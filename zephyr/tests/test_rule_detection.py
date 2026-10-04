"""Daemon-native creation-rule execution on private Xvfb/cirrus."""
import os
from pathlib import Path
import signal
import subprocess as sp
import sys
import tempfile
import time

from private_wm import private_wm
from test_window_lifecycle import wait_for


def run():
    cirrus, zephyr, zephyrd = [str(Path(arg).resolve()) for arg in sys.argv[1:4]]
    project = Path(__file__).resolve().parents[1]
    children = []
    managed_clients = []
    with tempfile.TemporaryDirectory(prefix="zephyr-rule-detection-") as temp:
        root = Path(temp)
        base_env = dict(os.environ, PATH=str(Path(cirrus)) + os.pathsep + os.environ["PATH"])
        with private_wm(cirrus, root / "wm", base_env) as env:
            log_path = root / "zephyrd.log"
            log = log_path.open("w+")

            def start(args, **kwargs):
                proc = sp.Popen(args, env=env, stdout=kwargs.pop("stdout", log),
                                stderr=kwargs.pop("stderr", log), **kwargs)
                children.append(proc)
                return proc

            def daemon_log():
                log.flush()
                return log_path.read_text()

            def cli(*args, timeout=5):
                return sp.run([zephyr, *args], env=env, text=True,
                              capture_output=True, timeout=timeout)

            def cirrus_cli(*args):
                return sp.run([str(Path(cirrus) / "sirocco"), *args], env=env,
                              text=True, capture_output=True, timeout=5, check=True).stdout.strip()

            def new_client(classname, configure=()):
                proc = start([sys.executable, str(project / "tests" / "test_window_lifecycle.py"),
                              "--client", classname], stdin=sp.PIPE, stdout=sp.PIPE,
                             text=True)
                xid = proc.stdout.readline().strip()
                assert xid.startswith("0x"), xid
                for command in configure:
                    proc.stdin.write(command + "\n"); proc.stdin.flush()
                    assert proc.stdout.readline().strip() == "OK"
                proc.stdin.write("map\n"); proc.stdin.flush()
                assert proc.stdout.readline().strip() == "OK"
                managed_clients.append((proc, xid))
                return proc, xid

            def destroy_client(proc, xid):
                if proc.poll() is None:
                    proc.stdin.write("destroy\n"); proc.stdin.flush()
                    assert proc.stdout.readline().strip() == "OK"
                wait_for(lambda: xid not in cirrus_cli("window", "ids", "--all").splitlines(),
                         "test client did not disappear: " + xid)

            def snapshot_client(xid):
                for line in cirrus_cli("window", "snapshot").splitlines():
                    fields = line.split()
                    if len(fields) >= 5 and fields[0] == "CLIENT" and fields[1] == xid:
                        return fields
                raise AssertionError("client missing from authoritative snapshot: " + xid)

            def current_group():
                for line in cirrus_cli("window", "snapshot").splitlines():
                    fields = line.split()
                    if len(fields) == 2 and fields[0] == "CURRENT":
                        return fields[1]
                raise AssertionError("current group missing from authoritative snapshot")

            def geometry(xid):
                return cirrus_cli("window", "geometry", xid)

            def check_native_rule(classname, verb, expected_group=None):
                proc, xid = new_client(classname)
                matched = "RULE_MATCH " + xid + " " + verb
                applied = "RULE_APPLIED " + xid + " " + verb
                wait_for(lambda: applied in daemon_log() or
                         "RULE_FAILED " + xid in daemon_log(),
                         classname + " policy did not finish")
                lines = daemon_log().splitlines()
                assert lines.count(matched) == 1, lines
                assert lines.count(applied) == 1, lines
                assert "RULE_FAILED " + xid + " " + verb + " " not in daemon_log()
                assert geometry(xid) != "20 20 160 100", (classname, geometry(xid))
                if expected_group is not None:
                    assert snapshot_client(xid)[2] == str(expected_group), (classname, snapshot_client(xid))
                return proc, xid

            try:
                # An existing matching window is baseline state and must not
                # execute a rule during daemon startup.
                baseline_proc, baseline_xid = new_client("yazi")
                baseline_surf_proc, baseline_surf_xid = new_client(
                    "Surf", ("title @cgDIS:T | Baseline",)
                )
                baseline_geometry = geometry(baseline_xid)
                baseline_group = snapshot_client(baseline_xid)[2]

                daemon = start([zephyrd])
                wait_for(lambda: "BASELINE " in daemon_log(), "daemon did not publish baseline")
                time.sleep(0.2)
                assert "RULE_MATCH " not in daemon_log(), daemon_log()
                assert "RULE_APPLIED " not in daemon_log(), daemon_log()
                assert "RULE_FAILED " not in daemon_log(), daemon_log()
                assert "RULE_MATCH " + baseline_surf_xid not in daemon_log(), daemon_log()
                assert geometry(baseline_xid) == baseline_geometry
                assert snapshot_client(baseline_xid)[2] == baseline_group
                assert snapshot_client(baseline_surf_xid)[2] != "2"

                # A qualifying title already present in the initial baseline
                # is suppressed. A real post-READY transition on that same
                # identity is handled once, and an unchanged repeat is quiet.
                baseline_surf_proc.stdin.write("title ordinary page\n")
                baseline_surf_proc.stdin.flush()
                assert baseline_surf_proc.stdout.readline().strip() == "OK"
                assert cli("window", "await", "--name", "ordinary page").returncode == 0
                baseline_surf_proc.stdin.write("title @cgDIS:T | Baseline\n")
                baseline_surf_proc.stdin.flush()
                assert baseline_surf_proc.stdout.readline().strip() == "OK"
                surf_match = "RULE_MATCH " + baseline_surf_xid + " surf title"
                surf_applied = "RULE_APPLIED " + baseline_surf_xid + " surf title"
                wait_for(lambda: surf_applied in daemon_log(),
                         "Surf title transition policy was not applied")
                assert daemon_log().count(surf_match) == 1, daemon_log()
                assert daemon_log().count(surf_applied) == 1, daemon_log()
                baseline_surf_proc.stdin.write("title @cgDIS:T | Baseline\n")
                baseline_surf_proc.stdin.flush()
                assert baseline_surf_proc.stdout.readline().strip() == "OK"
                time.sleep(0.2)
                assert daemon_log().count(surf_match) == 1, daemon_log()
                assert snapshot_client(baseline_surf_xid)[2] == "2"

                # Keep the default WM group distinct from Kakoune's policy
                # destination so an accidental dispatch would be observable.
                cirrus_cli("group", "activate", "2")

                # An unrelated client is reported as added without matching
                # or receiving an action.
                unrelated_proc, unrelated_xid = new_client("LifecycleTest")
                wait_for(lambda: "CLIENT_ADDED " + unrelated_xid + " " in daemon_log(),
                         "unrelated client was not observed")
                assert "RULE_MATCH " + unrelated_xid + " " not in daemon_log()
                assert "RULE_APPLIED " + unrelated_xid + " " not in daemon_log()
                assert "RULE_FAILED " + unrelated_xid + " " not in daemon_log()
                unrelated_geometry = geometry(unrelated_xid)
                unrelated_group = snapshot_client(unrelated_xid)[2]

                # Keep another managed client focused before adding Kak. The
                # rule must act on the ClientAdded XID and leave the unrelated
                # client's geometry and group alone.
                cirrus_cli("window", "focus", unrelated_xid)
                assert cirrus_cli("window", "focused") == unrelated_xid
                # Hold zephyrd while Cirrus adds/maps the new client, then
                # focus the unrelated client before zephyrd takes its next
                # authoritative snapshot. This makes the execution-time
                # focused client differ from the ClientAdded target.
                daemon.send_signal(signal.SIGSTOP)
                matching_proc, matching_xid = new_client("kak")
                cirrus_cli("window", "focus", unrelated_xid)
                assert cirrus_cli("window", "focused") == unrelated_xid
                daemon.send_signal(signal.SIGCONT)
                matched = "RULE_MATCH " + matching_xid + " kak"
                applied = "RULE_APPLIED " + matching_xid + " kak"
                wait_for(lambda: applied in daemon_log() or
                         "RULE_FAILED " + matching_xid in daemon_log() or daemon.poll() is not None,
                         "matching policy did not finish")
                assert daemon.poll() is None, ("zephyrd exited", daemon.poll(), daemon_log())
                assert applied in daemon_log(), daemon_log()
                lines = daemon_log().splitlines()
                assert lines.count(matched) == 1, lines
                assert lines.count(applied) == 1, lines
                assert "RULE_FAILED " + matching_xid + " kak " not in daemon_log()
                assert snapshot_client(matching_xid)[2] == "3"
                assert geometry(matching_xid) != "20 20 160 100"
                assert geometry(unrelated_xid) == unrelated_geometry
                assert snapshot_client(unrelated_xid)[2] == unrelated_group
                assert cirrus_cli("window", "focused") == unrelated_xid

                yazi_proc, yazi_xid = new_client("yazi")
                yazi_match = "RULE_MATCH " + yazi_xid + " yazi"
                yazi_applied = "RULE_APPLIED " + yazi_xid + " yazi"
                wait_for(lambda: yazi_applied in daemon_log(),
                         "Yazi policy was not applied")
                assert yazi_match in daemon_log()
                assert snapshot_client(yazi_xid)[2] == "5"
                assert geometry(yazi_xid) != "20 20 160 100"

                # Exercise title-based matching as well as class matching.
                firefox_proc, firefox_xid = new_client(
                    "LifecycleTest", ("title Example page — Mozilla Firefox",)
                )
                firefox_match = "RULE_MATCH " + firefox_xid + " firefox"
                firefox_applied = "RULE_APPLIED " + firefox_xid + " firefox"
                wait_for(lambda: firefox_applied in daemon_log(),
                         "Firefox title policy was not applied")
                assert firefox_match in daemon_log()
                assert snapshot_client(firefox_xid)[2] == "1"
                assert geometry(firefox_xid) != "20 20 160 100"

                qutebrowser_proc, qutebrowser_xid = new_client(
                    "qutebrowser", ("title ordinary qutebrowser page",)
                )
                qutebrowser_match = "RULE_MATCH " + qutebrowser_xid + " qutebrowser"
                qutebrowser_applied = "RULE_APPLIED " + qutebrowser_xid + " qutebrowser"
                wait_for(lambda: qutebrowser_applied in daemon_log(),
                         "qutebrowser policy was not applied")
                assert qutebrowser_match in daemon_log()
                assert geometry(qutebrowser_xid) != "20 20 160 100"

                # The historical Whoops selector was global by title. Native
                # execution scopes it to qutebrowser to avoid closing an
                # unrelated application's identically titled window.
                other_whoops_proc, other_whoops_xid = new_client(
                    "LifecycleTest", ("title ordinary page",)
                )
                wait_for(lambda: "CLIENT_ADDED " + other_whoops_xid + " " in daemon_log(),
                         "unrelated Whoops test client was not observed")
                other_whoops_proc.stdin.write("title Whoops!\n")
                other_whoops_proc.stdin.flush()
                assert other_whoops_proc.stdout.readline().strip() == "OK"
                assert cli("window", "await", "--name", "Whoops!").returncode == 0
                assert "RULE_MATCH " + other_whoops_xid + " qutebrowser-whoops title" not in daemon_log()
                assert other_whoops_xid in cirrus_cli("window", "ids", "--all").splitlines()

                qutebrowser_proc.stdin.write("title Whoops!\n")
                qutebrowser_proc.stdin.flush()
                assert qutebrowser_proc.stdout.readline().strip() == "OK"
                wait_for(lambda: qutebrowser_xid in cli(
                    "window", "ids", "--all", "--name", "Whoops!"
                ).stdout.splitlines(), "daemon cache did not observe qutebrowser title")
                whoops_match = "RULE_MATCH " + qutebrowser_xid + " qutebrowser-whoops title"
                whoops_applied = "RULE_APPLIED " + qutebrowser_xid + " qutebrowser-whoops title"
                wait_for(lambda: whoops_applied in daemon_log(),
                         "qutebrowser Whoops title policy was not applied")
                assert whoops_match in daemon_log()
                assert qutebrowser_xid not in cirrus_cli("window", "ids", "--all").splitlines()
                assert other_whoops_xid in cirrus_cli("window", "ids", "--all").splitlines()
                managed_clients[:] = [
                    client for client in managed_clients if client[1] != qutebrowser_xid
                ]

                # Stage 4 rules translated directly from the current rulerrc.
                # These exercise tile-only, group+tile, and group+snap paths.
                check_native_rule("compose", "compose", 2)
                check_native_rule("cbftp", "cbftp")
                check_native_rule("xftp", "xftp")
                check_native_rule("audacious", "audacious", 6)
                check_native_rule("gFTP", "gftp")
                check_native_rule("pcmanfm", "pcmanfm", 5)

                # The email rule's final operation must cycle the stack
                # anchored at its own XID, even though an unrelated client
                # has focus when zephyrd processes ClientAdded.
                for proc, xid in managed_clients:
                    if xid != unrelated_xid:
                        destroy_client(proc, xid)
                cirrus_cli("group", "activate", "2")
                peer_proc, peer_xid = new_client("LifecycleTest")
                wait_for(lambda: "CLIENT_ADDED " + peer_xid + " " in daemon_log(),
                         "email stack peer was not observed")
                assert cli("group", "add", "2", peer_xid).returncode == 0
                cirrus_cli("window", "apply-geometries", peer_xid,
                           "341", "0", "341", "768")
                cirrus_cli("window", "apply-geometries", unrelated_xid,
                           "-10000", "-10000", "100", "100")
                cirrus_cli("window", "focus", peer_xid)

                daemon.send_signal(signal.SIGSTOP)
                email_proc, email_xid = new_client("email")
                cirrus_cli("window", "focus", email_xid)
                cirrus_cli("window", "focus", unrelated_xid)
                assert cirrus_cli("window", "focused") == unrelated_xid
                stack_before = cirrus_cli("window", "stack", email_xid).splitlines()
                assert set(stack_before) == {email_xid, peer_xid}, (
                    stack_before, geometry(email_xid), geometry(peer_xid),
                    geometry(unrelated_xid)
                )
                assert stack_before[-1] == email_xid, stack_before
                daemon.send_signal(signal.SIGCONT)

                email_match = "RULE_MATCH " + email_xid + " email"
                email_applied = "RULE_APPLIED " + email_xid + " email"
                wait_for(lambda: email_applied in daemon_log() or
                         "RULE_FAILED " + email_xid in daemon_log() or daemon.poll() is not None,
                         "email policy did not finish")
                assert daemon.poll() is None, daemon_log()
                assert daemon_log().splitlines().count(email_match) == 1, daemon_log()
                assert daemon_log().splitlines().count(email_applied) == 1, daemon_log()
                assert snapshot_client(email_xid)[2] == "2"
                assert geometry(email_xid) == "X=341\nY=0\nWIDTH=341\nHEIGHT=768"
                assert cirrus_cli("window", "focused") == peer_xid, (
                    "email stack cycle did not select the other member from email's stack",
                    cirrus_cli("window", "focused"), email_xid, peer_xid
                )
                cli_email = cli("rule", "email")
                assert cli_email.returncode == 0, cli_email.stderr
                assert cirrus_cli("window", "focused") == email_xid, (
                    "focused CLI email rule did not use the same stack-cycle implementation",
                    cirrus_cli("window", "focused"), email_xid
                )

                # The policy is one-shot per ClientAdded. Later invalidations
                # and focus changes must not run it again.
                cirrus_cli("window", "focus", unrelated_xid)
                wait_for(lambda: any(line.startswith("FOCUS_CHANGED ") and
                                     line.endswith(" " + unrelated_xid)
                                     for line in daemon_log().splitlines()),
                         "focus invalidation did not produce a refresh")
                assert daemon_log().splitlines().count(matched) == 1
                assert daemon_log().splitlines().count(applied) == 1

                # The compatibility CLI resolves its explicit policy target
                # from focus, then reaches the same shared rule mapping.
                cli_compose = cli("rule", "compose")
                assert cli_compose.returncode == 0, cli_compose.stderr
                assert snapshot_client(unrelated_xid)[2] == "2"

                # Trigger the known spread error after mapping. The daemon
                # reports failure, consumes this creation event, then serves
                # a subsequent query and observes another client.
                top_metric = Path(env["WMSE"]) / "ui" / "gap_width top" / "700"
                top_metric.mkdir(parents=True)
                term_proc, term_xid = new_client("term")
                term_match = "RULE_MATCH " + term_xid + " term"
                term_failure = ("RULE_FAILED " + term_xid +
                                " term layout fold: window exceeds row height")
                wait_for(lambda: term_failure in daemon_log(),
                         "term policy failure was not reported")
                assert term_match in daemon_log()
                assert "RULE_APPLIED " + term_xid + " term" not in daemon_log()
                assert daemon_log().splitlines().count(term_failure) == 1
                wait_for(lambda: cli("window", "ids", "--all").returncode == 0 and
                         term_xid in cli("window", "ids", "--all").stdout.splitlines(),
                         "daemon did not answer query after failed policy")
                later_proc, later_xid = new_client("LifecycleTest")
                wait_for(lambda: "CLIENT_ADDED " + later_xid + " " in daemon_log(),
                         "daemon did not handle a later client after policy failure")
                assert "RULE_MATCH " + later_xid + " " not in daemon_log()
                assert "RULE_APPLIED " + later_xid + " " not in daemon_log()
                assert "RULE_FAILED " + later_xid + " " not in daemon_log()
                assert daemon_log().splitlines().count(term_failure) == 1

                print("PASS: baseline suppression, explicit-target native Stage 3–5 rules, focused compose/email CLI compatibility, unknown miss, one-shot rules, term failure containment and daemon recovery")
            except BaseException:
                print(daemon_log())
                raise
            finally:
                for proc in reversed(children):
                    if proc.poll() is None:
                        proc.terminate()
                        try:
                            proc.wait(timeout=5)
                        except sp.TimeoutExpired:
                            proc.kill(); proc.wait()
                log.close()


if __name__ == "__main__":
    run()
