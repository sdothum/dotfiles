"""Readiness synchronization and baseline rule boundary on private Xvfb."""
import os
from pathlib import Path
import subprocess as sp
import sys
import tempfile

from private_wm import private_wm
from test_window_lifecycle import wait_for


def run():
    cirrus, zephyr, zephyrd = [str(Path(arg).resolve()) for arg in sys.argv[1:4]]
    project = Path(__file__).resolve().parents[1]
    children = []
    with tempfile.TemporaryDirectory(prefix="zephyr-readiness-") as temp:
        root = Path(temp)
        base_env = dict(os.environ, PATH=str(Path(cirrus)) + os.pathsep + os.environ["PATH"])
        with private_wm(cirrus, root / "wm", base_env, screen="1920x1200x24") as env:
            log_path = root / "zephyrd.log"
            with log_path.open("w+") as log:
                def start(args, **kwargs):
                    proc = sp.Popen(args, env=env, stdout=kwargs.pop("stdout", log),
                                    stderr=kwargs.pop("stderr", log), **kwargs)
                    children.append(proc)
                    return proc

                def daemon_log():
                    log.flush()
                    return log_path.read_text()

                def cirrus_cli(*args):
                    return sp.run([str(Path(cirrus) / "sirocco"), *args], env=env,
                                  text=True, capture_output=True, timeout=5,
                                  check=True).stdout.strip()

                def new_client(classname):
                    proc = start([sys.executable,
                                  str(project / "tests" / "test_window_lifecycle.py"),
                                  "--client", classname], stdin=sp.PIPE,
                                 stdout=sp.PIPE, text=True)
                    xid = proc.stdout.readline().strip()
                    assert xid.startswith("0x"), xid
                    proc.stdin.write("map\n")
                    proc.stdin.flush()
                    assert proc.stdout.readline().strip() == "OK"
                    return proc, xid

                def state(xid):
                    for line in cirrus_cli("window", "snapshot").splitlines():
                        fields = line.split()
                        if len(fields) >= 5 and fields[0] == "CLIENT" and fields[1] == xid:
                            return fields
                    raise AssertionError("client absent from WM snapshot: " + xid)

                try:
                    baseline_proc, baseline_xid = new_client("yazi")
                    baseline_geometry = cirrus_cli("window", "geometry", baseline_xid)

                    # Launch await before the listener exists. It must wait
                    # for daemon startup and then for the baseline boundary.
                    awaiter = start([zephyr, "daemon", "await"], stdout=sp.PIPE,
                                    stderr=sp.PIPE, text=True)
                    assert awaiter.poll() is None, "await completed before daemon startup"
                    daemon = start([zephyrd])
                    stdout, stderr = awaiter.communicate(timeout=10)
                    assert awaiter.returncode == 0, (stdout, stderr, daemon_log())
                    wait_for(lambda: "BASELINE " in daemon_log(),
                             "daemon baseline diagnostic missing")
                    assert not any(
                        line.endswith(" " + baseline_xid + " yazi")
                        and line.startswith(("RULE_MATCH ", "RULE_APPLIED ", "RULE_FAILED "))
                        for line in daemon_log().splitlines()
                    ), daemon_log()
                    assert cirrus_cli("window", "geometry", baseline_xid) == baseline_geometry

                    # The new client is created strictly after readiness and
                    # must not be swallowed into the suppressed baseline.
                    luakit_proc, luakit_xid = new_client("Luakit")
                    wm_class = sp.run(["xprop", "-id", luakit_xid, "WM_CLASS"],
                                     env=env, text=True, capture_output=True,
                                     timeout=5, check=True).stdout
                    assert '"luakit", "Luakit"' in wm_class, wm_class
                    luakit_geometry_before = cirrus_cli("window", "geometry", luakit_xid)
                    matched = "RULE_MATCH " + luakit_xid + " luakit"
                    applied = "RULE_APPLIED " + luakit_xid + " luakit"
                    failed = "RULE_FAILED " + luakit_xid + " luakit "
                    wait_for(lambda: applied in daemon_log() or
                             failed in daemon_log() or
                             daemon.poll() is not None,
                             "post-ready Luakit policy did not finish")
                    assert daemon.poll() is None, daemon_log()
                    assert daemon_log().splitlines().count(matched) == 1, daemon_log()
                    if applied in daemon_log():
                        assert daemon_log().splitlines().count(applied) == 1, daemon_log()
                    else:
                        # This fixture's available screen geometry makes the
                        # existing Luakit spread action reject its snapped
                        # height. Matching and the preceding COMM move still
                        # prove this post-READY identity crossed ClientAdded.
                        assert any(line.startswith(failed) and
                                   "window exceeds row height" in line
                                   for line in daemon_log().splitlines()), daemon_log()
                    assert state(luakit_xid)[2] == "2", state(luakit_xid)
                    assert cirrus_cli("window", "geometry", luakit_xid) != luakit_geometry_before

                    # A successful policy after the Luakit fixture limitation
                    # proves the daemon continues processing post-READY adds.
                    kak_proc, kak_xid = new_client("kak")
                    kak_applied = "RULE_APPLIED " + kak_xid + " kak"
                    wait_for(lambda: kak_applied in daemon_log() or
                             daemon.poll() is not None,
                             "post-ready Kak policy did not finish")
                    assert daemon.poll() is None, daemon_log()
                    assert "RULE_MATCH " + kak_xid + " kak" in daemon_log()
                    assert kak_applied in daemon_log()
                    assert state(kak_xid)[2] == "3", state(kak_xid)
                    assert cirrus_cli("window", "geometry", kak_xid) != "20 20 160 100"
                finally:
                    for proc in reversed(children):
                        if proc.poll() is None:
                            proc.terminate()
                            try:
                                proc.wait(timeout=3)
                            except sp.TimeoutExpired:
                                proc.kill()
                                proc.wait()


if __name__ == "__main__":
    run()
