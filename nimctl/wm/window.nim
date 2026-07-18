import std/strutils

import compat
import group as groups

#
# Queries
#

proc classname*(args: seq[string]): string =
  shvArgs("window", "classname", args, 0, 0)

proc count*(args: seq[string]): string =
  shvArgs("window", "count", args, 1, 1)

proc ids*(args: seq[string]): string =
  shvArgs("window", "ids", args, 0, 1)

#
# Actions
#

proc extend*(args: seq[string]) =
  runvArgs("window", "extend", args, 1, 2)

proc group*(args: seq[string]) =
  runvArgs("window", "group", args, 1, 2)

proc hide*(args: seq[string]) =
  runvArgs("window", "hide", args, 0, 0)

proc revert*(args: seq[string]) =
  runvArgs("window", "revert", args, 0, 1)

proc rotate*(args: seq[string]) =
  runvArgs("window", "rotate", args, 0, 0)

proc shift*(args: seq[string]) =
  runvArgs("window", "shift", args, 1, 1)

proc size*(args: seq[string]) =
  runvArgs("window", "size", args, 1, 3)

proc snap*(args: seq[string]) =
  runvArgs("window", "snap", args, 1, 3)

proc spread*(args: seq[string]) =
  runvArgs("window", "spread", args, 1, 4)

proc swap*(args: seq[string]) =
  runvArgs("window", "swap", args, 1, 1)

proc standard*(args: seq[string]) =
  runvArgs("window", "standard", args, 2, 3)

proc sync*(args: seq[string]) =
  runvArgs("window", "sync", args, 1, 2)

proc tile*(args: seq[string]) =
  runvArgs("window", "tile", args, 1, 4)

#
# Native Nim convenience overloads
#

proc classname*(): string =
  classname(@[])

proc count*(classname: string): int =
  parseInt(count(@[classname]))

proc group*(groupname: string) =
  let groupId = groups.id(groupname)
  group(@[$groupId])

proc size*(size: string) =
  size(@[size])

proc size*(size, orientation: string) =
  size(@[size, orientation])

proc snap*(position: string) =
  snap(@[position])

proc snap*(position1, position2: string) =
  snap(@[position1, position2])

proc spread*(selector: string) =
  spread(@[selector])

proc sync*(selector: string) =
  sync(@[selector])

proc sync*(selector, property: string) =
  sync(@[selector, property])

proc tile*(side: string) =
  tile(@[side])

proc tile*(column, position: string) =
  tile(@[column, position])

proc tile*(matrix, column, position: string) =
  tile(@[matrix, column, position])

#
# Dispatch
#

proc dispatch*(verb: string, rest: seq[string]) =
  case verb
  of "classname":
    echo classname(rest)
  of "count":
    echo count(rest)
  of "extend":
    extend(rest)
  of "group":
    group(rest)
  of "hide":
    hide(rest)
  of "ids":
    echo ids(rest)
  of "revert":
    revert(rest)
  of "rotate":
    rotate(rest)
  of "shift":
    shift(rest)
  of "size":
    size(rest)
  of "snap":
    snap(rest)
  of "spread":
    spread(rest)
  of "swap":
    swap(rest)
  of "standard":
    standard(rest)
  of "sync":
    sync(rest)
  of "tile":
    tile(rest)
  else:
    quit("unknown window action: " & verb)
