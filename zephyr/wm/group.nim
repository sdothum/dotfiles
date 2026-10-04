import native_ipc as ipc
import std/os
import std/options
import std/strutils
import std/tables
import ../zephyr_errors

import cliargs
import compat
import constants
import window_query as window
import daemon_client
import group_id

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
    result = parseInt(ipc.groupCount().strip())
  except ValueError:
    raiseZephyrError("group count: invalid WM group count")

proc count*(): int =
  count(@[])

proc tagcount*(args: seq[string]): int =
  requireNoArgs("group tagcount", args)

  GroupNames.len - 1

proc current*(args: seq[string]): string =
  requireNoArgs("group current", args)
  let reply = queryDaemon(RequestQueryCurrentGroup)
  if not reply.ok:
    raiseZephyrError("group current: " & reply.error)
  reply.body

proc current*(): string =
  ipc.groupCurrent()

proc currentLive*(): string =
  ipc.groupCurrent()

proc currentLiveId*(): int =
  try:
    parseInt(currentLive())
  except ValueError:
    raiseZephyrError("group current: invalid WM group id")

proc id*(groupname: string): int =
  if groupname.len == 0:
    raiseZephyrError("group id: missing group name")

  for i, name in GroupNames:
    if name == groupname:
      return i

  raiseZephyrError("group id: unknown group " & groupname)

proc id*(args: seq[string]): int =
  requireArgs("group id", args, 1)

  let a = parseArguments(
    "group id",
    args,
    [
      ArgGroupName
    ]
  )

  id(a.groupName)

proc publicId*(groupname: string, context = "group"): PublicGroupId =
  let value = id(groupname)
  if value == 0:
    raiseZephyrError(context & ": group 0 is reserved VOID")
  publicGroupId(value, count(), context)

proc name*(group: int): string =
  if group < 0 or group >= count():
    raiseZephyrError("group name: invalid group id " & $group)
  if group < GroupNames.len:
    GroupNames[group]
  else:
    "GROUP " & $group

proc name*(args: seq[string]): string =
  requireArgs("group name", args, 0, 1)

  if args.len == 0:
    return name(currentLiveId())

  let a = parseArguments(
    "group name",
    args,
    [
      ArgGroup
    ]
  )

  name(a.group.get)

proc name*(): string =
  name(@[])

#
# Helpers
#

proc singleChildName*(path: string): Option[string] =
  for kind, child in walkDir(path):
    if kind == pcDir:
      let name = lastPathPart(child)
      if name.len > 0:
        return some(name)
      return none(string)
  none(string)

proc groupPath*(group: string, groupSuffix: string = ""): string =
  singleChildName((getEnv("GROUP") & groupSuffix) / group).get("")

proc validWinid(value: string): bool =
  if value.len != 10 or value[0 .. 1] != "0x":
    return false
  for index in 2 .. 9:
    if value[index] notin {'0'..'9', 'a'..'f', 'A'..'F'}:
      return false
  true

proc rememberedToken(entry: string): tuple[
    valid: bool,
    token: Option[window.ClientToken]
  ] =
  result.valid = true
  result.token = none(window.ClientToken)
  var foundIdentity = false
  try:
    for kind, path in walkDir(entry):
      let name = lastPathPart(path)
      if not name.startsWith("ID"):
        continue
      if foundIdentity or kind != pcDir or not name.startsWith("ID=") or
          name.len <= 3:
        return (false, none(window.ClientToken))
      try:
        result.token = some(window.parseClientToken(name[3 .. ^1]))
      except ValueError:
        return (false, none(window.ClientToken))
      foundIdentity = true
  except CatchableError:
    return (false, none(window.ClientToken))

proc rememberClient(group: PublicGroupId, client: window.WmClientState) =
  let groupRoot = (getEnv("GROUP") & ":focus") / $group.intValue
  removeDir(groupRoot)
  let entry = groupRoot / client.winid
  createDir(entry)
  if client.token.isSome:
    createDir(entry / ("ID=" & $client.token.get))

proc setCurrentGroup(group, currentGroup: int) =
  discard group
  discard currentGroup

proc reconcileCurrentGroup(group, currentGroup: int) =
  if currentGroup == group:
    return

  discard group

proc validRememberedWinid(group: PublicGroupId): Option[string] =
  let groupRoot = (getEnv("GROUP") & ":focus") / $group.intValue
  let remembered = singleChildName(groupRoot)
  if remembered.isNone:
    return none(string)

  let winid = remembered.get
  if not validWinid(winid):
    return none(string)

  let saved = rememberedToken(groupRoot / winid)
  if not saved.valid:
    removeDir(groupRoot)
    return none(string)

  var snapshot: window.WmSnapshot
  if not window.tryWmSnapshot(snapshot):
    return none(string)
  for client in snapshot.clients:
    if client.winid != winid or client.group != uint32(group.intValue):
      continue
    if saved.token.isSome:
      if client.token.isSome and client.token.get == saved.token.get:
        return some(winid)
      removeDir(groupRoot)
      return none(string)

    # Legacy XID-only entries remain usable. Upgrade them when the live
    # snapshot provides an identity, without making lookup depend on the write.
    if client.token.isSome:
      try:
        createDir(groupRoot / winid / ("ID=" & $client.token.get))
      except CatchableError:
        discard
    return some(winid)
  none(string)

#
# Actions
#

proc add*(group: PublicGroupId, winid = "")
proc focus*(group: PublicGroupId)

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

  let group = a.group.get
  if group <= 0 or group >= count():
    raiseZephyrError("group add: invalid group id " & $group)
  add(publicGroupId(group, count(), "group add"), a.winid)

proc add*(group: PublicGroupId, winid: string) =
  var snapshot: window.WmSnapshot
  let haveSnapshot = window.tryWmSnapshot(snapshot)
  var target = winid
  if target == "":
    if not haveSnapshot or snapshot.focused.isNone:
      return
    target = snapshot.focused.get
  let root = getEnv("GROUP")

  createDir(root / $group.intValue / target)
  let focusRoot = (root & ":focus") / $group.intValue
  if haveSnapshot:
    for client in snapshot.clients:
      if client.winid == target.toLowerAscii():
        rememberClient(group, client)
        return
  removeDir(focusRoot)

proc add*(group: int, winid = "") =
  if group <= 0 or group >= count():
    raiseZephyrError("group add: invalid group id " & $group)
  add(publicGroupId(group, count(), "group add"), winid)

proc remove*(args: seq[string]) =
  requireArgs("group remove", args, 0, 2)

  var a = parseArguments(
    "group remove",
    args,
    [
      ArgClose,
      ArgWinid
    ]
  )

  if a.winid == "":
    a.winid = window.focusedWinid()

  if a.winid == "":
    return

  let root = getEnv("GROUP")

  for group in 0 ..< count():
    removeDir(root / $group / a.winid)
    removeDir(root & ":focus" / $group / a.winid)

  if a.close:
    ipc.closeWindow(ipc.windowId(a.winid))

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

  let parsedGroup = a.group.get
  if parsedGroup <= 0 or parsedGroup >= count():
    raiseZephyrError("group close: invalid group id " & $parsedGroup)
  let group = publicGroupId(parsedGroup, count(), "group close")
  let groupNo = group.intValue

  let root = getEnv("GROUP")
  var
    members: seq[string]
    cleanupPaths = initTable[string, seq[string]]()

  for kind, path in walkDir(root / $groupNo):
    if kind == pcDir:
      let winid = lastPathPart(path)

      members.add(winid)
      cleanupPaths[winid] = @[path]

  for group in 0 ..< count():
    if group != groupNo:
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
    ipc.closeWindow(ipc.windowId(winid))

    removeKnownGroupState(winid)

  ipc.clearGroup(groupNo)

  removeDir(root / $groupNo)
  removeDir(root & ":focus" / $groupNo)
  removeDir(root & ":deactivated" / $groupNo)

proc desktop*(args: seq[string]) =
  requireArgs("group desktop", args, 1)

  let a = parseArguments(
    "group desktop",
    args,
    [
      ArgGroup
    ]
  )

  let parsedGroup = a.group.get
  if parsedGroup <= 0 or parsedGroup >= count():
    raiseZephyrError("group desktop: invalid group id " & $parsedGroup)
  let group = publicGroupId(parsedGroup, count(), "group desktop")
  let groupNo = group.intValue

  let root = getEnv("GROUP")
  for g in 1 ..< count():
    if g != groupNo:
      ipc.deactivateGroup(g)

  removeDir(root & ":deactivated")

  ipc.activateGroup(groupNo)

  let winid = validRememberedWinid(group)

  if winid.isSome:
    ipc.focus(ipc.windowId(winid.get)).require()

proc focus*(args: seq[string]) =
  requireArgs("group focus", args, 1)

  let a = parseArguments(
    "group focus",
    args,
    [
      ArgGroup
    ]
  )

  let groupNo = a.group.get
  if groupNo == 0:
    raiseZephyrError("group focus: group 0 is reserved VOID")
  focus(publicGroupId(groupNo, count(), "group focus"))

proc focus*(group: PublicGroupId) =
  let groupNo = group.intValue

  let currentGroup = currentLiveId()

  if currentGroup == groupNo:
    add(group)
    return

  let root = getEnv("GROUP")

  setCurrentGroup(groupNo, currentGroup)

  ipc.activateGroup(groupNo)

  removeDir(
    (root & ":deactivated") / $groupNo
  )

  let winid = validRememberedWinid(group)
  if winid.isSome:
    ipc.focus(ipc.windowId(winid.get)).require()

proc focus*(group: int) =
  if group == 0:
    raiseZephyrError("group focus: group 0 is reserved VOID")
  focus(publicGroupId(group, count(), "group focus"))

proc focus*(groupname: string) =
  focus(publicId(groupname, "group focus"))

proc reconcile*(args: seq[string]) =
  requireArgs("group reconcile", args, 1)

  let a = parseArguments(
    "group reconcile",
    args,
    [
      ArgGroup
    ]
  )

  let groupNo = a.group.get
  if groupNo == 0 or groupNo >= count():
    raiseZephyrError("group reconcile: invalid group id " & $groupNo)
  let group = publicGroupId(groupNo, count(), "group reconcile")

  let currentGroup = currentLiveId()
  if currentGroup == group.intValue:
    return

  reconcileCurrentGroup(group.intValue, currentGroup)

proc last*(args: seq[string]) =
  requireNoArgs("group last", args)

  let group = singleChildName(getEnv("GROUP") / "last")

  if group.isSome:
    try:
      focus(publicGroupId(parseInt(group.get), count(), "group last"))
    except ValueError:
      raiseZephyrError("group last: invalid saved group id " & group.get)

proc restore*(args: seq[string]) =
  requireNoArgs("group restore", args)

  let winid = window.focusedWinid()
  let root = getEnv("GROUP")

  for g in 1 ..< count():
    ipc.activateGroup(g)

  removeDir(root & ":deactivated")

  if winid != "":
    ipc.focus(ipc.windowId(winid)).require()

proc toggle*(args: seq[string]) =
  requireArgs("group toggle", args, 1)

  let a = parseArguments(
    "group toggle",
    args,
    [
      ArgGroup
    ]
  )

  let parsedGroup = a.group.get
  if parsedGroup <= 0 or parsedGroup >= count():
    raiseZephyrError("group toggle: invalid group id " & $parsedGroup)
  let group = publicGroupId(parsedGroup, count(), "group toggle")
  let groupNo = group.intValue

  let root = getEnv("GROUP")

  for kind, path in walkDir(root & ":deactivated"):
    if kind == pcDir:
      if $groupNo == lastPathPart(path):

        for kind, path in walkDir(root / $groupNo):
          if kind == pcDir:
            removeDir(getEnv("HIDDEN") / lastPathPart(path))

        focus(group)
        return

  let winid = singleChildName(root / $groupNo)

  if winid.isNone:
    return

  ipc.deactivateGroup(groupNo)

  createDir(root & ":deactivated" / $groupNo)

#
# Native Nim convenience overloads
#

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
    raiseZephyrError("unknown group action")
