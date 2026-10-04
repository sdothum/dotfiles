"""Fluent WindowChain behavior on a private Xvfb/cirrus fixture."""
import os
from pathlib import Path
import select
import subprocess as sp
import sys
import tempfile
from test_window_lifecycle import wait_for


def run():
    cirrus, zephyr, probe, zephyrd = [str(Path(p).resolve()) for p in sys.argv[1:5]]
    children = []
    with tempfile.TemporaryDirectory(prefix="zephyr-window-chain-") as directory:
        root = Path(directory)
        env = dict(os.environ, PATH=cirrus + os.pathsep + os.environ["PATH"])
        env.pop("DISPLAY", None)
        for key in ("WINFO", "GROUP", "HIDDEN", "WME", "WMSE", "FIFO", "XDG_RUNTIME_DIR"):
            path = root / key.lower(); path.mkdir(); env[key] = str(path)
        with (root / "fixture.log").open("w+") as log:
            def start(args, **kwargs):
                p = sp.Popen(args, env=env, stdout=kwargs.pop("stdout", log),
                             stderr=kwargs.pop("stderr", log), **kwargs)
                children.append(p); return p
            def wm(*args):
                return sp.check_output([cirrus + "/sirocco", *args], env=env, text=True).strip()
            def command(*args):
                result = sp.run([zephyr, *args], env=env, text=True, capture_output=True, timeout=10)
                assert result.returncode == 0, result.stderr
                return result.stdout.strip()
            def focused(): return wm("window", "focused")
            def geometry(wid): return wm("window", "geometry", wid)
            def group_of(wid):
                for line in wm("window", "snapshot").splitlines():
                    fields = line.split()
                    if len(fields) >= 5 and fields[0] == "CLIENT" and fields[1] == wid:
                        return fields[2]
                raise AssertionError("client missing from WM snapshot: " + wid)
            def size_of(value):
                return tuple(int(line.split("=")[1]) for line in value.splitlines()
                             if line.startswith(("WIDTH=", "HEIGHT=")))
            rd, wr = os.pipe()
            server = start(["Xvfb", "-displayfd", str(wr), "-screen", "0", "1280x900x24",
                            "-nolisten", "tcp"], pass_fds=(wr,))
            os.close(wr)
            try:
                assert select.select([rd], [], [], 10)[0]
                env["DISPLAY"] = ":" + os.read(rd, 64).decode().strip()
                start([cirrus + "/cirrus", "-c", "/bin/true"])
                wait_for(lambda: sp.run([cirrus + "/sirocco", "group", "count"], env=env,
                                        stdout=sp.DEVNULL, stderr=sp.DEVNULL).returncode == 0,
                         "private cirrus startup")
                windows = []
                for _ in range(3):
                    p = start([sys.executable, str(Path(__file__).with_name("test_class_fold.py")), "--client"],
                              stdin=sp.PIPE, stdout=sp.PIPE, text=True)
                    wid = p.stdout.readline().strip(); p.stdin.write("map\n"); p.stdin.flush()
                    assert p.stdout.readline().strip() == "OK"
                    wait_for(lambda: wid in wm("window", "ids", "--all").splitlines(), "window map")
                    windows.append(wid)
                daemon = start([zephyrd])
                wait_for(lambda: set(command("window", "ids", "--all").splitlines()) == set(windows),
                         "daemon snapshot bootstrap")
                a, b, c = windows
                for wid, x, y in ((a, 100, 100), (b, 400, 250), (c, 700, 400)):
                    wm("window", "apply-geometries", wid, str(x), str(y), "180", "120")
                p = start([probe], stdin=sp.PIPE, stdout=sp.PIPE, stderr=sp.PIPE, text=True)
                def act(*args):
                    p.stdin.write(" ".join(args) + "\n"); p.stdin.flush()
                    ready = select.select([p.stdout], [], [], 8)[0]
                    if not ready or p.poll() is not None:
                        raise AssertionError((args, p.poll(), p.stderr.read()))
                    reply = p.stdout.readline().strip()
                    if not reply: raise AssertionError((args, p.poll(), p.stderr.read()))
                    return reply

                wm("window", "focus", a)
                assert act("capture") == a
                wm("window", "focus", b)
                wait_for(lambda: focused() == b, "focus changed to second client")
                assert act("spread", "left") == a
                command("window", "spread", "left", b)
                assert geometry(a) == geometry(b)
                wait_for(lambda: focused() == b, "spread chain changed focus")
                assert act("tile", "3", "2") == a
                command("window", "tile", "3", "2", b)
                assert geometry(a) == geometry(b)
                wait_for(lambda: focused() == b, "tile chain changed focus")

                # The layout grid path and CLI placement path must produce
                # identical rectangles after resolving to the same cell.
                for layout_args, window_args in (
                    (("tile", "3", "--rows", "2", "--position", "4"),
                     ("tile", "3", "3", "--rows", "2", "--row", "2")),
                    (("tile", "3", "--rows", "2", "--position", "7"),
                     ("tile", "3", "2", "--rows", "2", "--row", "1")),
                    (("spread", "3", "--rows", "2", "--position", "4"),
                     ("spread", "3", "3", "--rows", "2", "--row", "2")),
                ):
                    wm("window", "focus", b)
                    command("window", *window_args, a)
                    expected = geometry(a)
                    command("layout", *layout_args, a)
                    assert geometry(a) == expected, (layout_args, window_args)
                    wait_for(lambda: focused() == b,
                             "grid placement changed the authoritative focus")

                wm("window", "focus", b)
                command("window", "spread", "3", "3", "--rows", "2", "bottom", a)
                named_geometry = geometry(a)
                command("window", "spread", "3", "3", "--rows", "2",
                        "--row", "2", a)
                assert geometry(a) == named_geometry, "named spread selectors changed placement"
                wait_for(lambda: focused() == b, "spread selector changed focus")

                old_a, old_b = geometry(a), geometry(b)
                focus_before_size = focused()
                assert act("size", "A4") == a
                assert size_of(geometry(a)) != size_of(old_a)
                assert geometry(b) == old_b
                wait_for(lambda: focused() == focus_before_size,
                         "size chain changed focus from " + focus_before_size + " to " + focused())
                assert act("size-rotated") == a
                assert act("snap", "Center") == a
                wait_for(lambda: focused() == b, "snap chain changed focus")
                assert act("snap-vertical") == a
                wait_for(lambda: focused() == b, "typed snap chain changed focus")
                assert act("move", "20", "-10") == a
                assert act("shift", "right") == a
                wait_for(lambda: focused() == b, "move/shift chain changed focus")
                assert act("layer", "above") == a
                state = sp.check_output(["xprop", "-id", a, "_NET_WM_STATE"], env=env, text=True)
                assert "_NET_WM_STATE_ABOVE" in state
                wait_for(lambda: focused() == b, "layer chain changed focus")
                assert act("layer", "overlay") == a
                wait_for(lambda: focused() == b, "overlay chain changed focus")
                assert act("layer", "normal") == a
                wait_for(lambda: focused() == b, "normal layer restore changed focus")
                assert act("focus") == a and focused() == a

                # Explicit stack-cycle is anchored to the captured client's
                # overlapping stack even when another, non-overlapping client
                # has focus. Put A at the top of its A/C stack so cycling A
                # must select C.
                wm("window", "apply-geometries", a, "100", "100", "180", "120")
                wm("window", "apply-geometries", c, "100", "100", "180", "120")
                wm("window", "apply-geometries", b, "700", "500", "180", "120")
                wm("window", "focus", a)
                stack_order = wm("window", "stack", a).splitlines()
                assert set(stack_order) == {a, c}, (stack_order, a, c)
                assert stack_order[-1] == a, (stack_order, a)
                wm("window", "focus", b)
                assert act("stack-cycle") == a
                assert focused() == c, ("explicit cycle did not use A's stack", focused(), a, c)

                # The original focused-window form is unchanged, and a
                # one-window stack remains focused on its sole member.
                wm("window", "focus", b)
                wm("window", "stack", "cycle")
                assert focused() == b, "focused single-window cycle changed focus"
                wm("window", "stack", "cycle", b)
                assert focused() == b, "explicit single-window cycle changed focus"

                wm("window", "focus", b)
                wait_for(lambda: focused() == b, "focus changed before group assignment")
                active_before_group = wm("group", "current")
                assert act("group", "COMM") == a
                wait_for(lambda: focused() == b, "group chain changed focus")
                assert group_of(a) == "2"
                assert wm("group", "current") == active_before_group
                assert act("group-id", "2") == a
                p.stdin.close(); p.wait(timeout=5)

                p = start([probe], stdin=sp.PIPE, stdout=sp.PIPE, stderr=sp.PIPE, text=True)
                assert act("capture", b) == b
                wm("window", "focus", c)
                wait_for(lambda: focused() == c, "focus changed to third client")
                b_before, c_before = geometry(b), geometry(c)
                assert act("size", "720p") == b
                assert geometry(c) == c_before and geometry(b) != b_before
                assert act("layer", "above") == b
                state = sp.check_output(["xprop", "-id", b, "_NET_WM_STATE"], env=env,
                                        text=True)
                assert "_NET_WM_STATE_ABOVE" in state
                assert act("layer", "normal") == b
                wait_for(lambda: focused() == c, "explicit chain size changed focus")
                assert act("focus") == b and focused() == b
                p.stdin.close(); p.wait(timeout=5)

                wm("window", "focus", c)
                command("window", "snap", "center", a)
                assert focused() == a
                wm("window", "focus", b)
                command("window", "move", "7", "9")
                assert focused() == b

                p = start([probe], stdin=sp.PIPE, stdout=sp.PIPE, stderr=sp.PIPE, text=True)
                assert act("capture", a) == a
                wm("window", "close", a)
                wait_for(lambda: a not in wm("window", "ids", "--all").splitlines(), "target destruction")
                wm("window", "focus", c)
                c_before = geometry(c)
                p.stdin.write("size 480p\n"); p.stdin.flush(); p.stdin.close()
                assert p.wait(timeout=8) != 0
                error = p.stderr.read()
                assert "captured window no longer exists" in error or "identity changed" in error, error
                assert geometry(c) == c_before and focused() == c

                # Public group commands still use one-based IDs. Focus and
                # toggle operate on group 2 without changing the ID mapping.
                wm("window", "focus", b)
                command("window", "group", "1")
                command("group", "add", "1", b)
                wait_for(lambda: group_of(b) == "1", "group-1 membership cache")
                wm("window", "focus", c)
                command("window", "group", "2")
                command("group", "add", "2")
                wait_for(lambda: group_of(c) == "2", "group-2 membership cache")
                for invalid in ("0", "999", "nonnumeric"):
                    result = sp.run([zephyr, "group", "focus", invalid], env=env,
                                    text=True, capture_output=True, timeout=8)
                    assert result.returncode != 0, (invalid, result.stdout, result.stderr)
                command("group", "focus", "1")
                current, active = wm("group", "current"), focused()
                assert current == "1" and active == b, ("focus group 1", current, active, b)
                command("group", "focus", "2")
                assert wm("group", "current") == "2" and focused() == c
                command("group", "toggle", "2")
                command("group", "toggle", "2")
                assert wm("group", "current") == "2" and focused() == c

                # The CLI teleport switch retains its old focus behavior;
                # fluent .group() above remains non-teleporting.
                wm("window", "focus", b)
                command("window", "group", "2")
                command("group", "add", "2")
                command("group", "focus", "2")
                wm("window", "focus", c)
                command("window", "group", "3", "--teleport")
                assert group_of(c) == "3"
                assert wm("group", "current") == "2" and focused() == b
                print("PASS: focused/explicit capture; group/spread/tile/stack-cycle targets; stack-cycle focus anchor; geometry persistence; focus preservation; destroyed-client rejection; CLI focus behavior")
            except BaseException:
                log.flush(); log.seek(0); print(log.read()); raise
            finally:
                os.close(rd)
                for p in reversed(children):
                    if p.poll() is None:
                        p.terminate()
                        try: p.wait(timeout=5)
                        except sp.TimeoutExpired: p.kill(); p.wait()


if __name__ == "__main__": run()
