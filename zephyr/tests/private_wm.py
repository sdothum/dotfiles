"""Private Xvfb/cirrus fixture; never inherits the desktop DISPLAY."""
from contextlib import contextmanager
import os
from pathlib import Path
import select
import subprocess as sp
from test_window_lifecycle import wait_for


@contextmanager
def private_wm(cirrus, root, base_env=None, screen="1024x768x24"):
    root = Path(root)
    root.mkdir(parents=True, exist_ok=True)
    env = dict(base_env or os.environ)
    env.pop("DISPLAY", None)
    for key in ("WINFO", "GROUP", "HIDDEN", "WME", "WMSE", "FIFO", "XDG_RUNTIME_DIR"):
        path = root / key.lower()
        path.mkdir(exist_ok=True)
        env[key] = str(path)
    rd, wr = os.pipe()
    server = wm = None
    with (root / "private-wm.log").open("w+") as log:
        try:
            server = sp.Popen(["Xvfb", "-displayfd", str(wr), "-screen", "0", screen,
                               "-nolisten", "tcp"], pass_fds=(wr,), stdout=log, stderr=log, env=env)
            os.close(wr); wr = None
            assert select.select([rd], [], [], 10)[0], "Xvfb startup timed out"
            number = os.read(rd, 64).decode().strip()
            assert number.isdecimal(), "Xvfb did not allocate a private display"
            env["DISPLAY"] = ":" + number
            env["ZEPHYR_PRIVATE_TEST_DISPLAY"] = env["DISPLAY"]
            wm = sp.Popen([str(Path(cirrus) / "cirrus"), "-c", "/bin/true"],
                          env=env, stdout=log, stderr=log)
            def ready():
                assert wm.poll() is None, "private cirrus exited"
                return sp.run([str(Path(cirrus) / "sirocco"), "group", "count"], env=env,
                              stdout=sp.DEVNULL, stderr=sp.DEVNULL, timeout=5).returncode == 0
            wait_for(ready, "private cirrus startup")
            yield env
        except BaseException:
            log.flush(); log.seek(0); print(log.read())
            raise
        finally:
            os.close(rd)
            if wr is not None: os.close(wr)
            for p in (wm, server):
                if p is not None and p.poll() is None:
                    p.terminate()
                    try: p.wait(timeout=5)
                    except sp.TimeoutExpired: p.kill(); p.wait()
