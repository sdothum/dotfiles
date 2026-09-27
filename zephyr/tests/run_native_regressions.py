"""Build and run all native IPC regressions without accessing the desktop WM.

Usage: python3 tests/run_native_regressions.py /path/to/cirrus/source
Builds in a temporary directory (printed, retained for diagnostic logs).
"""
import os
from pathlib import Path
import shutil
import subprocess as sp
import sys
import tempfile
from private_wm import private_wm


def run():
    repo = Path(__file__).resolve().parents[1]
    source = Path(sys.argv[1]).resolve()
    build = Path(tempfile.mkdtemp(prefix="zephyr-native-regressions-"))
    print("Artifacts:", build, flush=True)
    env = dict(os.environ, DISPLAY=":65534")
    env.pop("ZEPHYR_PRIVATE_TEST_DISPLAY", None)
    for key in ("WINFO", "GROUP", "HIDDEN", "WME", "WMSE", "FIFO", "XDG_RUNTIME_DIR"):
        path = build / key.lower(); path.mkdir()
        env[key] = str(path)

    def command(label, args, **kwargs):
        p = sp.run([str(arg) for arg in args], cwd=repo, env=kwargs.pop("env", env),
                   text=True, capture_output=True, timeout=180, **kwargs)
        (build / (label + ".log")).write_text(p.stdout + p.stderr)
        print(label, "PASS" if p.returncode == 0 else "FAIL", flush=True)
        diagnostics = [line for line in (p.stdout + p.stderr).splitlines()
                       if "Warning:" in line or "Error:" in line]
        if diagnostics: print("\n".join(diagnostics), flush=True)
        if p.returncode:
            print(p.stdout + p.stderr)
            raise RuntimeError(label)
        return p

    cirrus = build / "cirrus"; cirrus.mkdir()
    for pattern in ("*.c", "*.h", "Makefile", "config.mk", "VERSION"):
        for path in source.glob(pattern): shutil.copy2(path, cirrus / path.name)
    shutil.copytree(source / "tests", cirrus / "tests")
    command("build-cirrus", ["make", "-C", cirrus, "-j4"])
    binaries = {}
    sources = [repo / "zephyr.nimble", repo / "zephyrd.nim", repo / "tests/native_ipc_probe.nim"]
    sources += sorted((repo / "tests").glob("test_*.nim"))
    for path in sources:
        binary = build / path.stem
        command("build-" + path.stem, ["nim", "c", "--nimcache:" + str(build / "nimcache"),
                                        "-o:" + str(binary), path])
        binaries[path.stem] = binary
    for path in sorted((repo / "tests").glob("test_*.nim")):
        if path.stem != "test_state_reconciliation":
            command(path.stem, [binaries[path.stem]])
    # Explicitly prove a direct invocation cannot silently inherit a desktop WM.
    p = sp.run([binaries["test_state_reconciliation"]], env=env, text=True, capture_output=True)
    assert p.returncode != 0 and "private WM fixture" in p.stderr
    with private_wm(cirrus, build / "reconciliation", env) as private_env:
        command("test_state_reconciliation", [binaries["test_state_reconciliation"]], env=private_env)
    for name in ("test_native_ipc", "test_ids_group", "test_window_lifecycle", "test_fold_stacking",
                 "test_group_explode", "test_class_fold"):
        args = [sys.executable, repo / "tests" / (name + ".py"), cirrus,
                binaries["zephyr"], binaries["zephyrd"]]
        if name == "test_native_ipc": args.append(binaries["native_ipc_probe"])
        command(name, args)
    for name in ("run_layers", "run_ids_group"):
        command("cirrus-" + name, [sys.executable, cirrus / "tests" / (name + ".py")])
    print("PASS: complete native IPC and existing regression suites", flush=True)


if __name__ == "__main__":
    run()
