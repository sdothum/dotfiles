import std/[os, unittest]
import ../wm/[state, window_lifecycle, x11_invalidation]

let root = getTempDir() / ("zephyr-cleanup-" & $getCurrentProcessId())
createDir(root)
putEnv("WINFO", root / "winfo")
let winid = "0x00000042"
let path = getEnv("WINFO") / winid

suite "window state cleanup":
  test "idempotent recursive cleanup and path validation":
    createDir(path / "WIDTH=20")
    check cleanupWindowState(winid)
    check not dirExists(path)
    check cleanupWindowState(winid)
    check not cleanupWindowState("../unrelated")

  test "live restore transaction defers cleanup":
    createDir(path)
    createDir(root / ".restore-all.lock")
    writeFile(root / ".restore-all.lock" / "pid", $getCurrentProcessId())
    check not cleanupWindowState(winid)
    check dirExists(path)
    removeDir(root / ".restore-all.lock")
    check cleanupWindowState(winid)

  test "unavailable X connection never implies destroyed":
    createDir(path)
    var event: X11Invalidation
    var lifecycle = WindowLifecycle(reconcile: true)
    check not lifecycle.service(event)
    check dirExists(path)
    lifecycle.queueDestroyed(0x42)
    check not lifecycle.service(event)
    check dirExists(path)

  test "hidden cleanup is idempotent and validates paths":
    putEnv("HIDDEN", root / "hidden")
    createDir(root / "hidden" / winid / "2:Test")
    check clearHiddenState(winid)
    check not dirExists(root / "hidden" / winid)
    check clearHiddenState(winid)
    check not clearHiddenState("../unrelated")

  test "uncertain visibility preserves hidden-only state":
    createDir(root / "hidden" / winid)
    var event: X11Invalidation
    var lifecycle = WindowLifecycle(reconcile: true)
    lifecycle.queueMapped(0x42)
    check not lifecycle.service(event)
    check dirExists(root / "hidden" / winid)

  test "unset WINFO cannot target relative directories":
    delEnv("WINFO")
    check cleanupWindowState(winid)
    check dirExists(path)

removeDir(root)
