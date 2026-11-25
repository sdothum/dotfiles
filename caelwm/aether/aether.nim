import std/os

import wm/display
import wm/daemon_client as daemonClient
import wm/group
import wm/screen
import wm/state
import wm/window

import policy/layouts
import policy/rules
import zephyr_errors

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
  of "daemon":
    if verb != "await":
      raiseZephyrError("unknown daemon command: " & verb)
    if rest.len > 0:
      raiseZephyrError("daemon await takes no arguments")
    daemonClient.awaitReady()

  of "display":
    display.dispatch(verb, rest)

  of "group":
    group.dispatch(verb, rest)

  of "layout", "layouts":
    layouts.dispatch(verb, rest)

  of "rule":
    rules.dispatch(verb, rest)

  of "screen":
    screen.dispatch(verb, rest)

  of "state":
    state.dispatch(verb, rest)

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
  echo "  aether display height"
  echo "  aether daemon await"
  echo "  aether display width"
  echo "  aether display width_test <args>"
  echo "  aether group add <args>"
  echo "  aether group close <args>"
  echo "  aether group count"
  echo "  aether group current"
  echo "  aether group desktop <args>"
  echo "  aether group focus <args>"
  echo "  aether group id <args>"
  echo "  aether group last"
  echo "  aether group name <args>"
  echo "  aether group next"
  echo "  aether group previous"
  echo "  aether group reconcile <args>"
  echo "  aether group remove [<args>]"
  echo "  aether group restore"
  echo "  aether group toggle <args>"
  echo "  aether layout bias [left|right]"
  echo "  aether layouts explode"
  echo "  aether layouts fold <args>"
  echo "  aether layouts unfold [<class> | --group <group>]"
  echo "  aether layouts level <args>"
  echo "  aether layouts restore <args>"
  echo "  aether layouts spread <args>"
  echo "  aether layouts tile <args>"
  echo "  aether layouts unexplode"
  echo "  aether layouts grid <args>"
  echo "  aether screen indent"
  echo "  aether screen panel"
  echo "  aether state snapshot"
  echo "  aether state restore"
  echo "  aether sync group"
  echo "  aether window await <args>"
  echo "  aether window classname"
  echo "  aether window count <args>"
  echo "  aether window extend <args>"
  echo "  aether window geometry <args>"
  echo "  aether window group <args>"
  echo "  aether window wm-group <winid>"
  echo "  aether window wm-groups"
  echo "  aether window snapshot"
  echo "  aether window hide"
  echo "  aether window ids [<args>]"
  echo "  aether window restore [<args>]"
  echo "  aether window rotate"
  echo "  aether window move <args>"
  echo "  aether window shift <args>"
  echo "  aether window size <args>"
  echo "  aether window snap <args>"
  echo "  aether window stack [<winid>]"
  echo "  aether window spread <args>"
  echo "  aether window swap <args>"
  echo "  aether window tile <args>"
  echo "  aether window toggle <args>"
  quit(1)

#
# Main
#

let args = commandLineParams()

if args.len == 0:
  usage()

try:
  for cmd in splitCommands(args):
    dispatchCommand(cmd)
except ZephyrError as error:
  stderr.writeLine(error.msg)
  quit(1)
