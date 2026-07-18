import compat

#
# Actions
#

proc fold*(args: seq[string]) =
  runvArgs("layout", "fold", args, 1, 3)

proc level*(args: seq[string]) =
  runvArgs("layout", "level", args, 0, 0)

proc revert*(args: seq[string]) =
  runvArgs("layout", "revert", args, 0, 0)

proc spread*(args: seq[string]) =
  runvArgs("layout", "spread", args, 1, 3)

proc tile*(args: seq[string]) =
  runvArgs("layout", "tile", args, 1, 3)

#
# Native Nim convenience overloads
#

proc fold*(columns: string) =
  fold(@[columns])

proc fold*(columns, classname: string) =
  fold(@[columns, classname])

proc fold*(spread, columns, classname: string) =
  fold(@[spread, columns, classname])

proc spread*(columns: string) =
  spread(@[columns])

proc spread*(columns, classname: string) =
  spread(@[columns, classname])

proc spread*(columns, position, classname: string) =
  spread(@[columns, position, classname])

proc tile*(columns: string) =
  tile(@[columns])

proc tile*(columns, classname: string) =
  tile(@[columns, classname])

#
# Dispatch
#

proc dispatch*(verb: string, rest: seq[string]) =
  case verb
  of "fold":
    fold(rest)
  of "level":
    level(rest)
  of "revert":
    revert(rest)
  of "spread":
    spread(rest)
  of "tile":
    tile(rest)
  else:
    quit("unknown layout action")
