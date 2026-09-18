"""Fold/group explode integration test; argv: cirrus-dir zephyr zephyrd."""
import ctypes as C
import os
from pathlib import Path
import select
import subprocess
import sys
import tempfile
import time
from test_window_lifecycle import wait_for

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
    hint = ClassHint(b"lifecycle-test", b"Other" if "--other-client" in sys.argv else b"LifecycleTest")
    x.XSetClassHint(display, window, C.byref(hint))
    class SizeHints(C.Structure):
        _fields_ = [("flags", C.c_long)] + [(name,C.c_int) for name in
            ("x","y","width","height","min_width","min_height","max_width",
             "max_height","width_inc","height_inc","min_aspect_x","min_aspect_y",
             "max_aspect_x","max_aspect_y","base_width","base_height","win_gravity")]
    x.XSetWMNormalHints.argtypes=[C.c_void_p,C.c_ulong,C.POINTER(SizeHints)]
    hints=SizeHints();hints.flags=16;hints.min_width=1;hints.min_height=1
    x.XSetWMNormalHints(display,window,C.byref(hints))
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




def run():
    cirrus, zephyr, zephyrd = map(lambda p: str(Path(p).resolve()), sys.argv[1:4])
    children = []
    with tempfile.TemporaryDirectory(prefix="zephyr-ids-group-") as directory:
        root = Path(directory)
        env = dict(os.environ, PATH=cirrus + os.pathsep + os.environ["PATH"])
        for name in ("WINFO", "GROUP", "HIDDEN", "WME", "FIFO", "WMSE", "XDG_RUNTIME_DIR"):
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
                for i in range(4):
                    p = start([sys.executable, __file__, "--client"], stdin=subprocess.PIPE,
                              stdout=subprocess.PIPE, text=True)
                    xid = p.stdout.readline().strip()
                    p.stdin.write("map\n"); p.stdin.flush()
                    assert p.stdout.readline().strip() == "OK"
                    time.sleep(.15)
                    command("group", "add", "2" if i < 2 else "4", xid)
                    subprocess.run(["xprop", "-id", xid, "-f", "WM_NAME", "8s", "-set",
                                    "WM_NAME", "foo title"], env=env, check=True, stdout=log)
                    windows.append(xid)
                daemon = start([zephyrd])
                # Wait for the standard snapshot bootstrap, not a special group seed.
                def ready():
                    p = subprocess.run([zephyr, "window", "ids", "--all"], env=env,
                                       capture_output=True, text=True, timeout=5)
                    return p.returncode == 0 and set(p.stdout.splitlines()) == set(windows)
                wait_for(ready, "cache did not bootstrap")
                def geometry(wid):
                    return command("window", "geometry", wid).strip()
                def layout(*args):
                    subprocess.run([zephyr, "layout", *args], env=env, check=True, timeout=5)
                def focused():
                    return command("window", "focused").strip()
                for i,w in enumerate(windows):
                    command("window","apply-geometries",w,str(80+i*40),"100","180","120")
                original={w:geometry(w) for w in windows}
                focus_before=focused()
                layout("fold","4","--rows","3","--spread","LifecycleTest")
                saved=Path(env["WME"])/"layout"/"fold:class:LifecycleTest"
                assert saved.is_dir() and len(list(saved.iterdir()))==4
                first={str(p.relative_to(saved)) for p in saved.rglob("*")}
                assert focused()==focus_before
                layout("fold","3","LifecycleTest")
                assert first=={str(p.relative_to(saved)) for p in saved.rglob("*")}
                # New instance after the first fold participates in re-fold, not unfold.
                p=start([sys.executable,__file__,"--client"],stdin=subprocess.PIPE,stdout=subprocess.PIPE,text=True)
                new=p.stdout.readline().strip();p.stdin.write("map\n");p.stdin.flush()
                assert p.stdout.readline().strip()=="OK"
                wait_for(lambda:new in ids("LifecycleTest"),"new class client not cached")
                command("window","apply-geometries",new,"60","70","150","110")
                layout("fold","4","LifecycleTest")
                new_geometry=geometry(new)
                assert first=={str(p.relative_to(saved)) for p in saved.rglob("*")}
                # Independent class operation using a distinct window/class.
                other=start([sys.executable,__file__,"--other-client"],stdin=subprocess.PIPE,stdout=subprocess.PIPE,text=True)
                other_id=other.stdout.readline().strip()
                other.stdin.write("map\n");other.stdin.flush();assert other.stdout.readline().strip()=="OK"
                wait_for(lambda:other_id in ids("Other"),"other class not cached")
                command("window","apply-geometries",other_id,"200","200","180","120")
                other_original=geometry(other_id)
                layout("fold","3","Other")
                other_root=saved.with_name("fold:class:Other")
                assert other_root.is_dir()
                # Recorded identity remains authoritative despite a classname change.
                subprocess.run(["xprop","-id",windows[0],"-f","WM_CLASS","8s","-set","WM_CLASS","Changed"],env=env,check=True,stdout=log)
                # Destroy one original and simulate a reused XID by mismatching its token.
                command("window","close",windows[1])
                wait_for(lambda:windows[1] not in ids("--all"),"destroy not observed")
                record=next(p for p in saved.iterdir() if p.name.endswith(windows[2]))
                identity=next(p for p in record.iterdir() if p.name.startswith("ID="))
                identity.rename(identity.with_name("ID="+"0"*32+":0000000000000001"))
                reused_geometry=geometry(windows[2])
                command("window","hide",windows[3])
                command("window","focus",other_id)
                layout("unfold","LifecycleTest")
                assert focused()==other_id
                assert geometry(windows[0])==original[windows[0]]
                assert geometry(windows[3])==original[windows[3]]
                assert geometry(windows[2])==reused_geometry
                assert geometry(new)==new_geometry
                assert not saved.exists() and other_root.exists()
                layout("unfold","Other")
                assert geometry(other_id)==other_original and not other_root.exists()
                missing=subprocess.run([zephyr,"layout","unfold","Other"],env=env,capture_output=True,text=True)
                assert missing.returncode!=0 and "no fold state for Other" in missing.stderr
                for args in ([],["Other","extra"],["--group","2"]):
                    invalid=subprocess.run([zephyr,"layout","unfold",*args],env=env,capture_output=True,text=True)
                    assert invalid.returncode!=0
                # Existing default/group fold and stack/group explode paths remain independent.
                survivors=[windows[0],windows[2],windows[3],new,other_id]
                for w in survivors:
                    command("window","focus",w)
                    command("window","apply-geometries",w,"100","100","180","120")
                wait_for(lambda:windows[3] in ids(),"hidden fixture not remapped")
                before={w:geometry(w) for w in survivors}
                layout("explode","--group","4");layout("unexplode","--group","4")
                assert {w:geometry(w) for w in survivors}==before
                layout("explode");layout("unexplode")
                assert {w:geometry(w) for w in survivors}==before
                layout("fold","4","--group","4")
                layout("fold","4")
                assert not any((Path(env["WME"])/"layout").glob("fold:class:*"))
                print("PASS: class fold/refold, new clients, destroyed clients, token mismatch, class change, hidden clients, independent classes, focus, one-shot state")

            except BaseException:
                log.flush(); log.seek(0); print(log.read())
                raise
            finally:
                os.close(read_fd)
                for p in reversed(children):
                    if p.poll() is None:
                        p.terminate(); p.wait(timeout=5)


if __name__ == "__main__":
    if sys.argv[1:] in (["--client"], ["--other-client"]):
        client()
    else:
        run()
