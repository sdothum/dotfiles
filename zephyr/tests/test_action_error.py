"""CLI and catchable-host behavior for policy action failures."""
import os
from pathlib import Path
import subprocess as sp
import sys
import tempfile

from private_wm import private_wm
from test_window_lifecycle import wait_for


def run():
    cirrus, zephyr, probe, zephyrd = [str(Path(arg).resolve()) for arg in sys.argv[1:5]]
    project = Path(__file__).resolve().parents[1]
    children = []
    with tempfile.TemporaryDirectory(prefix="zephyr-action-error-") as temp:
        base_env = dict(os.environ, PATH=str(Path(cirrus)) + os.pathsep + os.environ["PATH"])
        with private_wm(cirrus, Path(temp) / "wm", base_env) as env:
            # Keep a 700px client inside the 768px Xvfb root while making it
            # taller than Zephyr's usable area, so the fold precondition is
            # exercised without relying on bogus WM_NORMAL_HINTS values.
            for edge in ("top", "bottom"):
                metric = Path(env["WMSE"]) / "ui" / ("gap_width " + edge) / "40"
                metric.mkdir(parents=True)
            def start(args, **kwargs):
                proc = sp.Popen(args, env=env, **kwargs)
                children.append(proc)
                return proc

            def cirrus_cli(*args):
                return sp.run([str(Path(cirrus) / "sirocco"), *args], env=env,
                              text=True, capture_output=True, timeout=5, check=True).stdout.strip()

            def zephyr_cli(*args):
                return sp.run([zephyr, *args], env=env, text=True,
                              capture_output=True, timeout=10)

            daemon_log = (Path(temp) / "zephyrd.log").open("w+")
            daemon = start([zephyrd], stdout=daemon_log, stderr=daemon_log)
            wait_for(lambda: "BASELINE " in (Path(temp) / "zephyrd.log").read_text(),
                     "daemon did not bootstrap")

            def new_client(classname, height=100):
                proc = start([sys.executable, str(project / "tests" / "test_window_lifecycle.py"),
                              "--client", classname], stdin=sp.PIPE, stdout=sp.PIPE,
                             text=True)
                xid = proc.stdout.readline().strip()
                proc.stdin.write(f"resize 200 {height}\n"); proc.stdin.flush()
                assert proc.stdout.readline().strip() == "OK"
                proc.stdin.write("map\n"); proc.stdin.flush()
                assert proc.stdout.readline().strip() == "OK"
                wait_for(lambda: xid in cirrus_cli("window", "ids", "--all").splitlines(),
                         "client did not become managed")
                return proc, xid

            try:
                # Give the client a valid 700px size before mapping. It fits
                # inside the Xvfb root but exceeds the 688px usable area.
                term, term_id = new_client("term", 700)
                cirrus_cli("window", "focus", term_id)
                assert "HEIGHT=700" in cirrus_cli("window", "geometry", term_id)

                result = zephyr_cli("rule", "term")
                assert result.returncode != 0
                assert result.stderr.strip() == "layout fold: window exceeds row height", result.stderr
                assert "ZephyrError" not in result.stderr and "Traceback" not in result.stderr

                caught = sp.run([probe, term_id], env=env, text=True,
                                capture_output=True, timeout=10)
                assert caught.returncode == 0, caught.stderr
                assert caught.stdout.splitlines() == [
                    "layout fold: window exceeds row height", "HOST_SURVIVED"
                ], caught.stdout

                kak, kak_id = new_client("kak")
                cirrus_cli("window", "focus", kak_id)
                successful = zephyr_cli("rule", "kak")
                assert successful.returncode == 0, successful.stderr
                assert zephyr_cli("window", "wm-group", kak_id).stdout.strip() == "3"
                assert cirrus_cli("window", "focused") == kak_id
                print("PASS: CLI error compatibility, catchable host survival, successful Kak rule")
            finally:
                for proc in reversed(children):
                    if proc.poll() is None:
                        if proc.stdin:
                            proc.stdin.write("destroy\n"); proc.stdin.flush()
                        proc.terminate()
                        try:
                            proc.wait(timeout=5)
                        except sp.TimeoutExpired:
                            proc.kill(); proc.wait()
                daemon_log.close()


if __name__ == "__main__":
    run()
