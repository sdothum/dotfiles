import compat

#
# Queries
#

proc height*(args: seq[string]): string =
  shvArgs("display", "height", args, 0, 0)

proc width*(args: seq[string]): string =
  shvArgs("display", "width", args, 0, 0)

#
# Predicates
#

proc widthTest*(args: seq[string]): int =
  statusvArgs("display", "width_test", args, 2, 2)

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
