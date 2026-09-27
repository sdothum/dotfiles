"""Layer CLI contract against an isolated/live cirrus, without subprocess mocks.

Standalone usage: test_window_layer.py ZEPHYR SIROCCO MANAGED_XID
Also exercised on a private display by test_native_ipc.py.
"""
import os
from pathlib import Path
import subprocess
import sys


def check_layers(binary, sirocco, env, winid):
    def focused():
        return subprocess.check_output([sirocco, "window", "focused"], env=env, text=True).strip()

    def run(args, expected):
        before = focused()
        result = subprocess.run([binary, "window", "layer", *args], env=env,
                                capture_output=True, text=True, timeout=5)
        assert (result.returncode == 0) == expected, (args, result.stderr)
        assert focused() == before, "layer assignment changed focus"

    for value in ("Normal", "Above", "Overlay", "normal", "above", "overlay"):
        run([value], True)
        run([value, winid], True)
    for args in ([], ["ABOVE"], ["Unknown"], [winid, "Above"],
                 ["Above", "Overlay"], ["Above", "0xZZZZZZZZ"],
                 ["Above", "--all"], ["Above", winid, "extra"]):
        run(args, False)
    run(["Overlay", "0x7fffffff"], False)


if __name__ == "__main__":
    check_layers(str(Path(sys.argv[1]).resolve()), str(Path(sys.argv[2]).resolve()),
                 os.environ, sys.argv[3])
    print("PASS: layer parsing, focused/explicit targets, invalid arguments, WM errors, stable focus")
