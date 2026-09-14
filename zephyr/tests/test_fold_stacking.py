"""Fold/group explode integration test; argv: cirrus-dir zephyr zephyrd."""
import ctypes as C
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
                    command("window", "apply-geometries", w, str(80+i*40), "100", "180", "120")
                x = C.CDLL("libX11.so.6")
                x.XOpenDisplay.argtypes=[C.c_char_p];x.XOpenDisplay.restype=C.c_void_p
                x.XDefaultRootWindow.argtypes=[C.c_void_p];x.XDefaultRootWindow.restype=C.c_ulong
                x.XQueryTree.argtypes=[C.c_void_p,C.c_ulong,C.POINTER(C.c_ulong),C.POINTER(C.c_ulong),C.POINTER(C.POINTER(C.c_ulong)),C.POINTER(C.c_uint)]
                x.XFree.argtypes=[C.c_void_p]
                x.XCloseDisplay.argtypes=[C.c_void_p]
                def order():
                    display=x.XOpenDisplay(env["DISPLAY"].encode());assert display
                    root_id=C.c_ulong();parent=C.c_ulong();items=C.POINTER(C.c_ulong)();count=C.c_uint()
                    assert x.XQueryTree(display,x.XDefaultRootWindow(display),C.byref(root_id),C.byref(parent),C.byref(items),C.byref(count))
                    result=[items[i] for i in range(count.value)]
                    x.XFree(items);x.XCloseDisplay(display)
                    return {w:result.index(int(w,16)) for w in windows}
                names=["normal","above","overlay"]
                for bands in [(0,0,0,0),(0,1,1,0),(1,0,0,2),(2,0,2,1)]:
                    for w,band in zip(windows,bands):command("window","layer",names[band],w)
                    command("window","focus",windows[3])
                    for repeat in range(2):
                        # Raise unrelated peers between repeats; the second fold changes no geometry.
                        command("window","raise-many",*windows[2:])
                        layout("fold","3","--rows","1","--group","2")
                        assert focused()==windows[3]
                        positions=order()
                        for i in range(4):
                            for j in range(4):
                                if bands[i]>bands[j]:assert positions[windows[i]]>positions[windows[j]]
                        for i in range(2):
                            for j in range(2,4):
                                if bands[i]==bands[j]:assert positions[windows[i]]>positions[windows[j]]
                        if bands[0]==bands[1]:assert positions[windows[1]]>positions[windows[0]]
                    # Group explode reuses the same explicit stacking helper.
                    command("window","raise-many",*windows[2:])
                    layout("explode","--group","2")
                    positions=order()
                    for i in range(2):
                        for j in range(2,4):
                            if bands[i]==bands[j]:assert positions[windows[i]]>positions[windows[j]]
                    layout("unexplode","--group","2")
                for w in windows:
                    command("window","layer","normal",w)
                    command("window","apply-geometries",w,"100","100","180","120")
                original = {w: geometry(w) for w in windows}
                focus_before = focused()
                layout("fold", "3", "--rows", "1", "--group", "2")
                folded = {w: geometry(w) for w in windows[:2]}
                assert any(folded[w] != original[w] for w in windows[:2])
                assert focused() == focus_before
                # Restore exact source rectangles for the explode comparison.
                for w in windows[:2]:
                    fields = [part.split("=", 1)[1] for part in original[w].split()]
                    command("window", "apply-geometries", w, *fields)
                layout("explode", "--group", "2")
                assert {w: geometry(w) for w in windows[:2]} == folded
                assert focused() == focus_before
                group2 = Path(env["WME"]) / "layout" / "explode:group:2"
                group4 = group2.with_name("explode:group:4")
                assert group2.is_dir()
                assert all(geometry(w) == original[w] for w in windows[2:])
                layout("explode", "--group", "4")
                exploded4 = {w: geometry(w) for w in windows[2:]}
                assert group4.is_dir()
                # Restore by recorded identity despite membership changes and hiding.
                command("group", "add", "4", windows[0])
                command("window", "hide", windows[1])
                command("window", "focus", windows[2])
                focus_before = focused()
                layout("unexplode", "--group", "2")
                assert all(geometry(w) == original[w] for w in windows[:2]), ({w:geometry(w) for w in windows[:2]}, original)
                assert focused() == focus_before
                assert not group2.exists() and group4.exists()
                assert {w: geometry(w) for w in windows[2:]} == exploded4
                # A newly added group member must not join an existing restore set.
                command("group", "add", "4", windows[1])
                new_member_geometry = geometry(windows[1])
                # Simulate XID reuse: the recorded token no longer identifies this client.
                record = next(p for p in group4.iterdir() if p.name.endswith(windows[2]))
                identity = next(p for p in record.iterdir() if p.name.startswith("ID="))
                identity.rename(identity.with_name("ID=" + "0" * 32 + ":0000000000000001"))
                layout("unexplode", "--group", "4")
                assert geometry(windows[2]) == exploded4[windows[2]]
                assert geometry(windows[3]) == original[windows[3]]
                assert geometry(windows[1]) == new_member_geometry
                assert focused() == focus_before
                assert not group4.exists()
                # Destroyed original entries are ignored without retaining stale state.
                command("group", "add", "2", windows[0])
                wait_for(lambda: ids("--group", "2") == [windows[0]], "group not ready")
                layout("explode", "--group", "2")
                command("window", "close", windows[0])
                wait_for(lambda: windows[0] not in ids("--all"), "destroy not observed")
                layout("unexplode", "--group", "2")
                assert not group2.exists()
                empty = subprocess.run([zephyr,"layout","explode","--group","2"],env=env,
                                       capture_output=True,text=True)
                assert empty.returncode != 0
                assert "no matching windows" in empty.stderr
                print("PASS: mixed-layer fold raises, no-op repeats, participant order, unrelated focus, group explode raises, fold/grid equivalence, exact group restore, independent roots, migration, hidden restore, token mismatch, new members, destruction, focus")

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
