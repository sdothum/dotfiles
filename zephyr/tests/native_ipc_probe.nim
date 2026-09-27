# Test driver keeps the production session alive across stdin requests.
import std/[os, strutils]
import ../wm/native_ipc as ipc
for line in stdin.lines:
  let args = line.splitWhitespace()
  if args.len == 0: continue
  case args[0]
  of "current": echo ipc.groupCurrent()
  of "focused": echo ipc.focused()
  of "snapshot":
    let reply = ipc.snapshot()
    echo $reply.status & " " & reply.output.replace("\n", "|") & reply.error
  of "move":
    ipc.move(parseInt(args[1]), parseInt(args[2]), ipc.windowId(args[3]))
    echo "OK"
  of "geometry": echo ipc.geometry(ipc.windowId(args[1])).replace("\n", "|")
  of "resize":
    ipc.resize(parseInt(args[1]), parseInt(args[2]), ipc.windowId(args[3]))
    echo "OK"
  of "relative":
    ipc.move(parseInt(args[1]), parseInt(args[2]), ipc.windowId(args[3]), relative = true)
    echo "OK"
  of "focus": echo ipc.focus(ipc.windowId(args[1])).status
  of "last":
    ipc.focusLast()
    echo "OK"
  of "cardinal":
    ipc.focusCardinal(ipc.Direction(parseInt(args[1])))
    echo "OK"
  of "hide": echo ipc.hide(ipc.windowId(args[1])).status
  of "hide-detail":
    let reply = ipc.hide(ipc.windowId(args[1]))
    echo $reply.status & " " & reply.error
  of "connection-failure":
    let display = getEnv("DISPLAY")
    ipc.close()
    putEnv("DISPLAY", ":65534")
    let reply = ipc.snapshot()
    putEnv("DISPLAY", display)
    echo $reply.status & " " & reply.error
  of "ids":
    echo ipc.ids(args[1] == "all", ipc.Selector(parseInt(args[2])),
      (if args.len > 4: args[4] else: ""), parseInt(args[3])).replace("\n", "|")
  of "stack": echo ipc.stack(ipc.windowId(args[1])).replace("\n", "|")
  of "stack-geometries": echo ipc.stackGeometries(ipc.windowId(args[1])).replace("\n", "|")
  of "add":
    ipc.addToGroup(parseInt(args[1]), ipc.windowId(args[2]))
    echo "OK"
  of "remove":
    ipc.removeFromGroup(ipc.windowId(args[1]))
    echo "OK"
  of "activate":
    ipc.activateGroup(parseInt(args[1]))
    echo "OK"
  of "deactivate":
    ipc.deactivateGroup(parseInt(args[1]))
    echo "OK"
  of "clear":
    ipc.clearGroup(parseInt(args[1]))
    echo "OK"
  of "raise":
    var targets: seq[ipc.WindowId]
    for arg in args[1 .. ^1]: targets.add(ipc.windowId(arg))
    ipc.raiseMany(targets)
    echo "OK"
  of "apply", "checked":
    let body = args[1 .. ^1].join(" ") & "\n"
    if args[0] == "checked": ipc.applyGeometriesChecked(body)
    else: ipc.applyGeometries(body)
    echo "OK"
  of "close":
    ipc.closeWindow(ipc.windowId(args[1]))
    echo "OK"
  else: quit("unknown probe action")
  stdout.flushFile()
