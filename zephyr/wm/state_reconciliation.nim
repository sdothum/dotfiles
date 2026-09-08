import std/os
import std/options
import std/strutils
import std/tables

import group as policyGroup
import window_query

proc validWinid(value: string): bool =
  if value.len != 10 or value[0] != '0' or value[1] != 'x':
    return false
  for index in 2 .. 9:
    if value[index] notin {'0'..'9', 'a'..'f', 'A'..'F'}:
      return false
  true

proc removeEntry(path: string): bool =
  if not fileExists(path) and not dirExists(path):
    return true
  try:
    if dirExists(path):
      removeDir(path)
    else:
      removeFile(path)
    result = true
  except CatchableError:
    result = false

proc removeMembership(groupRoot, focusRoot, group, winid: string): bool =
  result = removeEntry(groupRoot / group / winid)
  if not removeEntry(focusRoot / group / winid):
    result = false

proc reconcileStaleGroupEntries(
  groupRoot, focusRoot: string,
  groupCount: int,
  managed: Table[string, bool]
): bool =
  result = true
  for number in 0 ..< groupCount:
    let group = $number
    let membershipRoot = groupRoot / group
    if dirExists(membershipRoot):
      try:
        for kind, path in walkDir(membershipRoot):
          if kind != pcDir:
            continue
          let winid = lastPathPart(path)
          if not validWinid(winid) or managed.hasKey(winid):
            continue
          if not removeMembership(groupRoot, focusRoot, group, winid):
            result = false
      except CatchableError:
        result = false

    let focusGroupRoot = focusRoot / group
    if dirExists(focusGroupRoot):
      try:
        for kind, path in walkDir(focusGroupRoot):
          if kind != pcDir:
            continue
          let winid = lastPathPart(path)
          if not validWinid(winid) or managed.hasKey(winid):
            continue
          if not removeEntry(path):
            result = false
      except CatchableError:
        result = false

proc reconcileHidden(hiddenRoot: string, managed: Table[string, bool]): bool =
  if not dirExists(hiddenRoot):
    return true
  result = true
  try:
    for kind, path in walkDir(hiddenRoot):
      if kind == pcDir or kind == pcFile or kind == pcLinkToFile or kind == pcLinkToDir:
        if not managed.hasKey(lastPathPart(path)) and not removeEntry(path):
          result = false
  except CatchableError:
    result = false

proc readCurrentGroup(groupRoot: string, groupCount: int, current: var uint32): bool =
  let currentRoot = groupRoot / "current"
  if not dirExists(currentRoot):
    return false

  var found = 0
  try:
    for kind, path in walkDir(currentRoot):
      if kind != pcDir:
        return false
      let value = lastPathPart(path)
      if value.len == 0:
        return false
      for character in value:
        if character notin {'0'..'9'}:
          return false
      let parsed = parseInt(value)
      if parsed < 0 or parsed >= groupCount:
        return false
      found.inc
      current = uint32(parsed)
  except CatchableError:
    return false
  found == 1

proc focusedMembership(
  groupRoot, winid: string,
  groupCount: int,
  membership: var uint32
): bool =
  var found = 0
  for number in 0 ..< groupCount:
    let path = groupRoot / $number / winid
    if dirExists(path):
      found.inc
      membership = uint32(number)
  found == 1

proc reconcileCurrent(
  snapshot: WmSnapshot,
  groupRoot: string,
  groupCount: int,
  membershipSuccess: bool
): bool =
  if not membershipSuccess or not isSome(snapshot.focused) or
      snapshot.currentGroup == NullGroup or
      snapshot.currentGroup >= uint32(groupCount):
    return true

  let winid = snapshot.focused.get()
  var membership: uint32
  if not focusedMembership(groupRoot, winid, groupCount, membership):
    return true
  if membership != snapshot.currentGroup:
    return true

  var current: uint32
  if not readCurrentGroup(groupRoot, groupCount, current):
    return true
  if current == snapshot.currentGroup:
    return true

  let currentRoot = groupRoot / "current"
  let suffix = $getCurrentProcessId()
  let temporary = groupRoot / (".current." & suffix)
  let backup = groupRoot / (".current.old." & suffix)
  try:
    createDir(temporary / $snapshot.currentGroup)
    moveDir(currentRoot, backup)
    try:
      moveDir(temporary, currentRoot)
    except CatchableError:
      try:
        moveDir(backup, currentRoot)
      except CatchableError:
        discard
      raise
    discard removeEntry(backup)
    result = true
  except CatchableError:
    discard removeEntry(temporary)
    result = false

proc reconcileSnapshot*(snapshot: WmSnapshot): bool =
  let groupRoot = getEnv("GROUP")
  let hiddenRoot = getEnv("HIDDEN")
  if groupRoot.len == 0 or hiddenRoot.len == 0:
    return false

  let focusRoot = groupRoot & ":focus"
  let groupCount = policyGroup.count()
  var managed = initTable[string, bool]()

  for client in snapshot.clients:
    managed[client.winid] = true
    if client.group != NullGroup and client.group >= uint32(groupCount):
      return false

  var membershipSuccess = reconcileStaleGroupEntries(
    groupRoot, focusRoot, groupCount, managed
  )

  for client in snapshot.clients:
    if not client.mapped:
      continue

    let group = client.group
    if group == NullGroup:
      for number in 0 ..< groupCount:
        if not removeMembership(groupRoot, focusRoot, $number, client.winid):
          membershipSuccess = false
      continue

    let destination = groupRoot / $group / client.winid
    try:
      createDir(destination)
    except CatchableError:
      membershipSuccess = false
      continue

    for number in 0 ..< groupCount:
      if uint32(number) == group:
        continue
      if not removeMembership(groupRoot, focusRoot, $number, client.winid):
        membershipSuccess = false

  var success = membershipSuccess
  if not reconcileHidden(hiddenRoot, managed):
    success = false
  if not reconcileCurrent(snapshot, groupRoot, groupCount, membershipSuccess):
    success = false
  success
