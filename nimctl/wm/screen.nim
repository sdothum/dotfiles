import compat

#
# Queries
#

proc gap*(args: seq[string]): string =
  shvArgs("screen", "gap", args, 0, 0)

proc indent*(args: seq[string]): string =
  shvArgs("screen", "indent", args, 0, 0)

proc margin*(args: seq[string]): string =
  shvArgs("screen", "margin", args, 0, 0)

proc panel*(args: seq[string]): string =
  shvArgs("screen", "panel", args, 0, 0)

proc top*(args: seq[string]): string =
  shvArgs("screen", "top", args, 0, 0)

#
# Native Nim convenience overloads
#

proc gap*(): string =
  gap(@[])

proc indent*(): string =
  indent(@[])

proc margin*(): string =
  margin(@[])

proc panel*(): string =
  panel(@[])

proc top*(): string =
  top(@[])

#
# Dispatch
#

proc dispatch*(verb: string, rest: seq[string]) =
  case verb
  of "gap":
    echo gap(rest)
  of "indent":
    echo indent(rest)
  of "margin":
    echo margin(rest)
  of "panel":
    echo panel(rest)
  of "top":
    echo top(rest)
  else:
    quit("unknown screen action")
