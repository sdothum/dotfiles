import std/os
import std/strutils
import std/tables

import cliargs
import compat
import constants
import window_query as window
import daemon_client

# Group IDs are raw WM IDs.  Slot 0 is reserved VOID; names are presentation.
const GroupNames* = [
  "VOID",
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

proc count*(args: seq[string]): int =
  requireNoArgs("group count", args)
  try:
    result = parseInt(shvArgs("sirocco", "group", @["count"], 1, 1).strip())
  except ValueError:
    quit("group count: invalid WM group count")

proc count*(): int =
  count(@[])

proc tagcount*(args: seq[string]): int =
  requireNoArgs("group tagcount", args)

  GroupNames.len - 1

proc current*(args: seq[string]): string =
  requireNoArgs("group current", args)
  let reply = queryDaemon(RequestQueryCurrentGroup)
  if not reply.ok:
    quit("group current: " & reply.error)
  reply.body

proc current*(): string =
  shvArgs("sirocco", "group", @["current"], 1, 1)

proc currentLive*(): string =
  shvArgs("sirocco", "group", @["current"], 1, 1)

proc id*(args: seq[string]): int =
  requireArgs("group id", args, 1)

  proc fail(error: string) =
    quit("group id: " & error)

  let a = parseArguments(
    "group id",
    args,
    [
      ArgGroupName
    ]
  )

  if a.groupName.len == 0:
    fail("missing group name")

  for i, name in GroupNames:
    if name == a.groupName:
      return i

  fail("unknown group " & a.groupName)

proc name*(args: seq[string]): string =
  requireArgs("group name", args, 0, 1)

  if args.len == 0:
    return name(@[currentLive()])

  let a = parseArguments(
    "group name",
    args,
    [
      ArgGroup
    ]
  )

  if a.group < 0 or a.group >= count():
    quit("group name: invalid group id " & $a.group)
  if a.group < GroupNames.len:
    GroupNames[a.group]
  else:
    "GROUP " & $a.group

#
# Helpers
#

proc singleChildName*(path: string): string =
  for kind, child in walkDir(path):
    if kind == pcDir:
      return lastPathPart(child)

proc groupPath*(group: string, groupSuffix: string = ""): string =
  singleChildName((getEnv("GROUP") & groupSuffix) / group)

proc setCurrentGroup(group: string, currentGroup: string) =
  discard group
  discard currentGroup

proc reconcileCurrentGroup(group: string, currentGroup: string) =
  if currentGroup == group:
    return

  discard group

proc validRememberedWinid(group: int): string =
  let remembered = singleChildName((getEnv("GROUP") & ":focus") / $group)
  if remembered == "":
    return

  var wmGroup: uint32
  if not window.tryWmGroup(remembered, wmGroup):
    return
  if wmGroup == uint32(group):
    result = remembered

#
# Actions
#

proc add*(args: seq[string]) =
  requireArgs("group add", args, 1, 2)

  var a = parseArguments(
    "group add",
    args,
    [
      ArgGroup,
      ArgWinid
    ]
  )

  if a.group == 0 or a.group >= count():
    quit("group add: invalid group id " & $a.group)

  if a.winid == "":
    a.winid = window.focusedWinid()

  if a.winid == "":
    return

  let root = getEnv("GROUP")

  createDir(root / $a.group / a.winid)
  removeDir(root & ":focus" / $a.group)
  createDir(root & ":focus" / $a.group / a.winid)

proc remove*(args: seq[string]) =
  requireArgs("group remove", args, 0, 1)

  var a = parseArguments(
    "group remove",
    args,
    [
      ArgWinid
    ]
  )

  if a.winid == "":
    a.winid = window.focusedWinid()

  if a.winid  == "":
    return

  let root = getEnv("GROUP")

  for group in 0 ..< count():
    removeDir(root / $group / a.winid)
    removeDir(root & ":focus" / $group / a.winid)

proc remove*(winid: string) =
  remove(@[winid])

proc close*(args: seq[string]) =
  requireArgs("group close", args, 1)

  var a = parseArguments(
    "group close",
    args,
    [
      ArgGroup,
    ]
  )

  if a.group == 0 or a.group >= count():
    quit("group close: invalid group id " & $a.group)

  let root = getEnv("GROUP")
  var
    members: seq[string]
    cleanupPaths = initTable[string, seq[string]]()

  for kind, path in walkDir(root / $a.group):
    if kind == pcDir:
      let winid = lastPathPart(path)

      members.add(winid)
      cleanupPaths[winid] = @[path]

  for group in 0 ..< count():
    if group != a.group:
      for kind, path in walkDir(root / $group):
        if kind == pcDir:
          let winid = lastPathPart(path)
          if cleanupPaths.hasKey(winid):
            cleanupPaths[winid].add(path)

    for kind, path in walkDir(root & ":focus" / $group):
      if kind == pcDir:
        let winid = lastPathPart(path)
        if cleanupPaths.hasKey(winid):
          cleanupPaths[winid].add(path)

  proc removeKnownGroupState(winid: string) =
    for path in cleanupPaths[winid]:
      removeDir(path)

  for winid in members:
    runvArgs(
      "sirocco",
      "window",
      @["close", winid],
      2,
      2
    )

    removeKnownGroupState(winid)

  runvArgs(
    "sirocco",
    "group",
    @["clear", $a.group],
    2,
    2
  )

  removeDir(root / $a.group)
  removeDir(root & ":focus" / $a.group)
  removeDir(root & ":deactivated" / $a.group)

proc desktop*(args: seq[string]) =
  requireArgs("group desktop", args, 1)

  let a = parseArguments(
    "group desktop",
    args,
    [
      ArgGroup
    ]
  )

  if a.group == 0 or a.group >= count():
    quit("group desktop: invalid group id " & $a.group)

  let root = getEnv("GROUP")
  for g in 1 ..< count():
    if g != a.group:
      runvArgs(
        "sirocco",
        "group",
        @["deactivate", $g],
        2,
        2
      )

  removeDir(root & ":deactivated")

  runvArgs(
    "sirocco",
    "group",
    @["activate", $a.group],
    2,
    2
  )

  let winid = singleChildName(root & ":focus" / $a.group)

  if winid != "":
    runvArgs(
      "sirocco",
      "window",
      @["focus", winid],
      2,
      2
    )

proc focus*(args: seq[string]) =
  requireArgs("group focus", args, 1)

  let a = parseArguments(
    "group focus",
    args,
    [
      ArgGroup
    ]
  )

  if a.group == 0:
    quit("group focus: group 0 is reserved VOID")
  if a.group >= count():
    quit("group focus: invalid group id " & $a.group)

  let currentGroup = currentLive()

  if currentGroup == $a.group:
    add(args)
    return

  let root = getEnv("GROUP")

  setCurrentGroup($a.group, currentGroup)

  runvArgs(
    "sirocco",
    "group",
    @["activate", $a.group],
    2,
    2
  )

  removeDir(
    (root & ":deactivated") / $a.group
  )

  let winid = validRememberedWinid(a.group)
  if winid != "":
    runvArgs(
      "sirocco",
      "window",
      @["focus", winid],
      2,
      2
    )

proc focus*(groupname: string) =
  let group = id(@[groupname])
  focus(@[$group])

proc focus*(group: int) =
  focus(@[$group])

proc reconcile*(args: seq[string]) =
  requireArgs("group reconcile", args, 1)

  let a = parseArguments(
    "group reconcile",
    args,
    [
      ArgGroup
    ]
  )

  if a.group == 0 or a.group >= count():
    quit("group reconcile: invalid group id " & $a.group)

  let currentGroup = currentLive()
  if currentGroup == $a.group:
    return

  reconcileCurrentGroup($a.group, currentGroup)

proc last*(args: seq[string]) =
  requireNoArgs("group last", args)

  let group = singleChildName(getEnv("GROUP") / "last")

  if group != "":
    focus(@[group])

proc restore*(args: seq[string]) =
  requireNoArgs("group restore", args)

  let winid = window.focusedWinid()
  let root = getEnv("GROUP")

  for g in 1 ..< count():
    runvArgs(
      "sirocco",
      "group",
      @["activate", $g],
      2,
      2
    )

  removeDir(root & ":deactivated")

  if winid != "":
    runvArgs(
      "sirocco",
      "window",
      @["focus", winid],
      2,
      2
    )

proc toggle*(args: seq[string]) =
  requireArgs("group toggle", args, 1)

  let a = parseArguments(
    "group toggle",
    args,
    [
      ArgGroup
    ]
  )

  if a.group == 0 or a.group >= count():
    quit("group toggle: invalid group id " & $a.group)

  let root = getEnv("GROUP")

  for kind, path in walkDir(root & ":deactivated"):
    if kind == pcDir:
      if $a.group == lastPathPart(path):

        for kind, path in walkDir(root / $a.group):
          if kind == pcDir:
            removeDir(getEnv("HIDDEN") / lastPathPart(path))

        focus(a.group)
        return

  let winid = singleChildName(root / $a.group)

  if winid == "":
    return

  runvArgs(
    "sirocco",
    "group",
    @["deactivate", $a.group],
    2,
    2
  )

  createDir(root & ":deactivated" / $a.group)

#
# Native Nim convenience overloads
#

proc id*(groupname: string): string =
  $id(@[groupname])

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
    echo $count(rest)
  of "current":
    echo current(rest)
  of "desktop":
    desktop(rest)
  of "focus":
    focus(rest)
  of "reconcile":
    reconcile(rest)
  of "id":
    echo id(rest)
  of "last":
    last(rest)
  of "name":
    echo name(rest)
  of "remove":
    remove(rest)
  of "restore":
    restore(rest)
  of "tagcount":
    echo $tagcount(rest)
  of "toggle":
    toggle(rest)
  else:
    quit("unknown group action")
