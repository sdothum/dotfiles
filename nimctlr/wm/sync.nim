import compat

#
# Actions
#

proc group*(args: seq[string]) =
  runvArgs("sync", "group", args, 0, 0)

proc window*(args: seq[string]) =
  runvArgs("sync", "window", args, 0, 0)

#
# Native Nim convenience overloads
#

proc group*() =
  group(@[])

proc window*() =
  window(@[])

#
# Dispatch
#

proc dispatch*(verb: string, rest: seq[string]) =
  case verb
  of "group":
    group(rest)
  of "window":
    window(rest)
  else:
    quit("unknown sync action")

