"""Cached window ids group integration test; argv: cirrus-dir zephyr zephyrd."""
import os
from pathlib import Path
import select
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
        for name in ("WINFO", "GROUP", "HIDDEN", "WME", "FIFO", "XDG_RUNTIME_DIR"):
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
    else:
        run()
