import cliargs
import compat

#
# Actions
#

proc fold*(args: seq[string]) =
  runvArgs("layout", "fold", args, 1, 5)

proc level*(args: seq[string]) =
  runvArgs("layout", "level", args, 0, 0)

proc restore*() =
  runvArgs("layout", "restore", @[], 0, 0)

proc spread*(args: seq[string]) =
  runvArgs("layout", "spread", args, 1, 4)

proc tile*(args: seq[string]) =
  runvArgs("layout", "tile", args, 1, 4)

#
# Native Nim convenience overloads
#

proc fold*(columns: string) =
  fold(@[columns])

proc fold*(columns, classname: string) =
  fold(@[columns, classname])

proc fold*(spread, columns, classname: string) =
  fold(@[spread, columns, classname])

proc fold*(columns, rows, num, classname: string) =
  fold(@[columns, rows, num, classname])

proc fold*(stateless, columns, rows, num, classname: string) =
  fold(@[stateless, columns, rows, num, classname])

proc spread*(columns: string) =
  spread(@[columns])

proc spread*(columns, classname: string) =
  spread(@[columns, classname])

proc spread*(columns, position, classname: string) =
  spread(@[columns, position, classname])

proc spread*(columns, rows, num, classname: string) =
  spread(@[columns, rows, num, classname])

proc tile*(columns: string) =
  tile(@[columns])

proc tile*(columns, classname: string) =
  tile(@[columns, classname])

proc tile*(columns, rows, num, classname: string) =
  tile(@[columns, rows, num, classname])

#
# Dispatch
#

proc dispatch*(verb: string, rest: seq[string]) =
  case verb
  of "fold", "spread", "tile":
    validateOptions(
      rest,
      valueOptions = ["--", "--rows"],
      allowedOptions = ["--", "--rows"]
    )

    case verb
    of "fold":
      fold(rest)
    of "spread":
      spread(rest)
    of "tile":
      tile(rest)

  of "level":
    level(rest)
  of "restore":
    requireNoArgs(verb, rest)
    restore()
  else:
    quit("unknown layout action")
