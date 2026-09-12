"""CLI contract test. Pass a freshly compiled zephyr binary as argv[1]."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

binary = str(Path(sys.argv[1]).resolve())
with tempfile.TemporaryDirectory() as directory:
    root = Path(directory)
    backend = root / "sirocco"
    backend.write_text('''#!/usr/bin/env python3
import json, os, sys
with open(os.environ["LAYER_TEST_LOG"], "a") as log:
    log.write(json.dumps(sys.argv[1:]) + "\\n")
if sys.argv[1:] == ["window", "focused"]:
    print("0x03a00007")
else:
    sys.exit(int(os.environ.get("LAYER_TEST_STATUS", "0")))
''')
    backend.chmod(0o755)
    log = root / "calls"
    env = dict(os.environ, PATH=directory + os.pathsep + os.environ["PATH"],
               LAYER_TEST_LOG=str(log))

    def run(args, expected, calls, status=0):
        log.write_text("")
        result = subprocess.run([binary, "window", "layer", *args],
                                env=dict(env, LAYER_TEST_STATUS=str(status)),
                                capture_output=True, text=True)
        assert (result.returncode == 0) == expected, (args, result.stderr)
        assert [json.loads(line) for line in log.read_text().splitlines()] == calls
        if status:
            assert result.returncode == status

    for value in ("Normal", "Above", "Overlay", "normal", "above", "overlay"):
        run([value], True, [["window", "focused"],
                           ["window", "layer", value, "0x03a00007"]])
        run([value, "0x03a00008"], True,
            [["window", "layer", value, "0x03a00008"]])
    for args in ([], ["ABOVE"], ["Unknown"], ["0x03a00007", "Above"],
                 ["Above", "Overlay"], ["Above", "0xZZZZZZZZ"],
                 ["Above", "--all"], ["Above", "0x03a00007", "extra"]):
        run(args, False, [])
    run(["Overlay", "0x03a00007"], False,
        [["window", "layer", "Overlay", "0x03a00007"]], status=7)
print("PASS: layer parsing, focused/explicit targets, invalid arguments, backend failures")
