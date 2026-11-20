import std/os
import std/options
import std/sequtils
import std/sets
import std/strutils
import std/tables

import ./state
import ./types
import ./window
import ./window_query as query
import ../zephyr_errors

type
  PlacementClient* = object
    winid*: string
    token*: Option[query.ClientToken]

  PlacementSource* = object
    client*: PlacementClient
    geometry*: Geometry

  PlacementCell* = object
    column*: int
    row*: int

  FoldPlacement = object
    applications: seq[window.CheckedGeometryApplication]
    history: seq[state.IdentityHistoryUpdate]
    records: seq[state.IdentityExplodeStateRecord]

proc foldDestination(cell: PlacementCell, columns, rows: int,
    screen: ScreenGeometry, source: Geometry, spread: bool): Geometry =
  let tileWidth = (screen.width - (columns - 1) * screen.gap) div columns
  let tileHeight = (screen.height - (rows - 1) * screen.gap) div rows

  if spread:
    if screen.height < rows * source.height + (rows - 1) * screen.gap:
      raiseZephyrError("layouts fold: window exceeds row height")
    return Geometry(
      x: tileWidth * (cell.column - 1) + screen.margin +
        (cell.column - 1) * screen.gap + (tileWidth - source.width) div 2,
      y: tileHeight * (cell.row - 1) + screen.top +
        (cell.row - 1) * screen.gap + (tileHeight - source.height) div 2,
      width: source.width,
      height: source.height
    )

  Geometry(
    x: tileWidth * (cell.column - 1) + screen.margin +
      (cell.column - 1) * screen.gap,
    y: tileHeight * (cell.row - 1) + screen.top +
      (cell.row - 1) * screen.gap,
    width: tileWidth,
    height: tileHeight
  )

proc applyFold*(clients: seq[PlacementClient], cells: seq[PlacementCell],
    columns, rows: int, spread: bool, checkpointRoot: Option[string],
    focusedWinid: string) =
  if clients.len == 0:
    raiseZephyrError("layouts fold: no matching windows")
  if cells.len != clients.len:
    raiseZephyrError("layouts fold: invalid placement plan")

  if checkpointRoot.isSome:
    state.recoverExplodeOperation(checkpointRoot.get)

  let screenGeometry = window.screenGeometry()
  var placement: FoldPlacement

  # Capture every source geometry before any mutation occurs. This preserves
  # spread sizing and original-history comparison semantics.
  var initial: seq[Geometry] = @[]
  for client in clients:
    initial.add(query.geometry(client.winid))

  for index, client in clients:
    if client.token.isNone:
      raiseZephyrError("layouts fold: missing client identity for " & client.winid)

    let source = initial[index]
    let destination = foldDestination(cells[index], columns, rows,
      screenGeometry, source, spread)
    placement.records.add((client.winid, client.token.get, source))
    if source != destination:
      placement.history.add((client.winid, client.token.get, source))
    placement.applications.add((client.winid, client.token.get, destination))

  proc raisePlacement() =
    window.raiseMany(placement.applications.mapIt(it.winid))

  proc restoreFocus() =
    # Explicit multi-raise preserves focus. Avoid raising an unrelated focused
    # window back over the placement merely to reaffirm its existing focus.
    if query.focusedWinid() != focusedWinid:
      window.focus(focusedWinid)
      raisePlacement()

  if checkpointRoot.isSome:
    var operation = state.beginExplodeOperationIdentity(checkpointRoot.get,
      placement.records, placement.history, preserveOriginal = true)
    if placement.history.len > 0:
      window.applyGeometriesChecked(placement.applications)
    state.markExplodeGeometryApplied(operation)
    raisePlacement()
    state.commitExplodeOperation(operation)
    restoreFocus()
    return

  if placement.history.len == 0:
    raisePlacement()
    restoreFocus()
    return

  var transaction = state.beginRestoreHistoryIdentity(placement.history)
  window.applyGeometriesChecked(placement.applications)
  state.commitRestoreHistory(transaction)
  raisePlacement()
  restoreFocus()

proc explodeDestination(cell: PlacementCell, columns, rows: int,
    screen: ScreenGeometry): Geometry =
  let tileWidth = (screen.width - (columns - 1) * screen.gap) div columns
  let tileHeight = (screen.height - (rows - 1) * screen.gap) div rows
  Geometry(
    x: tileWidth * (cell.column - 1) + screen.margin +
      (cell.column - 1) * screen.gap,
    y: tileHeight * (cell.row - 1) + screen.top +
      (cell.row - 1) * screen.gap,
    width: tileWidth,
    height: tileHeight
  )

proc raisePlacement(applications: seq[window.CheckedGeometryApplication]) =
  window.raiseMany(applications.mapIt(it.winid))

proc restoreFocus(focusedWinid: string,
    applications: seq[window.CheckedGeometryApplication]) =
  if focusedWinid.len > 0 and query.focusedWinid() != focusedWinid:
    window.focus(focusedWinid)
    raisePlacement(applications)

proc applyGroupExplode*(clients: seq[PlacementClient],
    cells: seq[PlacementCell], columns, rows: int, checkpointRoot: string,
    focusedWinid: string) =
  if clients.len == 0:
    raiseZephyrError("layouts explode --group: no matching windows")
  if cells.len != clients.len:
    raiseZephyrError("layouts explode --group: invalid placement plan")

  state.recoverExplodeOperation(checkpointRoot)
  var placement: FoldPlacement
  let screenGeometry = window.screenGeometry()

  for index, client in clients:
    if client.token.isNone:
      raiseZephyrError("layouts explode --group: missing client identity for " & client.winid)
    let source = query.geometry(client.winid)
    let destination = explodeDestination(cells[index], columns, rows, screenGeometry)
    placement.records.add((client.winid, client.token.get, source))
    if source != destination:
      placement.history.add((client.winid, client.token.get, source))
    placement.applications.add((client.winid, client.token.get, destination))

  var operation = state.beginExplodeOperationIdentity(checkpointRoot,
    placement.records, placement.history)
  window.applyGeometriesChecked(placement.applications)
  state.markExplodeGeometryApplied(operation)
  raisePlacement(placement.applications)
  state.commitExplodeOperation(operation)

  if focusedWinid.len > 0 and focusedWinid in window.liveIds(@["--all"]).splitLines():
    restoreFocus(focusedWinid, placement.applications)

proc applyStackExplode*(sources: seq[PlacementSource],
    cells: seq[PlacementCell], columns, rows: int, checkpointRoot: string,
    focusedWinid: string) =
  if sources.len == 0:
    raiseZephyrError("layouts explode: no matching windows")
  if cells.len != sources.len:
    raiseZephyrError("layouts explode: invalid placement plan")

  state.recoverExplodeOperation(checkpointRoot)
  var
    records: seq[state.IdentityExplodeStateRecord] = @[]
    history: seq[state.IdentityHistoryUpdate] = @[]
    applications: seq[window.GeometryApplication] = @[]
  let screenGeometry = window.screenGeometry()

  for index, source in sources:
    if source.client.token.isNone:
      raiseZephyrError("layouts explode: missing client identity for " & source.client.winid)
    let destination = explodeDestination(cells[index], columns, rows, screenGeometry)
    records.add((source.client.winid, source.client.token.get, source.geometry))
    if source.geometry != destination:
      history.add((source.client.winid, source.client.token.get, source.geometry))
    applications.add((source.client.winid, destination))

  var operation = state.beginExplodeOperationIdentity(checkpointRoot, records, history)
  window.applyGeometries(applications)
  state.markExplodeGeometryApplied(operation)
  window.raiseMany(sources.mapIt(it.client.winid))
  state.commitExplodeOperation(operation)
  window.focus(focusedWinid)

proc restoreCheckpoint*(root, command: string, missingState = "") =
  state.recoverExplodeOperation(root)
  state.recoverExplodeState(root)
  let explodeLock = state.acquireExplodeLock(root)
  defer: state.releaseExplodeLock(explodeLock)

  let recorded = state.loadStateEntries(root)
  if recorded.len == 0:
    if dirExists(root):
      removeDir(root)
    state.releaseExplodeLock(explodeLock)
    raiseZephyrError(if missingState.len > 0: missingState else:
      command & ": no matching windows")

  let liveSnapshot = query.wmSnapshot()
  var existing = initHashSet[string]()
  for client in liveSnapshot.clients:
    existing.incl(client.winid)
  let focusedBefore = liveSnapshot.focused.get("")
  var tokens = initTable[string, Option[query.ClientToken]]()
  for client in liveSnapshot.clients:
    tokens[client.winid] = client.token

  var applications: seq[window.CheckedGeometryApplication] = @[]
  for entry in recorded:
    let token = tokens.getOrDefault(entry.winid)
    if entry.winid in existing and token.isSome and token.get == entry.token:
      applications.add((entry.winid, entry.token, entry.geometry))

  if applications.len > 0:
    window.applyGeometriesChecked(applications)
    if focusedBefore.len > 0 and focusedBefore in existing and
        query.focusedWinid() != focusedBefore:
      window.focus(focusedBefore)
  removeDir(root)

proc applyLevel*(clients: seq[PlacementClient]) =
  if clients.len == 0:
    return
  let screenGeometry = window.screenGeometry()
  var applications: seq[window.CheckedGeometryApplication] = @[]

  for client in clients:
    if client.token.isNone:
      raiseZephyrError("layouts level: missing client identity for " & client.winid)
    let source = query.geometry(client.winid)
    let destination = Geometry(
      x: source.x,
      y: (screenGeometry.height - source.height) div 2 + screenGeometry.top,
      width: source.width,
      height: source.height
    )
    if destination == source:
      state.saveGeometry(source, client.winid)
    else:
      state.saveOriginalIfChanged(source, destination, client.winid)
    applications.add((client.winid, client.token.get, destination))

  if applications.len > 0:
    window.applyGeometriesChecked(applications)

proc recoverRestoreHistory*() =
  state.recoverRestoreHistory(getEnv("WINFO"))

proc applyRestore*(clients: seq[PlacementClient], focusedWinid: string,
    all: bool) =
  if all:
    if clients.len == 0:
      return
    type RestorePlan = tuple[
      winid: string,
      token: query.ClientToken,
      destination: Geometry,
      source: Geometry
    ]
    var plan: seq[RestorePlan] = @[]
    for client in clients:
      if client.token.isNone or not state.hasGeometryForToken(client.winid, client.token.get):
        continue
      plan.add((client.winid, client.token.get,
        state.loadGeometryForToken(client.winid, client.token.get),
        query.geometry(client.winid)))
    if plan.len == 0:
      return
    let existing = window.liveIds(@["--all"]).splitLines.toHashSet
    var
      applications: seq[window.CheckedGeometryApplication] = @[]
      survivors: seq[RestorePlan] = @[]
    for entry in plan:
      if entry.winid in existing:
        applications.add((entry.winid, entry.token, entry.destination))
        survivors.add(entry)
    if applications.len == 0:
      return
    var updates: seq[state.IdentityHistoryUpdate] = @[]
    for entry in survivors:
      updates.add((entry.winid, entry.token, entry.source))
    var transaction = state.beginRestoreHistoryIdentity(updates)
    window.applyGeometriesChecked(applications)
    state.commitRestoreHistory(transaction)
    return

  if clients.len == 0:
    return
  var
    applications: seq[window.CheckedGeometryApplication] = @[]
    historyUpdates: seq[state.IdentityHistoryUpdate] = @[]
  for client in clients:
    if client.token.isNone or not state.hasGeometryForToken(client.winid, client.token.get):
      continue
    let saved = state.loadGeometryForToken(client.winid, client.token.get)
    let current = query.geometry(client.winid)
    applications.add((client.winid, client.token.get, saved))
    historyUpdates.add((client.winid, client.token.get, current))
  if applications.len > 0:
    var transaction = state.beginRestoreHistoryIdentity(historyUpdates)
    window.applyGeometriesChecked(applications)
    state.commitRestoreHistory(transaction)
  window.focus(focusedWinid)
