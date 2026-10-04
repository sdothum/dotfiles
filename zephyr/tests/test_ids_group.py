"""Cached window ids group integration test; argv: cirrus-dir zephyr zephyrd."""
import os
from pathlib import Path
import select
import shutil
import subprocess
import sys
import tempfile
import time
from test_window_lifecycle import client, wait_for


def run():
    cirrus, zephyr, zephyrd = map(lambda p: str(Path(p).resolve()), sys.argv[1:4])
    children = []
    with tempfile.TemporaryDirectory(prefix="zephyr-ids-group-") as directory:
        root = Path(directory)
        env = dict(os.environ, PATH=cirrus + os.pathsep + os.environ["PATH"])
        for name in ("WINFO", "GROUP", "HIDDEN", "WME", "WMSE", "FIFO", "XDG_RUNTIME_DIR"):
            path = root / name.lower()
            path.mkdir()
            env[name] = str(path)
        with (root / "log").open("w+") as log:
            def start(args, **kwargs):
                p = subprocess.Popen(args, env=env, stderr=log,
                                     stdout=kwargs.pop("stdout", log), **kwargs)
                children.append(p)
                return p

            def command(*args):
                return subprocess.check_output([cirrus + "/sirocco", *args], env=env, text=True)

            def client_tokens():
                result = {}
                for line in command("window", "snapshot").splitlines():
                    fields = line.split()
                    if len(fields) >= 5 and fields[0] == "CLIENT":
                        result[fields[1]] = fields[4]
                return result

            def zephyr_command(*args):
                return subprocess.run([zephyr, *args], env=env, capture_output=True,
                                      text=True, timeout=5)

            def ids(*args):
                p = subprocess.run([zephyr, "window", "ids", *args], env=env,
                                   capture_output=True, text=True, timeout=5)
                assert p.returncode == 0, p.stderr
                return p.stdout.strip().splitlines()

            def expect(expected, *args):
                assert ids(*args) == expected, (args, ids(*args), expected)

            read_fd, write_fd = os.pipe()
            start(["Xvfb", "-displayfd", str(write_fd), "-screen", "0", "1024x768x24",
                   "-nolisten", "tcp"], pass_fds=(write_fd,))
            os.close(write_fd)
            try:
                assert select.select([read_fd], [], [], 10)[0]
                env["DISPLAY"] = ":" + os.read(read_fd, 64).decode().strip()
                start([cirrus + "/cirrus", "-c", "/bin/true"])
                time.sleep(.4)
                windows = []
                for i in range(3):
                    p = start([sys.executable, __file__, "--client"], stdin=subprocess.PIPE,
                              stdout=subprocess.PIPE, text=True)
                    xid = p.stdout.readline().strip()
                    p.stdin.write("map\n"); p.stdin.flush()
                    assert p.stdout.readline().strip() == "OK"
                    time.sleep(.15)
                    command("group", "add", "2" if i < 2 else "3", xid)
                    subprocess.run(["xprop", "-id", xid, "-f", "WM_NAME", "8s", "-set",
                                    "WM_NAME", "foo title"], env=env, check=True, stdout=log)
                    windows.append(xid)
                command("window", "hide", windows[1])
                daemon = start([zephyrd])
                # Wait for the standard snapshot bootstrap, not a special group seed.
                def ready():
                    p = subprocess.run([zephyr, "window", "ids", "--all"], env=env,
                                       capture_output=True, text=True, timeout=5)
                    return p.returncode == 0 and set(p.stdout.splitlines()) == set(windows)
                wait_for(ready, "cache did not bootstrap")
                for metric in ("margin", "top", "bottom", "gap"):
                    assert zephyr_command("screen", metric).stdout.strip() == "0", metric
                # Group 0 remains parseable as an explicit value, but these
                # public group operations continue to reject reserved VOID.
                assert zephyr_command("group", "name", "0").stdout.strip() == "VOID"
                for invalid in (("group", "focus", "0"),
                                ("group", "add", "0", windows[0])):
                    rejected = zephyr_command(*invalid)
                    assert rejected.returncode != 0, (invalid, rejected.stdout)
                group_count = int(command("group", "count").strip())
                for invalid in (("group", "focus", str(group_count)),
                                ("group", "add", str(group_count), windows[0])):
                    rejected = zephyr_command(*invalid)
                    assert rejected.returncode != 0, (invalid, rejected.stdout)
                # Missing remembered state is ordinary absence and must not
                # make group focus fail or invent a focused-window fallback.
                p = zephyr_command("group", "focus", "2")
                assert p.returncode == 0, p.stderr

                # New remembered state records the live token alongside the
                # XID. It remains under the existing per-group XID directory.
                p = zephyr_command("group", "add", "2", windows[0])
                assert p.returncode == 0, p.stderr
                focus_group = Path(env["GROUP"] + ":focus") / "2"
                remembered = focus_group / windows[0]
                token_a = client_tokens()[windows[0]]
                assert (remembered / ("ID=" + token_a)).is_dir()
                command("window", "focus", windows[2])
                p = zephyr_command("group", "focus", "2")
                assert p.returncode == 0, p.stderr
                assert command("window", "focused").strip() == windows[0]

                # Legacy XID-only state remains usable and is upgraded from
                # the same live snapshot when that client has an identity.
                shutil.rmtree(remembered)
                remembered.mkdir()
                command("window", "focus", windows[2])
                p = zephyr_command("group", "focus", "2")
                assert p.returncode == 0, p.stderr
                assert command("window", "focused").strip() == windows[0]
                assert (remembered / ("ID=" + token_a)).is_dir()

                # Same XID and same WM group are insufficient if the saved
                # token belongs to a different live client.
                token_b = client_tokens()[windows[1]]
                shutil.rmtree(remembered)
                remembered.mkdir()
                (remembered / ("ID=" + token_b)).mkdir()
                command("window", "focus", windows[2])
                p = zephyr_command("group", "focus", "2")
                assert p.returncode == 0, p.stderr
                mismatch_fallback = command("window", "focused").strip()
                assert not remembered.exists(), "identity mismatch was not discarded"

                # A stale unmanaged XID follows the same focus fallback as a
                # reused XID with a mismatching token.
                shutil.rmtree(focus_group, ignore_errors=True)
                focus_group.mkdir()
                (focus_group / "0xdeadbeef").mkdir()
                command("window", "focus", windows[2])
                p = zephyr_command("group", "focus", "2")
                assert p.returncode == 0, p.stderr
                stale_fallback = command("window", "focused").strip()
                assert stale_fallback != "0xdeadbeef"
                assert stale_fallback == mismatch_fallback, (stale_fallback, mismatch_fallback)

                # A matching identity cannot bypass group validation. Pick a
                # group that differs from this client's live WM group.
                live_group = int(zephyr_command("window", "wm-group", windows[0]).stdout.strip())
                wrong_group_no = next(g for g in range(1, group_count)
                                      if g != live_group)
                wrong_focus_root = Path(env["GROUP"] + ":focus") / str(wrong_group_no)
                wrong_focus_root.mkdir(parents=True, exist_ok=True)
                wrong_group = wrong_focus_root / windows[0]
                wrong_group.mkdir()
                (wrong_group / ("ID=" + token_a)).mkdir()
                p = zephyr_command("group", "focus", str(live_group))
                assert p.returncode == 0, p.stderr
                p = zephyr_command("group", "focus", str(wrong_group_no))
                assert p.returncode == 0, p.stderr
                wrong_group_fallback = command("window", "focused").strip()

                shutil.rmtree(wrong_focus_root)
                wrong_focus_root.mkdir()
                (wrong_focus_root / "0xdeadbeef").mkdir()
                p = zephyr_command("group", "focus", str(live_group))
                assert p.returncode == 0, p.stderr
                p = zephyr_command("group", "focus", str(wrong_group_no))
                assert p.returncode == 0, p.stderr
                stale_group_fallback = command("window", "focused").strip()
                assert wrong_group_fallback == stale_group_fallback

                # Present but malformed identity metadata is corruption, not
                # a legacy tokenless entry, and is removed on lookup.
                shutil.rmtree(focus_group)
                malformed = focus_group / windows[0]
                malformed.mkdir(parents=True)
                (malformed / "ID=not-a-token").mkdir()
                command("window", "focus", windows[2])
                p = zephyr_command("group", "focus", "2")
                assert p.returncode == 0, p.stderr
                assert not focus_group.exists(), "malformed identity state was retained"

                visible = [windows[0], windows[2]]
                expect(sorted(visible)); expect(sorted(windows), "--all")
                for selector in ([], ["LifecycleTest"], ["--name", "foo"], ["--name", "f"]):
                    # Filtered queries retain snapshot order; these fixtures are creation-ordered.
                    before = ids(*selector)
                    expect([w for w in before if w == windows[0]], *selector, "--group", "2")
                    all_before = ids("--all", *selector)
                    expect([w for w in all_before if w in windows[:2]], "--all", *selector, "--group", "2")
                expect([windows[0]], "--group", "2", "LifecycleTest")
                expect([windows[0]], "LifecycleTest", "--group", "2")
                command("group", "add", "3", windows[0])
                wait_for(lambda: ids("--group", "2") == [], "group migration remained stale")
                assert set(ids("--group", "3")) == set(visible)
                command("group", "remove", windows[0])
                wait_for(lambda: ids("--group", "3") == [windows[2]], "group removal remained stale")
                assert ids("--all", "--group", "2") == [windows[1]]
                daemon.terminate(); daemon.wait(timeout=5)
                start([zephyrd]); wait_for(ready, "restart did not bootstrap")
                expect([windows[1]], "--all", "--name", "foo", "--group", "2")
                for value in ("0", "-1", "current", "nonnumeric"):
                    p = subprocess.run([zephyr, "window", "ids", "--group", value],
                                       env=env, capture_output=True, text=True)
                    assert p.returncode != 0
                group_count = int(command("group", "count").strip())
                p = subprocess.run([zephyr, "window", "ids", "--group", str(group_count - 1)],
                                   env=env, capture_output=True, text=True)
                assert p.returncode == 0, p.stderr
                p = subprocess.run([zephyr, "window", "ids", "--group", str(group_count)],
                                   env=env, capture_output=True, text=True)
                assert p.returncode != 0, "exclusive upper bound must be rejected"

                # Exercise representative ruler compatibility policies on a
                # private managed client with the matching WM_CLASS. Each
                # rule must retain the triggering XID through its target chain.
                def exercise_rule(classname, verb):
                    # Give fixed-destination policies a distinct starting
                    # group so the rule's target operation is observable.
                    starting_group = "3" if classname == "term" else "2"
                    command("group", "activate", starting_group)
                    proc = start([sys.executable, __file__, "--client", classname],
                                 stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
                    xid = proc.stdout.readline().strip()
                    assert xid.startswith("0x"), xid
                    # Creation policies run from ClientAdded, which happens
                    # as this client is mapped. Give it its intended test
                    # geometry before MapRequest so policy sees valid input.
                    proc.stdin.write("resize 200 150\n"); proc.stdin.flush()
                    assert proc.stdout.readline().strip() == "OK"
                    proc.stdin.write("map\n"); proc.stdin.flush()
                    assert proc.stdout.readline().strip() == "OK"
                    wait_for(lambda: xid in ids(classname),
                             "rule client not present in daemon snapshot: " + classname)
                    command("window", "focus", xid)
                    if classname == "term":
                        geometry = command("window", "geometry", xid)
                        assert "WIDTH=200" in geometry and "HEIGHT=150" in geometry, geometry
                    expected_current_group = int(
                        zephyr_command("group", "current").stdout.strip())
                    result = zephyr_command("rule", verb)
                    assert result.returncode == 0, (verb, result.stderr)
                    assert command("window", "focused").strip() == xid, verb
                    expected_group = {"kak": 3, "term": 3, "qutebrowser": 2,
                                      "Yazi": 5, "Firefox": 1}[classname]
                    if classname == "qutebrowser":
                        # Its policy intentionally keeps the current group;
                        # mapping the new client may have selected that group
                        # before this compatibility invocation.
                        expected_group = expected_current_group
                    wait_for(lambda: zephyr_command("window", "wm-group", xid).stdout.strip()
                             == str(expected_group),
                             "rule did not apply its target group: " + verb)
                    proc.stdin.write("destroy\n"); proc.stdin.flush()
                    assert proc.stdout.readline().strip() == "OK"
                    wait_for(lambda: xid not in ids("--all"),
                             "rule test client survived cleanup: " + classname)

                for classname, verb in (("kak", "kak"), ("term", "term"),
                                        ("qutebrowser", "qutebrowser"),
                                        ("Yazi", "yazi"), ("Firefox", "firefox")):
                    exercise_rule(classname, verb)
                print("PASS: cached ids/class/name/all/group, direct migration/removal, hidden state, restart, validation")
            except BaseException:
                log.flush(); log.seek(0); print(log.read())
                raise
            finally:
                os.close(read_fd)
                for p in reversed(children):
                    if p.poll() is None:
                        p.terminate(); p.wait(timeout=5)


if __name__ == "__main__":
    if sys.argv[1:] == ["--client"]:
        client()
    elif len(sys.argv) == 3 and sys.argv[1] == "--client":
        client(sys.argv[2])
    else:
        run()
