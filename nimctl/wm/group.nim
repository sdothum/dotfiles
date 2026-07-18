import std/strutils

import compat
import constants

const
  GroupNames* = [
    GroupDesk,
    GroupComm,
    GroupCode,
    GroupWiki,
    GroupUtil,
    GroupPlay,
    GroupPeer
  ]

#
# Queries
#

proc count*(args: seq[string]): string =
  shvArgs("group", "count", args, 0, 0)

proc current*(args: seq[string]): string =
  shvArgs("group", "current", args, 0, 0)

proc id*(groupName: string): int =
  for i, name in GroupNames:
    if name == groupName:
      return i + 1

  quit("unknown group: " & groupName)

proc name*(groupId: int): string =
  if groupId < 1 or groupId > GroupNames.len:
    quit("invalid group id: " & $groupId)

  GroupNames[groupId - 1]

#
# Actions
#


proc add*(args: seq[string]) =
  runvArgs("group", "add", args, 1, 2)

proc close*(args: seq[string]) =
  runvArgs("group", "close", args, 1, 1)

proc desktop*(args: seq[string]) =
  runvArgs("group", "desktop", args, 1, 1)

proc focus*(args: seq[string]) =
  runvArgs("group", "focus", args, 1, 1)

proc last*(args: seq[string]) =
  runvArgs("group", "last", args, 0, 0)

proc remove*(args: seq[string]) =
  runvArgs("group", "remove", args, 0, 1)

proc restore*(args: seq[string]) =
  runvArgs("group", "restore", args, 0, 0)

proc toggle*(args: seq[string]) =
  runvArgs("group", "toggle", args, 1, 1)

#
# Native Nim convenience overloads
#

proc count*(): string =
  count(@[])

proc current*(): string =
  current(@[])

proc focus*(groupname: string) =
  let groupId = id(groupname)
  focus(@[$groupId])

proc nameCurrent*(): string =
  name(parseInt(current()))

proc last*() =
  last(@[])

#
# Dispatch
#

proc dispatch*(verb: string, rest: seq[string]) =
  case verb
  of "add":
    add(rest)
  of "close":
    close(rest)
  of "count":
    echo count(rest)
  of "current":
    echo current(rest)
  of "desktop":
    desktop(rest)
  of "focus":
    focus(rest)

  of "id":
    if rest.len != 1:
      quit("group id expects 1 argument")

    echo id(rest[0])

  of "last":
    last(rest)

  of "name":
    if rest.len != 1:
      quit("group name expects 1 argument")

    try:
      echo name(parseInt(rest[0]))
    except ValueError:
      quit("group name expects a numeric group ID")

  of "remove":
    remove(rest)
  of "restore":
    restore(rest)
  of "toggle":
    toggle(rest)
  else:
    quit("unknown group action")

