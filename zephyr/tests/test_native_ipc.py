"""Native/C parity, persistent-session failures, chaining and optional benchmarks.

Usage: python3 tests/test_native_ipc.py CIRRUS_DIR ZEPHYR ZEPHYRD PROBE [BASELINE]
Build PROBE from tests/native_ipc_probe.nim. Requires Xvfb, libX11 and xwininfo.
"""
import os
import re
import ctypes as C
from pathlib import Path
import select
import signal
import statistics
import subprocess as sp
import sys
import tempfile
import time
from test_window_lifecycle import wait_for
from test_window_layer import check_layers


def run():
    cirrus, zephyr, daemon, probe = [str(Path(p).resolve()) for p in sys.argv[1:5]]
    children = []
    with tempfile.TemporaryDirectory(prefix="zephyr-native-ipc-") as directory:
        root = Path(directory)
        env = dict(os.environ, PATH=cirrus + os.pathsep + os.environ["PATH"])
        for key in ("WINFO", "GROUP", "HIDDEN", "WME", "WMSE", "FIFO", "XDG_RUNTIME_DIR"):
            path = root / key.lower()
            path.mkdir()
            env[key] = str(path)
        with (root / "log").open("w+") as log:
            def start(args, **kwargs):
                p = sp.Popen(args, env=env, stderr=log,
                             stdout=kwargs.pop("stdout", log), **kwargs)
                children.append(p)
                return p

            def cli(*args, check=True):
                return sp.run([cirrus + "/sirocco", *args], env=env, text=True,
                              capture_output=True, check=check, timeout=5)

            def output(*args):
                return cli(*args).stdout.strip()

            def z(*args, check=True, binary=zephyr):
                return sp.run([binary, *args], env=env, text=True, capture_output=True,
                              check=check, timeout=10)

            def child_ids():
                tree = sp.check_output(["xwininfo", "-root", "-tree"], env=env, text=True)
                return set(re.findall(r"^\s+(0x[0-9a-f]+)\s", tree, re.MULTILINE))

            def child_count():
                return len(child_ids())

            def response_absent(reply_window):
                value = sp.check_output(["xprop", "-id", reply_window, "__WM_IPC_RESPONSE"],
                                        env=env, text=True)
                assert "not found" in value, value

            def protocol_atoms(seed=0):
                x = C.CDLL("libX11.so.6")
                x.XOpenDisplay.argtypes = [C.c_char_p]; x.XOpenDisplay.restype = C.c_void_p
                x.XInternAtom.argtypes = [C.c_void_p, C.c_char_p, C.c_int]; x.XInternAtom.restype = C.c_ulong
                x.XCloseDisplay.argtypes = [C.c_void_p]
                display = x.XOpenDisplay(env["DISPLAY"].encode()); assert display
                try:
                    for i in range(seed):
                        x.XInternAtom(display, f"ZEPHYR_RESTART_SEED_{i}".encode(), 0)
                    return tuple(x.XInternAtom(display, name, 0) for name in
                                 (b"__WM_IPC_COMMAND", b"__WM_IPC_RESPONSE", b"__WM_IPC_REQUEST"))
                finally:
                    x.XCloseDisplay(display)

            def property_noise(reply_window):
                # A real unrelated PropertyNewValue plus a matching PropertyDelete.
                sp.run(["xprop", "-id", reply_window, "-f", "ZEPHYR_TEST_NOISE", "8s",
                        "-set", "ZEPHYR_TEST_NOISE", "unrelated"], env=env, check=True)
                x = C.CDLL("libX11.so.6")
                class PropertyEvent(C.Structure):
                    _fields_ = [("type", C.c_int), ("serial", C.c_ulong), ("send_event", C.c_int),
                                ("display", C.c_void_p), ("window", C.c_ulong), ("atom", C.c_ulong),
                                ("time", C.c_ulong), ("state", C.c_int)]
                class Event(C.Union):
                    _fields_ = [("property", PropertyEvent), ("pad", C.c_long * 24)]
                x.XOpenDisplay.argtypes = [C.c_char_p]; x.XOpenDisplay.restype = C.c_void_p
                x.XInternAtom.argtypes = [C.c_void_p, C.c_char_p, C.c_int]; x.XInternAtom.restype = C.c_ulong
                x.XSendEvent.argtypes = [C.c_void_p, C.c_ulong, C.c_int, C.c_long, C.POINTER(Event)]
                x.XSync.argtypes = [C.c_void_p, C.c_int]
                x.XCloseDisplay.argtypes = [C.c_void_p]
                display = x.XOpenDisplay(env["DISPLAY"].encode()); assert display
                try:
                    event = Event()
                    event.property = PropertyEvent(28, 0, 1, display, int(reply_window, 16),
                        x.XInternAtom(display, b"__WM_IPC_RESPONSE", 0), 0, 1)
                    assert x.XSendEvent(display, int(reply_window, 16), 0, 1 << 22, C.byref(event))
                    x.XSync(display, 0)
                finally:
                    x.XCloseDisplay(display)

            def session():
                return start([probe], stdin=sp.PIPE, stdout=sp.PIPE, text=True)

            def native(command, p=None):
                p = p or client
                p.stdin.write(command + "\n")
                p.stdin.flush()
                assert select.select([p.stdout], [], [], 5)[0], command
                reply = p.stdout.readline()
                assert reply, (command, p.poll())
                return reply.strip()

            rd, wr = os.pipe()
            server = start(["Xvfb", "-displayfd", str(wr), "-screen", "0", "1024x768x24",
                            "-nolisten", "tcp"], pass_fds=(wr,))
            os.close(wr)
            try:
                assert select.select([rd], [], [], 10)[0]
                env["DISPLAY"] = ":" + os.read(rd, 64).decode().strip()
                wm = start([cirrus + "/cirrus", "-c", "/bin/true"])
                wait_for(lambda: cli("group", "count", check=False).returncode == 0, "WM startup")
                windows = []
                for i in range(6):
                    p = start([sys.executable, str(Path(__file__).with_name("test_class_fold.py")), "--client"],
                              stdin=sp.PIPE, stdout=sp.PIPE, text=True)
                    wid = p.stdout.readline().strip()
                    p.stdin.write("map\n"); p.stdin.flush()
                    assert p.stdout.readline().strip() == "OK"
                    wait_for(lambda: wid in output("window", "ids", "--all"), "map")
                    cli("group", "add", "2", wid)
                    windows.append(wid)
                wid = windows[0]
                cli("window", "focus", wid)
                base_children = child_ids()
                base_count = len(base_children)
                client = session()
                assert native("current") == output("group", "current")
                assert native("focused") == output("window", "focused")
                reply_window, = child_ids() - base_children
                for _ in range(4):
                    assert native("snapshot").startswith("0 SNAPSHOT 2|")
                    response_absent(reply_window)
                    error = native("hide-detail 0x7fffffff")
                    assert error == "1 unknown or unmanaged window", error
                    response_absent(reply_window)
                    assert child_ids() - base_children == {reply_window}
                assert native("snapshot").startswith("0 SNAPSHOT 2|")

                for all_flag in (False, True):
                    for selector, pattern in ((0, ""), (1, "LifecycleTest"), (2, ".*")):
                        for group in (0, 2, 3):
                            args = ["window", "ids"] + (["--all"] if all_flag else [])
                            if selector == 1: args += [pattern]
                            if selector == 2: args += ["--name", pattern]
                            if group: args += ["--group", str(group)]
                            assert native(f'ids {"all" if all_flag else "mapped"} {selector} {group} {pattern}') == output(*args).replace("\n", "|")
                # Group payloads must not leak into the next unfiltered request.
                assert native("ids all 0 0") == "|".join(sorted(windows))
                for command, expected in (("move 123 147", (123,147,160,100)),
                                          ("resize 200 150", (123,147,200,150)),
                                          ("relative -20 10", (103,157,200,150))):
                    native(command + " " + wid)
                    geometry = output("window", "geometry", wid)
                    assert tuple(int(line.split("=")[1]) for line in geometry.splitlines()) == expected
                    assert native("geometry " + wid) == geometry.replace("\n", "|")
                for verb in ("stack", "stack-geometries"):
                    assert native(verb + " " + wid) == output("window", verb, wid).replace("\n", "|")
                assert native("snapshot") == "0 " + output("window", "snapshot").replace("\n", "|")
                token = next(line.split()[-1] for line in output("window", "snapshot").splitlines()
                             if line.startswith("CLIENT " + wid + " "))
                native(f"checked {wid} {token} 70 80 210 160")
                assert "WIDTH=210" in output("window", "geometry", wid)
                native(f"apply {wid} 100 100 180 120")
                native("raise " + " ".join(windows))
                assert native("hide " + wid) == "0"
                assert wid not in native("ids mapped 0 0")
                assert wid in native("ids all 0 0")
                assert native("focus " + wid) == "0"
                assert native("focused") == wid
                native("remove " + wid)
                assert wid not in native("ids all 0 2")
                native("add 3 " + wid)
                assert native("ids all 0 3") == wid
                native("deactivate 3")
                assert wid not in native("ids mapped 0 3")
                native("activate 3")
                assert native("ids mapped 0 3") == wid
                native("clear 3")
                assert native("ids all 0 3") == ""
                native("add 2 " + wid)
                native("focus " + windows[1]); native("focus " + wid)
                native("last")
                assert native("focused") == output("window", "focused")
                # Compare cardinal focus after resetting the same source each time.
                for direction, name in enumerate(("north", "east", "south", "west")):
                    cli("window", "focus", wid)
                    cli("window", "focus", "--cardinal", name)
                    expected = output("window", "focused")
                    native("focus " + wid)
                    native("cardinal " + str(direction))
                    assert native("focused") == expected
                for _ in range(100): native("snapshot")
                assert child_count() == base_count + 1, "reply windows leaked"
                client.stdin.close(); client.wait(timeout=5)
                wait_for(lambda: child_count() == base_count, "reply window exit cleanup")
                client = session()
                # Preserve CLI validation and acknowledged WM errors.
                check_layers(zephyr, cirrus + "/sirocco", env, wid)
                assert cli("window", "layer", "above", "0x7fffffff", check=False).returncode != 0
                assert native("hide 0x7fffffff") != "0"
                for w in windows: z("window", "layer", "normal", w)
                # Existing daemon cache and sequential query -> geometry -> query chain.
                daemon_process = start([daemon])
                wait_for(lambda: z("window", "ids", "--all", check=False).returncode == 0, "daemon bootstrap")
                before = output("window", "geometry", wid)
                cli("window", "focus", wid)
                chain = z("window", "geometry", wid, ".", "window", "move", "7", "9", ".",
                          "window", "geometry", wid).stdout.strip().splitlines()
                assert "\n".join(chain[:4]) == before
                assert int(chain[4].split("=")[1]) == int(chain[0].split("=")[1]) + 7
                assert int(chain[5].split("=")[1]) == int(chain[1].split("=")[1]) + 9
                if len(sys.argv) > 5:
                    baseline = str(Path(sys.argv[5]).resolve())
                    for label, args, repeats in (("group count", ["group","count"], 40),
                                                 ("six-window group fold", ["layout","fold","3","--rows","2","--group","2"], 20)):
                        samples = {baseline: [], zephyr: []}
                        for binary in samples:
                            z(*args, binary=binary)
                        for _ in range(repeats):
                            for binary in samples:
                                begin = time.perf_counter()
                                z(*args, binary=binary)
                                samples[binary].append((time.perf_counter()-begin)*1000)
                        print(f"BENCH {label}: before={statistics.median(samples[baseline]):.3f}ms after={statistics.median(samples[zephyr]):.3f}ms (median, n={repeats})")
                native("close " + windows[-1])
                wait_for(lambda: windows[-1] not in native("ids all 0 0"), "native close")
                daemon_process.terminate(); daemon_process.wait(timeout=5)
                native("snapshot")
                # Separate submission-only behavior from acknowledged completion.
                # Identify this probe's reply window by closing and reopening its session.
                assert native("connection-failure") == "1 CONNECT"
                baseline_children = child_ids()
                assert native("snapshot").startswith("0 SNAPSHOT 2|")
                reply_window, = child_ids() - baseline_children
                wm.send_signal(signal.SIGSTOP)
                # waitpid confirms the WM is stopped, rather than racing signal delivery.
                assert os.WIFSTOPPED(os.waitpid(wm.pid, os.WUNTRACED)[1])
                begin = time.monotonic()
                assert native("focus " + wid) == "0"
                assert time.monotonic() - begin < 1.5, "fire-and-forget waited for WM"
                # A hide must wait despite noise and old response-deletion notifications.
                begin = time.monotonic()
                client.stdin.write("hide-detail " + wid + "\n"); client.stdin.flush()
                property_noise(reply_window)
                assert select.select([client.stdout], [], [], 5)[0]
                assert client.stdout.readline().strip() == "1 TIMEOUT (completion unknown)"
                assert 1.8 <= time.monotonic() - begin < 5
                assert reply_window not in child_ids(), "timeout retained reply window"
                # Start the very next acknowledged request BEFORE resuming the WM.
                # Both requests are now queued at the stopped WM; the old hide reply
                # must not satisfy this new snapshot even if XCB reuses a client ID.
                client.stdin.write("snapshot\n"); client.stdin.flush()
                wait_for(lambda: bool(child_ids() - baseline_children), "fresh reply window")
                fresh_window, = child_ids() - baseline_children
                assert fresh_window != reply_window, "reused an ambiguous reply XID"
                wm.send_signal(signal.SIGCONT)
                assert select.select([client.stdout], [], [], 5)[0]
                reply = client.stdout.readline().strip()
                assert reply.startswith("0 SNAPSHOT 2|"), (reply_window, fresh_window, reply)
                assert wid not in native("ids mapped 0 0")
                response_absent(fresh_window)
                # WM restart does not disconnect X; next request reaches the new WM.
                wm.terminate(); wm.wait(timeout=5)
                assert native("snapshot").startswith("1 ")
                assert cli("window", "snapshot", check=False).returncode != 0
                assert native("focus " + wid) == "0"  # same submission-only guarantee as C
                assert cli("window", "focus", wid, check=False).returncode == 0
                wm = start([cirrus + "/cirrus", "-c", "/bin/true"])
                wait_for(lambda: cli("group", "count", check=False).returncode == 0, "WM restart")
                assert native("snapshot").startswith("0 SNAPSHOT 2|")
                # Actual X connection loss invalidates the persistent session.
                old_atoms = protocol_atoms()
                server.terminate(); server.wait(timeout=5)
                assert native("snapshot").startswith("1 ")
                server = start(["Xvfb", env["DISPLAY"], "-screen", "0", "1024x768x24", "-nolisten", "tcp", "-noreset"])
                wait_for(lambda: sp.run(["xdpyinfo"], env=env, stdout=sp.DEVNULL, stderr=sp.DEVNULL).returncode == 0, "X restart")
                # Force different atom IDs; success must not depend on coincidental
                # reuse of identifiers from the previous X server.
                new_atoms = protocol_atoms(seed=256)
                assert all(old != new for old, new in zip(old_atoms, new_atoms))
                wm = start([cirrus + "/cirrus", "-c", "/bin/true"])
                wait_for(lambda: cli("group", "count", check=False).returncode == 0, "new WM")
                assert native("snapshot").startswith("0 SNAPSHOT 2|")
                print("PASS: native/C query and mutation parity, filters, hidden clients, identities, reply reuse/cleanup, CLI validation, chained geometry, timeout/late reply, absent/restarted WM, X disconnect/reconnect")
            except BaseException:
                log.flush(); log.seek(0); print(log.read())
                raise
            finally:
                os.close(rd)
                for p in reversed(children):
                    if p.poll() is None:
                        p.send_signal(signal.SIGCONT)
                        p.terminate()
                        try: p.wait(timeout=5)
                        except sp.TimeoutExpired: p.kill(); p.wait()


if __name__ == "__main__":
    run()
