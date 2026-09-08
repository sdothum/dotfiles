import std/os

import wm/display
import wm/group
import wm/layout
import wm/rule
import wm/screen
import wm/state
import wm/sync
import wm/window

#
# Native Nim convenience overloads
#

proc splitCommands(args: seq[string]): seq[seq[string]] =
  var cmd: seq[string] = @[]

  for a in args:
    if a == ".":
      if cmd.len == 0:
        quit("empty command in chain")
      result.add(cmd)
      cmd = @[]
    else:
      cmd.add(a)

  if cmd.len > 0:
    result.add(cmd)

proc dispatchCommand(cmd: seq[string]) =
  if cmd.len < 2:
    quit("command requires domain and verb")

  let domain = cmd[0]

  var verb = cmd[1]
  var rest =
    if cmd.len > 2:
      cmd[2 .. ^1]
    else:
      @[]

  case domain
  of "display":
    display.dispatch(verb, rest)

  of "group":
    group.dispatch(verb, rest)

  of "layout":
    layout.dispatch(verb, rest)

  of "rule":
    rule.dispatch(verb, rest)

  of "screen":
    screen.dispatch(verb, rest)

  of "state":
    state.dispatch(verb, rest)

  of "sync":
    sync.dispatch(verb, rest)

  of "window":
    # `window -- <verb> ...` preserves prior window geometry.
    if verb == "--":
      if cmd.len < 3:
        quit("window -- requires a verb")

      verb = cmd[2]

      rest = @["--"]
      rest.add(cmd[3 .. ^1])

    window.dispatch(verb, rest)

  else:
    quit("unknown domain: " & domain)

proc usage() =
  echo "usage:"
  echo "  zephyr display height"
  echo "  zephyr display width"
  echo "  zephyr display width_test <args>"
  echo "  zephyr group add <args>"
  echo "  zephyr group close <args>"
  echo "  zephyr group count"
  echo "  zephyr group current"
  echo "  zephyr group desktop <args>"
  echo "  zephyr group focus <args>"
  echo "  zephyr group id <args>"
  echo "  zephyr group last"
  echo "  zephyr group name <args>"
  echo "  zephyr group reconcile <args>"
  echo "  zephyr group remove [<args>]"
  echo "  zephyr group restore"
  echo "  zephyr group toggle <args>"
  echo "  zephyr layout explode"
  echo "  zephyr layout fold <args>"
  echo "  zephyr layout level <args>"
  echo "  zephyr layout restore <args>"
  echo "  zephyr layout spread <args>"
  echo "  zephyr layout tile <args>"
  echo "  zephyr layout unexplode"
  echo "  zephyr layout unfold <args>"
  echo "  zephyr screen indent"
  echo "  zephyr screen panel"
  echo "  zephyr state snapshot"
  echo "  zephyr state restore"
  echo "  zephyr sync group"
  echo "  zephyr sync window"
  echo "  zephyr window await <args>"
  echo "  zephyr window classname"
  echo "  zephyr window count <args>"
  echo "  zephyr window extend <args>"
  echo "  zephyr window geometry <args>"
  echo "  zephyr window group <args>"
  echo "  zephyr window wm-group <winid>"
  echo "  zephyr window wm-groups"
  echo "  zephyr window snapshot"
  echo "  zephyr window hide"
  echo "  zephyr window ids [<args>]"
  echo "  zephyr window restore [<args>]"
  echo "  zephyr window rotate"
  echo "  zephyr window shift <args>"
  echo "  zephyr window size <args>"
  echo "  zephyr window snap <args>"
  echo "  zephyr window stack [<winid>]"
  echo "  zephyr window spread <args>"
  echo "  zephyr window swap <args>"
  echo "  zephyr window tile <args>"
  echo "  zephyr window toggle <args>"
  quit(1)

#
# Main
#

let args = commandLineParams()

if args.len == 0:
  usage()

for cmd in splitCommands(args):
  dispatchCommand(cmd)
