import compat
import std/strutils
import x11_ipc

proc rootDimensions(): tuple[width, height: int] =
  var ipc: X11Ipc
  if not ipc.open():
    quit("display: unable to connect to X")
  defer: ipc.close()
  if not ipc.rootGeometry(result.width, result.height):
    quit("display: unable to query root geometry")

proc dimensions*(): tuple[width, height: int] =
  rootDimensions()

#
# Queries
#

proc height*(args: seq[string]): string =
  requireNoArgs("display height", args)
  $dimensions().height

proc width*(args: seq[string]): string =
  requireNoArgs("display width", args)
  $dimensions().width

#
# Predicates
#

proc widthTest*(args: seq[string]): int =
  requireArgs("display width_test", args, 2, 2)
  let width = parseInt(width(@[]))
  let value = try:
    parseInt(args[1])
  except ValueError:
    quit("display width_test: expected integer width")
  let matches = case args[0]
    of "ge", "Ge": width >= value
    of "gt", "Gt": width > value
    of "ne", "Ne": width != value
    of "eq", "Eq": width == value
    of "le", "Le": width <= value
    of "lt", "Lt": width < value
    else:
      quit("display width_test: unknown operator " & args[0])
  if matches: 0 else: 1

#
# Native Nim convenience overloads
#

proc height*(): string =
  height(@[])

proc width*(): string =
  width(@[])

#
# Dispatch
#

proc dispatch*(verb: string, rest: seq[string]) =
  case verb
  of "height":
    echo height(rest)
  of "width":
    echo width(rest)
  of "width_test":
    quit(widthTest(rest))
  else:
    quit("unknown display action")
