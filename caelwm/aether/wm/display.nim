import compat
import std/strutils
import native_ipc as ipc


# Reads root width and height through native WM transport.

proc rootDimensions(): tuple[width, height: int] =
  ipc.rootDimensions()


# Returns display dimensions from the X root geometry query.

proc dimensions*(): tuple[width, height: int] =
  rootDimensions()

#
# Queries
#


# Returns display height as decimal text, rejecting arguments in the CLI overload.

proc height*(args: seq[string]): string =
  requireNoArgs("display height", args)
  $dimensions().height


# Returns display width as decimal text, rejecting arguments in the CLI overload.

proc width*(args: seq[string]): string =
  requireNoArgs("display width", args)
  $dimensions().width


# Validates the no-argument query and formats display width and height as one line.

proc dimensions(args: seq[string]): string =
  requireNoArgs("display dimensions", args)
  let size = dimensions()
  $size.width & " " & $size.height

#
# Predicates
#


# Compares display width with an integer and returns shell status 0 for a matching predicate.

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


# Returns display height as decimal text, rejecting arguments in the CLI overload.

proc height*(): string =
  height(@[])


# Returns display width as decimal text, rejecting arguments in the CLI overload.

proc width*(): string =
  width(@[])

#
# Dispatch
#


# Prints display queries or exits with the width predicate's status, rejecting unknown actions.

proc dispatch*(verb: string, rest: seq[string]) =
  case verb
  of "dimensions":
    echo dimensions(rest)
  of "height":
    echo height(rest)
  of "width":
    echo width(rest)
  of "width_test":
    quit(widthTest(rest))
  else:
    quit("unknown display action")
