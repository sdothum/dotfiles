"""End-to-end zephyrd cleanup tests on a private Xvfb display.

Run after building zephyrd; pass the cirrus repository directory as argv[1].
"""
import ctypes as C
import os
from pathlib import Path
import select
import subprocess
import sys
import tempfile
import time


def client():
    x = C.CDLL("libX11.so.6")
    class ClassHint(C.Structure):
        _fields_ = [("res_name", C.c_char_p), ("res_class", C.c_char_p)]

    signatures = {
        "XSetClassHint": (C.c_int, [C.c_void_p, C.c_ulong, C.POINTER(ClassHint)]),
        "XOpenDisplay": (C.c_void_p, [C.c_char_p]),
        "XDefaultRootWindow": (C.c_ulong, [C.c_void_p]),
        "XCreateSimpleWindow": (C.c_ulong, [C.c_void_p, C.c_ulong, C.c_int, C.c_int,
                                            C.c_uint, C.c_uint, C.c_uint, C.c_ulong, C.c_ulong]),
        "XMapWindow": (C.c_int, [C.c_void_p, C.c_ulong]),
        "XUnmapWindow": (C.c_int, [C.c_void_p, C.c_ulong]),
        "XDestroyWindow": (C.c_int, [C.c_void_p, C.c_ulong]),
        "XSync": (C.c_int, [C.c_void_p, C.c_int]),
        "XCloseDisplay": (C.c_int, [C.c_void_p]),
    }
    for name, (result, args) in signatures.items():
        function = getattr(x, name)
        function.restype, function.argtypes = result, args
    display = x.XOpenDisplay(None)
    assert display
    window = x.XCreateSimpleWindow(display, x.XDefaultRootWindow(display),
                                   20, 20, 160, 100, 0, 0, 0)
    hint = ClassHint(b"lifecycle-test", b"LifecycleTest")
    x.XSetClassHint(display, window, C.byref(hint))
    x.XSync(display, 0)
    print(f"0x{window:08x}", flush=True)
    for line in sys.stdin:
        action = line.strip()
        if action == "quit":
            break
        function = {"map": x.XMapWindow, "unmap": x.XUnmapWindow,
                    "destroy": x.XDestroyWindow}[action]
        function(display, window)
        x.XSync(display, 0)
        print("OK", flush=True)
    x.XCloseDisplay(display)


def wait_for(predicate, message):
    deadline = time.monotonic() + 6
    while time.monotonic() < deadline:
        if predicate():
            return
        time.sleep(0.05)
    raise AssertionError(message)


def run():
    project = Path(__file__).resolve().parents[1]
    cirrus = Path(sys.argv[1]).resolve()
    children = []
    with tempfile.TemporaryDirectory(prefix="zephyr-lifecycle-") as directory:
        root = Path(directory)
        env = dict(os.environ, PATH=str(cirrus) + os.pathsep + os.environ["PATH"])
        for name in ("WINFO", "GROUP", "HIDDEN", "WME", "FIFO", "XDG_RUNTIME_DIR"):
            path = root / name.lower()
            path.mkdir()
            env[name] = str(path)
        winfo = Path(env["WINFO"])
        logs = []

        def start(args, label, **kwargs):
            log = open(root / (label + ".log"), "w+")
            logs.append(log)
            process = subprocess.Popen(args, env=env, stderr=log,
                                       stdout=kwargs.pop("stdout", log), **kwargs)
            children.append(process)
            return process

        def new_window(mapped=True):
            process = start([sys.executable, __file__, "--client"], "client" + str(len(children)),
                            stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
            assert select.select([process.stdout], [], [], 5)[0], "client did not start"
            xid = process.stdout.readline().strip()
            assert xid.startswith("0x"), xid
            if mapped:
                action(process, "map")
                time.sleep(0.15)
            (winfo / xid / "WIDTH=160").mkdir(parents=True)
            return process, xid

        def action(process, value):
            process.stdin.write(value + "\n")
            process.stdin.flush()
            assert select.select([process.stdout], [], [], 5)[0], "client action timed out"
            assert process.stdout.readline().strip() == "OK"

        def command(*args):
            subprocess.run([str(cirrus / "sirocco"), *args], env=env, check=True, timeout=5)

        def daemon():
            process = start([str(project / "zephyrd")], "daemon" + str(len(children)))
            log = logs[-1]
            wait_for(lambda: "BASELINE" in Path(log.name).read_text(), "daemon failed to bootstrap")
            return process

        read_fd, write_fd = os.pipe()
        server = start(["Xvfb", "-displayfd", str(write_fd), "-screen", "0",
                        "1024x768x24", "-nolisten", "tcp"], "xvfb", pass_fds=(write_fd,))
        os.close(write_fd)
        try:
            assert select.select([read_fd], [], [], 10)[0]
            env["DISPLAY"] = ":" + os.read(read_fd, 64).decode().strip()
            wm = start([str(cirrus / "cirrus"), "-c", "/bin/true"], "wm")
            time.sleep(0.4)
            hidden, hidden_id = new_window(False)
            (winfo / "0xdeadbeef").mkdir()
            observer = daemon()
            wait_for(lambda: not (winfo / "0xdeadbeef").exists(), "startup stale WINFO retained")
            assert (winfo / hidden_id).exists(), "unmapped existing window removed"

            process, xid = new_window()
            command("window", "close", xid)
            wait_for(lambda: not (winfo / xid).exists(), "WM close retained WINFO")

            process, xid = new_window()
            action(process, "destroy")
            wait_for(lambda: not (winfo / xid).exists(), "application destroy retained WINFO")

            process, xid = new_window()
            process.kill()
            process.wait()
            wait_for(lambda: not (winfo / xid).exists(), "crashed client retained WINFO")

            process, xid = new_window()
            anchor, anchor_id = new_window()
            command("window", "focus", xid)
            subprocess.run([str(project / "zephyr"), "window", "hide", xid],
                           env=env, check=True, timeout=5)
            hidden_path = Path(env["HIDDEN"]) / xid
            assert hidden_path.exists(), "normal hide did not record HIDDEN"
            time.sleep(0.5)
            assert hidden_path.exists(), "unrelated focus removed HIDDEN"
            assert (winfo / xid).exists(), "hide removed WINFO"
            command("window", "focus", xid)
            wait_for(lambda: not hidden_path.exists(), "direct focus retained stale HIDDEN")
            assert (winfo / xid).exists(), "show removed WINFO"
            action(process, "unmap")
            hidden_path.mkdir()
            action(process, "map")
            wait_for(lambda: not hidden_path.exists(), "application map retained HIDDEN")
            command("group", "add", "2", xid)
            command("group", "deactivate", "2")
            hidden_path.mkdir()
            time.sleep(0.5)
            assert hidden_path.exists(), "inactive group lost hidden state"
            assert (winfo / xid).exists(), "group deactivation removed WINFO"
            command("group", "activate", "2")
            wait_for(lambda: not hidden_path.exists(), "group reactivation retained HIDDEN")
            action(process, "unmap")
            time.sleep(0.3)
            assert (winfo / xid).exists(), "unmap removed WINFO"

            # Group snapshots own memberships; lifecycle owns hidden state.
            for path in (Path(env["GROUP"]) / "2" / xid,
                         Path(env["GROUP"] + ":focus") / "2" / xid,
                         Path(env["HIDDEN"]) / xid):
                path.mkdir(parents=True, exist_ok=True)
            action(process, "destroy")
            wait_for(lambda: not (winfo / xid).exists(), "hidden destruction retained WINFO")
            wait_for(lambda: not (Path(env["HIDDEN"]) / xid).exists(), "hidden reconciliation failed")
            wait_for(lambda: not (Path(env["GROUP"]) / "2" / xid).exists(), "group reconciliation failed")

            process, xid = new_window()
            lock = winfo.parent / ".restore-all.lock"
            lock.mkdir()
            (lock / "pid").write_text(str(os.getpid()))
            action(process, "destroy")
            time.sleep(0.4)
            assert (winfo / xid).exists(), "cleanup ignored live transaction"
            (lock / "pid").unlink()
            lock.rmdir()
            wait_for(lambda: not (winfo / xid).exists(), "deferred cleanup not retried")

            observer.terminate()
            observer.wait()
            visible, visible_id = new_window()
            (Path(env["HIDDEN"]) / visible_id).mkdir()
            # A live unmanaged/unmapped window must survive both startup scans.
            (Path(env["HIDDEN"]) / hidden_id).mkdir()
            (winfo / hidden_id / "WIDTH=160").rmdir()
            (winfo / hidden_id).rmdir()
            (Path(env["HIDDEN"]) / "0xdeadbeef").mkdir()
            process, xid = new_window()
            action(process, "destroy")
            assert (winfo / xid).exists()
            observer = daemon()
            wait_for(lambda: not (winfo / xid).exists(), "restart retained dead client state")
            wait_for(lambda: not (Path(env["HIDDEN"]) / visible_id).exists(),
                     "restart retained visible HIDDEN entry")
            wait_for(lambda: not (Path(env["HIDDEN"]) / "0xdeadbeef").exists(),
                     "restart retained dead hidden-only entry")
            assert (Path(env["HIDDEN"]) / hidden_id).exists(), "restart removed unmapped HIDDEN"
            assert (winfo / visible_id).exists(), "restart removed visible WINFO"
            action(hidden, "destroy")
            wait_for(lambda: not (Path(env["HIDDEN"]) / hidden_id).exists(),
                     "hidden-only destruction missed")
            assert observer.poll() is None
            print("PASS: WM close, application destruction, crash, hide/unmap/groups, restart, transaction deferral, hidden visibility reconciliation")
        except BaseException:
            for log in logs:
                log.flush()
                print(Path(log.name).name, Path(log.name).read_text()[-5000:])
            raise
        finally:
            os.close(read_fd)
            for process in reversed(children):
                if process.poll() is None:
                    process.terminate()
                    process.wait(timeout=5)
            for log in logs:
                log.close()


if __name__ == "__main__":
    if sys.argv[1:] == ["--client"]:
        client()
    else:
        run()
