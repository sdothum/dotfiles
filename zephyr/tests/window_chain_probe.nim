## Keeps one value chain alive while the test changes focus from another process.
import std/[strutils]
import ../wm/constants
import ../wm/window as window

var chain: window.WindowChain
var captured = false
for line in stdin.lines:
  let args = line.splitWhitespace()
  if args.len == 0: continue
  if args[0] == "capture":
    if args.len == 2: chain = window.target(args[1])
    else: chain = window.target()
    captured = true
  else:
    if not captured: quit("test chain has no captured target")
    case args[0]
    of "size": chain = chain.size(args[1])
    of "size-rotated": chain = chain.size(A4, Rotate)
    of "snap": chain = chain.snap(args[1])
    of "snap-vertical": chain = chain.snap(Center, Vertical)
    of "move": chain = chain.move(parseInt(args[1]), parseInt(args[2]))
    of "shift": chain = chain.shift(args[1])
    of "group": chain = chain.group(args[1])
    of "group-id": chain = chain.group(parseInt(args[1]))
    of "spread": chain = chain.spread(args[1])
    of "tile": chain = chain.tile(args[1], args[2])
    of "layer":
      let layer = case args[1].toLowerAscii()
        of "normal": window.Normal
        of "above": window.Above
        of "overlay": window.Overlay
        else: quit("invalid probe layer")
      chain = chain.layer(layer)
    of "focus": chain = chain.focus()
    of "stack-cycle": chain = chain.stackCycle()
    else: quit("unknown chain operation " & args[0])
  echo chain.capturedWinid()
  stdout.flushFile()
