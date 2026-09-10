import std/os
import std/strutils
import std/sequtils
import std/sets

import cliargs
# import constants
import compat
import state
import types
import window
import window_query as query

#
# Helpers
#

type
  GridAction = proc(
    args: seq[string],
    screenGeometry: ScreenGeometry,
    sourceGeometry: Geometry
  )

proc grid(
  command: string,
  args: seq[string],
  action: GridAction,
  providedScreen = ScreenGeometry(),
  sourceGeometry = Geometry()
) =
  requireArgs(command, args, 1, 6)

  var a = parseArguments(
    command,
    args,
    [
      ArgColumns,
      ArgColumn,
      ArgColumnName,
      ArgRows,
      ArgPosition,
      ArgWinid
    ]
  )

  if a.rows == -1:
    a.rows = 1
  if a.position == -1:
    a.position = 1

  let screenGeometry =
    if providedScreen.width == 0:
      window.screenGeometry()
    else:
      providedScreen

  proc column(): int =
    if a.column > 0:
      return a.column
    let columnOrder =
      case a.columns
      of 1: @[1]
      of 2: @[2, 1]
      of 3: @[2, 3, 1]
      of 4: @[3, 4, 2, 1]
      of 5: @[3, 4, 5, 2, 1]
      else: toSeq(1 .. a.columns)
    if a.rows == 1:
      result = columnOrder[(a.position - 1) mod a.columns]
    else:
      result = columnOrder[((a.position - 1) div a.rows) mod a.columns]

  proc row(): int =
    (a.position - 1) mod a.rows + 1

  if a.rows == 1:
    action(@[
      $a.columns,
      $column(),
      a.winid],
      screenGeometry,
      sourceGeometry
    )
  else:
    action(@[
      $a.columns,
      $column(),
      "--rows", $a.rows,
      "--row", $row(),
      a.winid],
      screenGeometry,
      sourceGeometry
    )

proc tileWithScreen(
  args: seq[string],
  screenGeometry: ScreenGeometry,
  sourceGeometry = Geometry()
) =
  grid("tile", args, window.tile, screenGeometry, sourceGeometry)

proc spreadWithScreen(
  args: seq[string],
  screenGeometry: ScreenGeometry,
  sourceGeometry = Geometry()
) =
  grid("spread", args, window.spread, screenGeometry, sourceGeometry)

proc explodeDestination(
  columns, rows, position: int,
  s: ScreenGeometry
): Geometry =
  let columnOrder =
    case columns
    of 1: @[1]
    of 2: @[2, 1]
    of 3: @[2, 3, 1]
    of 4: @[3, 4, 2, 1]
    of 5: @[3, 4, 5, 2, 1]
    else: toSeq(1 .. columns)
  let column =
    if rows == 1:
      columnOrder[(position - 1) mod columns]
    else:
      columnOrder[((position - 1) div rows) mod columns]
  let row = (position - 1) mod rows + 1
  let tileWidth = (s.width - (columns - 1) * s.gap) div columns
  let tileHeight = (s.height - (rows - 1) * s.gap) div rows
  Geometry(
    x: tileWidth * (column - 1) + s.margin + (column - 1) * s.gap,
    y: tileHeight * (row - 1) + s.top + (row - 1) * s.gap,
    width: tileWidth,
    height: tileHeight
  )

proc foldDestination(
  columns, rows, position: int,
  screen: ScreenGeometry,
  source: Geometry,
  spread: bool
): Geometry =
  let columnOrder =
    case columns
    of 1: @[1]
    of 2: @[2, 1]
    of 3: @[2, 3, 1]
    of 4: @[3, 4, 2, 1]
    of 5: @[3, 4, 5, 2, 1]
    else: toSeq(1 .. columns)
  let column =
    if rows == 1:
      columnOrder[(position - 1) mod columns]
    else:
      columnOrder[((position - 1) div rows) mod columns]
  let row = (position - 1) mod rows + 1
  let tileWidth = (screen.width - (columns - 1) * screen.gap) div columns
  let tileHeight = (screen.height - (rows - 1) * screen.gap) div rows

  if spread:
    if screen.height < rows * source.height + (rows - 1) * screen.gap:
      quit("layout fold: window exceeds row height")
    return Geometry(
      x: tileWidth * (column - 1) + screen.margin +
        (column - 1) * screen.gap + (tileWidth - source.width) div 2,
      y: tileHeight * (row - 1) + screen.top +
        (row - 1) * screen.gap + (tileHeight - source.height) div 2,
      width: source.width,
      height: source.height
    )

  Geometry(
    x: tileWidth * (column - 1) + screen.margin + (column - 1) * screen.gap,
    y: tileHeight * (row - 1) + screen.top + (row - 1) * screen.gap,
    width: tileWidth,
    height: tileHeight
  )

#
# Actions
#

proc level*(args: seq[string]) =
  requireNoArgs("layout level", args)

  let winids = window.liveIds(@[])

  if winids == "":
    return

  let screenGeometry = window.screenGeometry()
  let identitySnapshot = query.wmSnapshot()
  var applications: seq[window.CheckedGeometryApplication] = @[]

  for wid in winids.splitLines():
    let source = query.geometry(wid)
    let destination = Geometry(
      x: source.x,
      y: (screenGeometry.height - source.height) div 2 + screenGeometry.top,
      width: source.width,
      height: source.height
    )
    var token = query.ClientToken()
    for client in identitySnapshot.clients:
      if client.winid == wid:
        token = client.token
        break
    if not token.isPresent:
      quit("layout level: missing client identity for " & wid)
    if destination == source:
      state.saveGeometry(source, wid)
    else:
      state.saveOriginalIfChanged(source, destination, wid)
    applications.add((wid, token, destination))

  if applications.len > 0:
    window.applyGeometriesChecked(applications)

proc restore*(args: seq[string]) =
  requireArgs("layout restore", args, 0, 1)

  let a = parseArguments(
    "layout restore",
    args,
    [
      ArgAll
    ]
  )

  if a.all:
    type RestorePlan = tuple[
      winid: string,
      token: query.ClientToken,
      destination: Geometry,
      source: Geometry
    ]

    state.recoverRestoreHistory(getEnv("WINFO"))
    let winids = window.liveIds(@["--all"])
    if winids == "":
      return

    var plan: seq[RestorePlan] = @[]
    let identitySnapshot = query.wmSnapshot()

    # Read every destination and live source before submitting any geometry.
    # This preserves the restore toggle state while giving bulk application a
    # complete, pre-mutation plan.
    for winid in winids.splitLines():
      var token = query.ClientToken()
      for client in identitySnapshot.clients:
        if client.winid == winid:
          token = client.token
          break
      if not token.isPresent or not hasGeometryForToken(winid, token):
        continue
      plan.add((winid, token, loadGeometryForToken(winid, token), query.geometry(winid)))

    if plan.len == 0:
      return

    # A target may disappear after the initial ids query.  Filter against one
    # all-managed observation, retaining the original restore order.
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

    # Prepare a complete replacement WINFO tree before touching the WM.  The
    # transaction remains PREPARED until the bulk acknowledgement arrives.
    var identityUpdates: seq[state.IdentityHistoryUpdate] = @[]
    for entry in survivors:
      identityUpdates.add((entry.winid, entry.token, entry.source))
    var transaction = state.beginRestoreHistoryIdentity(identityUpdates)

    # Preserve toggle/history semantics only after the WM acknowledges the
    # complete bulk application.  If this process dies after acknowledgement,
    # the durable transaction marker lets the next state operation roll the
    # complete generation forward.
    window.applyGeometriesChecked(applications)
    state.commitRestoreHistory(transaction)
    return

  let winid = query.focusedWinid()
  let winids = window.liveIds(@[])

  if winids == "":
    return

  var
    applications: seq[window.CheckedGeometryApplication] = @[]
    historyUpdates: seq[state.IdentityHistoryUpdate] = @[]

  let identitySnapshot = query.wmSnapshot()
  for wid in winids.splitLines():
    var token = query.ClientToken()
    for client in identitySnapshot.clients:
      if client.winid == wid:
        token = client.token
        break
    if not token.isPresent or not state.hasGeometryForToken(wid, token):
      continue

    let saved = state.loadGeometryForToken(wid, token)
    let current = query.geometry(wid)
    applications.add((wid, token, saved))
    historyUpdates.add((wid, token, current))

  if applications.len > 0:
    var transaction = state.beginRestoreHistoryIdentity(historyUpdates)
    window.applyGeometriesChecked(applications)
    state.commitRestoreHistory(transaction)

  focus(winid)

proc tile*(args: seq[string]) =
  tileWithScreen(args, ScreenGeometry())

proc spread*(args: seq[string]) =
  spreadWithScreen(args, ScreenGeometry())

proc fold*(args: seq[string]) =
  requireArgs("layout fold", args, 1, 6)

  var a = parseArguments(
    "layout fold",
    args,
    [
      ArgColumns,
      ArgRows,
      ArgClassname,
      ArgSpread
    ]
  )

  let winid = query.focusedWinid()

  if a.rows == -1:
    a.rows = 1

  let winids =
    if a.classname.len > 0:
      window.ids(@[a.classname]).splitLines()
    else:
      window.liveIds(@[]).splitLines()

  if winids.len == 0:
    quit("layout fold: no matching windows")

  let screenGeometry = window.screenGeometry()
  var
    initial: seq[Geometry] = @[]
    applications: seq[window.CheckedGeometryApplication] = @[]
    history: seq[state.IdentityHistoryUpdate] = @[]
  let identitySnapshot = query.wmSnapshot()

  # Capture every source geometry before any fold mutation occurs.  This
  # preserves spread sizing and the original-history comparison semantics.
  for winid in winids:
    initial.add(query.geometry(winid))

  for index, winid in winids:
    let source = initial[index]
    var token = query.ClientToken()
    for client in identitySnapshot.clients:
      if client.winid == winid:
        token = client.token
        break
    if not token.isPresent:
      quit("layout fold: missing client identity for " & winid)
    let destination = foldDestination(
      a.columns,
      a.rows,
      index + 1,
      screenGeometry,
      source,
      a.spread
    )
    if source != destination:
      history.add((winid, token, source))
    applications.add((winid, token, destination))

  if history.len == 0:
    focus(winid)
    return

  var transaction = state.beginRestoreHistoryIdentity(history)
  window.applyGeometriesChecked(applications)
  state.commitRestoreHistory(transaction)

  focus(winid)

proc explode*(args: seq[string]) =
  requireNoArgs("layout explode", args)

  let stack = query.stackGeometries()

  if stack.len == 0:
    quit("layout explode: no matching windows")

  var
    columns = 1
    rows = 1

  case stack.len
  of 1:
    return
  of 2:
    columns = 3
  of 3:
    columns = 4
  of 4:
    columns = 3
    rows = 2
  of 5 .. 9:
    columns = 4
    rows = 3
  else:
    columns = 5
    rows = 3

  let root = getEnv("WME") / "layout" / "explode"
  state.recoverExplodeOperation(root)
  var position = 1
  let screenGeometry = window.screenGeometry()
  let identitySnapshot = query.wmSnapshot()
  var records: seq[state.IdentityExplodeStateRecord] = @[]
  var history: seq[state.IdentityHistoryUpdate] = @[]
  var applications: seq[window.GeometryApplication] = @[]

  for entry in stack:
    var token = query.ClientToken()
    for client in identitySnapshot.clients:
      if client.winid == entry.winid:
        token = client.token
        break
    if not token.isPresent:
      quit("layout explode: missing client identity for " & entry.winid)
    records.add((entry.winid, token, entry.geometry))

    let destination = explodeDestination(
      columns,
      rows,
      position,
      screenGeometry,
    )
    if entry.geometry != destination:
      history.add((entry.winid, token, entry.geometry))
    applications.add((entry.winid, destination))

    inc position

  var operation = state.beginExplodeOperationIdentity(root, records, history)

  window.applyGeometries(applications)
  state.markExplodeGeometryApplied(operation)
  window.raiseMany(stack.mapIt(it.winid))
  state.commitExplodeOperation(operation)

proc unexplode*(args: seq[string]) =
  requireNoArgs("layout unexplode", args)

  let root = getEnv("WME") / "layout" / "explode"

  state.recoverExplodeOperation(root)
  state.recoverExplodeState(root)
  let explodeLock = acquireExplodeLock(root)
  defer: releaseExplodeLock(explodeLock)

  let recorded = loadStateEntries(root)

  if recorded.len == 0:
    # Legacy tokenless explode generations cannot safely identify their
    # original client instances; discard them without touching WM geometry.
    if dirExists(root):
      removeDir(root)
    releaseExplodeLock(explodeLock)
    quit("layout unexplode: no matching windows")

  let existing = window.liveIds(@["--all"]).splitLines.toHashSet
  let focusedBefore = query.focusedWinid()
  var
    applications: seq[window.CheckedGeometryApplication] = @[]

  let liveSnapshot = query.wmSnapshot()
  for entry in recorded:
    if entry.winid in existing:
      for client in liveSnapshot.clients:
        if client.winid == entry.winid and client.token == entry.token:
          applications.add((entry.winid, entry.token, entry.geometry))
          break

  # let focused = loadStateFocus(root)

  # if focused.len > 0:
  #   focus(focused)

  if applications.len > 0:
    window.applyGeometriesChecked(applications)
    # Explicit geometry is not an addressing operation, but sloppy-focus
    # EnterNotify delivery can still change attention when a survivor moves
    # beneath the pointer.  Preserve the focus that was authoritative at the
    # start of unexplode, never the pre-explode focus.
    if focusedBefore.len > 0 and focusedBefore in existing and
        query.focusedWinid() != focusedBefore:
      focus(focusedBefore)
  removeDir(root)

#
# Native Nim convenience overloads
#

proc fold*(columns: string) =
  fold(@[columns])

proc fold*(columns, classname: string) =
  fold(@[columns, classname])

proc fold*(columns, classname, spread: string) =
  fold(@[columns, classname, spread])

proc fold*(arg1, arg2, arg3, arg4: string) =
  fold(@[arg1, arg2, arg3, arg4])

proc fold*(arg1, arg2, arg3, arg4, arg5: string) =
  fold(@[arg1, arg2, arg3, arg4, arg5])

proc spread*(columns: string) =
  spread(@[columns])

proc spread*(columns, classname: string) =
  spread(@[columns, classname])

proc spread*(columns, position, classname: string) =
  spread(@[columns, position, classname])

proc spread*(arg1, arg2, arg3, arg4: string) =
  spread(@[arg1, arg2, arg3, arg4])

proc tile*(columns: string) =
  tile(@[columns])

proc tile*(columns, classname: string) =
  tile(@[columns, classname])

proc tile*(arg1, arg2, arg3, arg4: string) =
  tile(@[arg1, arg2, arg3, arg4])

#
# Dispatch
#

proc dispatch*(verb: string, rest: seq[string]) =
  case verb
  of "explode":
    explode(rest)
  of "fold":
    fold(rest)
  of "level":
    level(rest)
  of "restore":
    restore(rest)
  of "spread":
    spread(rest)
  of "tile":
    tile(rest)
  of "unexplode":
    unexplode(rest)
  else:
    quit("unknown layout action")
