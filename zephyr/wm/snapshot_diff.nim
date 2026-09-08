import std/algorithm
import std/options

import window_query

type
  SnapshotChangeKind* = enum
    FocusChanged
    CurrentChanged
    ClientRemoved
    ClientAdded
    GroupChanged
    MappedChanged
    NullGroupChanged

  SnapshotChange* = object
    kind*: SnapshotChangeKind
    winid*: string
    oldGroup*: uint32
    newGroup*: uint32
    oldMapped*: bool
    newMapped*: bool
    oldFocused*: Option[string]
    newFocused*: Option[string]
    oldCurrent*: uint32
    newCurrent*: uint32
    oldNullGroupCount*: int
    newNullGroupCount*: int

proc client(snapshot: WmSnapshot, winid: string): Option[WmClientState] =
  for item in snapshot.clients:
    if item.winid == winid:
      return some(item)
  none(WmClientState)

proc clientIds(snapshot: WmSnapshot): seq[string] =
  for item in snapshot.clients:
    result.add(item.winid)
  result.sort()

proc nullGroupCount(snapshot: WmSnapshot): int =
  for item in snapshot.clients:
    if item.group == NullGroup:
      result.inc

proc diffSnapshots*(previous, current: WmSnapshot): seq[SnapshotChange] =
  if previous.focused != current.focused:
    result.add(SnapshotChange(
      kind: FocusChanged,
      oldFocused: previous.focused,
      newFocused: current.focused
    ))

  if previous.currentGroup != current.currentGroup:
    result.add(SnapshotChange(
      kind: CurrentChanged,
      oldCurrent: previous.currentGroup,
      newCurrent: current.currentGroup
    ))

  let previousIds = previous.clientIds()
  let currentIds = current.clientIds()

  for winid in previousIds:
    let currentItem = current.client(winid)
    if currentItem.isNone or currentItem.get().token != previous.client(winid).get().token:
      let item = previous.client(winid).get()
      result.add(SnapshotChange(
        kind: ClientRemoved,
        winid: winid,
        oldGroup: item.group,
        oldMapped: item.mapped
      ))

  for winid in currentIds:
    let currentItem = current.client(winid)
    if currentItem.isNone:
      continue
    let previousItem = previous.client(winid)
    if previousItem.isNone or previousItem.get().token != currentItem.get().token:
      result.add(SnapshotChange(
        kind: ClientAdded,
        winid: winid,
        newGroup: currentItem.get().group,
        newMapped: currentItem.get().mapped
      ))

  for winid in currentIds:
    let currentItem = current.client(winid)
    if currentItem.isNone:
      continue
    let previousItem = previous.client(winid)
    if previousItem.isNone:
      continue

    let oldItem = previousItem.get()
    let newItem = currentItem.get()
    if oldItem.token != newItem.token:
      continue
    if oldItem.group != newItem.group:
      result.add(SnapshotChange(
        kind: GroupChanged,
        winid: winid,
        oldGroup: oldItem.group,
        newGroup: newItem.group
      ))
    if oldItem.mapped != newItem.mapped:
      result.add(SnapshotChange(
        kind: MappedChanged,
        winid: winid,
        oldMapped: oldItem.mapped,
        newMapped: newItem.mapped
      ))

  let oldNullGroupCount = previous.nullGroupCount()
  let newNullGroupCount = current.nullGroupCount()
  if oldNullGroupCount != newNullGroupCount:
    result.add(SnapshotChange(
      kind: NullGroupChanged,
      oldNullGroupCount: oldNullGroupCount,
      newNullGroupCount: newNullGroupCount
    ))

proc focusedText(value: Option[string]): string =
  if value.isSome:
    value.get()
  else:
    "NONE"

proc mappedText(value: bool): string =
  if value: "1" else: "0"

proc report*(change: SnapshotChange): string =
  case change.kind
  of FocusChanged:
    "FOCUS_CHANGED " & focusedText(change.oldFocused) & " " &
      focusedText(change.newFocused)
  of CurrentChanged:
    "CURRENT_CHANGED " & $change.oldCurrent & " " & $change.newCurrent
  of ClientRemoved:
    "CLIENT_REMOVED " & change.winid & " " & $change.oldGroup & " " &
      mappedText(change.oldMapped)
  of ClientAdded:
    "CLIENT_ADDED " & change.winid & " " & $change.newGroup & " " &
      mappedText(change.newMapped)
  of GroupChanged:
    "GROUP_CHANGED " & change.winid & " " & $change.oldGroup & " " &
      $change.newGroup
  of MappedChanged:
    "MAPPED_CHANGED " & change.winid & " " & mappedText(change.oldMapped) &
      " " & mappedText(change.newMapped)
  of NullGroupChanged:
    "NULLGROUP_CHANGED " & $change.oldNullGroupCount & " " &
      $change.newNullGroupCount
