import std/os

import wm/display
import wm/group
import wm/layout
import wm/rule
import wm/screen
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

  # `window -- <verb> ...` preserves prior window geometry.
  if domain == "window" and verb == "--":
    if cmd.len < 3:
      quit("window -- requires a verb")

    verb = cmd[2]

    rest = @["--"]
    if cmd.len > 3:
      rest.add(cmd[3 .. ^1])

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

  of "sync":
    sync.dispatch(verb, rest)

  of "window":
    window.dispatch(verb, rest)

  else:
    quit("unknown domain: " & domain)

proc usage() =
  echo "usage:"
  echo "  nimctlr display height"
  echo "  nimctlr display width"
  echo "  nimctlr display width_test <args>"
  echo "  nimctlr group add <args>"
  echo "  nimctlr group close <args>"
  echo "  nimctlr group count"
  echo "  nimctlr group current"
  echo "  nimctlr group desktop <args>"
  echo "  nimctlr group focus <args>"
  echo "  nimctlr group id <args>"
  echo "  nimctlr group last"
  echo "  nimctlr group name <args>"
  echo "  nimctlr group remove [<args>]"
  echo "  nimctlr group restore"
  echo "  nimctlr group toggle <args>"
  echo "  nimctlr layout fold <args>"
  echo "  nimctlr layout level <args>"
  echo "  nimctlr layout revert <args>"
  echo "  nimctlr layout spread <args>"
  echo "  nimctlr layout tile <args>"
  echo "  nimctlr screen indent"
  echo "  nimctlr screen panel"
  echo "  nimctlr sync group"
  echo "  nimctlr sync window"
  echo "  nimctlr window classname"
  echo "  nimctlr window count <args>"
  echo "  nimctlr window extend <args>"
  echo "  nimctlr window group <args>"
  echo "  nimctlr window hide"
  echo "  nimctlr window ids [<args>]"
  echo "  nimctlr window revert [<args>]"
  echo "  nimctlr window rotate"
  echo "  nimctlr window shift <args>"
  echo "  nimctlr window size <args>"
  echo "  nimctlr window snap <args>"
  echo "  nimctlr window spread <args>"
  echo "  nimctlr window swap <args>"
  echo "  nimctlr window standard <args>"
  echo "  nimctlr window sync <args>"
  echo "  nimctlr window tile <args>"
  quit(1)

#
# Main
#

let args = commandLineParams()

if args.len == 0:
  usage()

for cmd in splitCommands(args):
  dispatchCommand(cmd)
