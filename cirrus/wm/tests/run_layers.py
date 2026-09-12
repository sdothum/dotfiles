"""Build and test stacking layers on a private Xvfb display (requires Xvfb)."""
import os
from pathlib import Path
import select
import subprocess
import tempfile
import time

root = Path(__file__).resolve().parents[1]
subprocess.run(["make", "-B"], cwd=root, check=True)
with tempfile.TemporaryDirectory(prefix="cirrus-layers-") as directory:
    temporary = Path(directory)
    test = temporary / "test_layers"
    subprocess.run(["cc", "-std=c99", "-Wall", "-Wextra", "-I", str(root),
                    str(root / "tests/test_layers.c"), "-o", str(test),
                    "-lxcb", "-lxcb-ewmh"], check=True)
    read_fd, write_fd = os.pipe()
    with (temporary / "server.log").open("w+") as server_log, \
            (temporary / "wm.log").open("w+") as wm_log:
        server = subprocess.Popen(["Xvfb", "-displayfd", str(write_fd),
                                   "-screen", "0", "1024x768x24", "-nolisten", "tcp"],
                                  pass_fds=(write_fd,), stdout=server_log, stderr=server_log)
        os.close(write_fd)
        wm = None
        try:
            if not select.select([read_fd], [], [], 10)[0]:
                raise RuntimeError("Xvfb did not report a test display")
            display = os.read(read_fd, 64).decode().strip()
            assert display.isdecimal(), "Xvfb failed to start"
            env = dict(os.environ, DISPLAY=":" + display)
            wm = subprocess.Popen([str(root / "cirrus"), "-c", "/bin/true"],
                                  env=env, stdout=wm_log, stderr=wm_log)
            time.sleep(0.5)
            assert wm.poll() is None, "test WM failed to start"
            subprocess.run([str(test), str(root / "sirocco")], env=env,
                           timeout=40, check=True)
        except BaseException:
            for log in (server_log, wm_log):
                log.flush()
                log.seek(0)
                print(log.read())
            raise
        finally:
            os.close(read_fd)
            if wm is not None and wm.poll() is None:
                wm.terminate()
                wm.wait(timeout=5)
            server.terminate()
            server.wait(timeout=5)
