import std/algorithm
import std/options
import std/os
import std/sequtils
import std/strutils
import std/tables
import std/uri

import ../zephyr_errors
import ../wm/cliargs
import ../wm/compat
import ../wm/group as groups
import ../wm/group_id
import ../wm/placement
import ../wm/types
import ../wm/window
import ../wm/window_query as query

proc snapshotWinids*(snapshot: query.WmSnapshot, mappedOnly: bool,
    groupNo = none(PublicGroupId)): seq[string] =
  for client in snapshot.clients:
    if (not mappedOnly or client.mapped) and
        (groupNo.isNone or client.group == groupNo.get.intValue.uint32):
      result.add(client.winid)
  result.sort()

proc snapshotFocusedWinid*(snapshot: query.WmSnapshot): string =
  if snapshot.focused.isSome:
    result = snapshot.focused.get()

proc columnOrder*(columns, rows, position: int): int

proc clientsFor(snapshot: query.WmSnapshot,
    winids: seq[string]): seq[PlacementClient] =
  var tokens = initTable[string, Option[query.ClientToken]]()
  for client in snapshot.clients:
    tokens[client.winid] = client.token
  for winid in winids:
    result.add(PlacementClient(winid: winid, token: tokens.getOrDefault(winid)))

proc gridCells(count, columns, rows: int): seq[PlacementCell] =
  for position in 1 .. count:
    let column = columnOrder(columns, rows, position)
    let row = (position - 1) mod rows + 1
    result.add(PlacementCell(column: column, row: row))

proc spreadGrid*(count: int): Spread =
  result.columns = 1
  result.rows = 1
  case count
  of 1: return
  of 2: result.columns = 3
  of 3: result.columns = 4
  of 4:
    result.columns = 3
    result.rows = 2
  of 5 .. 9:
    result.columns = 4
    result.rows = 3
  else:
    result.columns = 5
    result.rows = 3

proc columnOrder*(columns, rows, position: int): int =
  let order =
    case columns
    of 1: @[1]
    of 2: @[2, 1]
    of 3: @[2, 3, 1]
    of 4: @[3, 4, 2, 1]
    of 5: @[3, 4, 5, 2, 1]
    else: toSeq(1 .. columns)
  if rows == 1:
    result = order[(position - 1) mod columns]
  else:
    result = order[((position - 1) div rows) mod columns]

proc gridDimensions*(count, columns, rows: int): Spread =
  result = Spread(columns: columns, rows: rows)
  if count <= columns * rows:
    return
  if count <= columns * 2:
    result.rows = 2
    return
  if count <= columns * 3:
    result.rows = 3
    return
  # Preserve the intended extra blank column when count is divisible by 3.
  result = Spread(columns: count div 3 + 1, rows: 3)

proc selectedWinids(snapshot: query.WmSnapshot, mappedOnly: bool,
    groupNo: Option[PublicGroupId], classname: string): seq[string] =
  if groupNo.isSome:
    return snapshotWinids(snapshot, mappedOnly, groupNo)
  if classname.len > 0:
    # Query the WM directly. A layout policy can run synchronously inside
    # zephyrd, where a request to its own IPC socket would deadlock the loop.
    return window.liveIds(@[classname]).splitLines()
  snapshotWinids(snapshot, mappedOnly)

proc classFoldRoot(classname: string): string =
  getEnv("WME") / "layout" / ("fold:class:" & encodeUrl(classname, usePlus = false))

proc groupFoldRoot(group: PublicGroupId): string =
  getEnv("WME") / "layout" / ("fold:group:" & $group.intValue)

proc allFoldRoot(): string =
  getEnv("WME") / "layout" / "fold:all"

proc fold*(args: seq[string]) =
  requireArgs("layouts fold", args, 1, 7)
  let a = parseArguments("layouts fold", args,
    [ArgColumns, ArgRows, ArgClassname, ArgGroupNo, ArgSpread, ArgRecord],
    groups.count)
  let snapshot = query.wmSnapshot()
  let winids = selectedWinids(snapshot, true, a.groupNo, a.classname)
  let columns = a.columns.get
  let rows = a.rows.get(1)
  let checkpointRoot =
    if not a.record:
      none(string)
    elif a.groupNo.isSome:
      some(groupFoldRoot(a.groupNo.get))
    elif a.classname.len > 0:
      some(classFoldRoot(a.classname))
    else:
      some(allFoldRoot())
  placement.applyFold(clientsFor(snapshot, winids),
    gridCells(winids.len, columns, rows), columns, rows, a.spread,
    checkpointRoot, snapshotFocusedWinid(snapshot))

proc unfold*(args: seq[string]) =
  requireArgs("layouts unfold", args, 0, 3)
  let a = parseArguments("layouts unfold", args,
    [ArgClassname, ArgGroupNo], groups.count)
  if a.groupNo.isSome:
    placement.restoreCheckpoint(groupFoldRoot(a.groupNo.get), "layouts unfold",
      "layouts unfold: no fold state for group " & $a.groupNo.get.intValue)
  elif a.classname.len > 0:
    placement.restoreCheckpoint(classFoldRoot(a.classname), "layouts unfold",
      "layouts unfold: no fold state for " & a.classname)
  else:
    placement.restoreCheckpoint(allFoldRoot(), "layouts unfold",
      "layouts unfold: no fold state for all windows")

proc explode*(args: seq[string]) =
  requireArgs("layouts explode", args, 0, 2)
  let a = parseArguments("layouts explode", args, [ArgGroupNo], groups.count)
  let snapshot = query.wmSnapshot()
  if a.groupNo.isSome:
    let group = a.groupNo.get
    let winids = snapshotWinids(snapshot, true, some(group))
    let dimensions = spreadGrid(winids.len)
    placement.applyGroupExplode(clientsFor(snapshot, winids),
      gridCells(winids.len, dimensions.columns, dimensions.rows),
      dimensions.columns, dimensions.rows,
      getEnv("WME") / "layout" / ("explode:group:" & $group.intValue),
      snapshotFocusedWinid(snapshot))
    return

  let stack = query.stackGeometries()
  var sources: seq[PlacementSource] = @[]
  let clients = clientsFor(snapshot, stack.mapIt(it.winid))
  for index, entry in stack:
    sources.add(PlacementSource(client: clients[index], geometry: entry.geometry))
  let dimensions = spreadGrid(stack.len)
  placement.applyStackExplode(sources,
    gridCells(stack.len, dimensions.columns, dimensions.rows),
    dimensions.columns, dimensions.rows,
    getEnv("WME") / "layout" / "explode", query.focusedWinid())

proc unexplode*(args: seq[string]) =
  requireArgs("layouts unexplode", args, 0, 2)
  let a = parseArguments("layouts unexplode", args, [ArgGroupNo], groups.count)
  if a.groupNo.isSome:
    let root = getEnv("WME") / "layout" / ("explode:group:" & $a.groupNo.get.intValue)
    placement.restoreCheckpoint(root, "layouts unexplode --group")
  else:
    placement.restoreCheckpoint(getEnv("WME") / "layout" / "explode",
      "layouts unexplode")

proc grid*(args: seq[string]): string =
  requireArgs("layouts grid", args, 1, 5)
  let a = parseArguments("layouts grid", args,
    [ArgColumns, ArgRows, ArgClassname, ArgGroupNo], groups.count)
  let snapshot = query.wmSnapshot()
  let winids = selectedWinids(snapshot, true, a.groupNo, a.classname)
  let columns = a.columns.get
  let rows = a.rows.get(1)

  proc format(columns, rows: int): string =
    $columns & " --rows " & $rows
  if winids.len == 0:
    raiseZephyrError("layouts grid: no matching windows")
  let dimensions = gridDimensions(winids.len, columns, rows)
  format(dimensions.columns, dimensions.rows)

type GridAction = proc(columns, rows, column, row: int, winid: string,
  screenGeometry: ScreenGeometry, sourceGeometry: Geometry)

proc gridOperation(command: string, args: seq[string], action: GridAction,
    providedScreen = ScreenGeometry(), sourceGeometry = Geometry()) =
  requireArgs(command, args, 1, 6)
  let a = parseArguments(command, args,
    [ArgColumns, ArgColumn, ArgColumnName, ArgRows, ArgPosition, ArgWinid])
  if a.columns.isNone:
    raiseZephyrError(command & ": columns must be > 0")
  let columns = a.columns.get
  let rows = a.rows.get(1)
  let position = a.position.get(1)
  let screenGeometry =
    if providedScreen.width == 0: window.screenGeometry()
    else: providedScreen
  let column =
    if a.column.isSome: a.column.get
    else: columnOrder(columns, rows, position)
  let row = (position - 1) mod rows + 1
  action(columns, rows, column, row, a.winid, screenGeometry, sourceGeometry)

proc tile*(args: seq[string]) =
  gridOperation("tile", args,
    proc(columns, rows, column, row: int, winid: string,
        screen: ScreenGeometry, geometry: Geometry) =
      window.tileGrid(columns, rows, column, row, winid, screen, geometry))

proc spread*(args: seq[string]) =
  gridOperation("spread", args,
    proc(columns, rows, column, row: int, winid: string,
        screen: ScreenGeometry, geometry: Geometry) =
      window.spreadGrid(columns, column, rows, row, winid, screen, geometry))

proc level*(args: seq[string]) =
  requireNoArgs("layouts level", args)
  let snapshot = query.wmSnapshot()
  placement.applyLevel(clientsFor(snapshot, snapshotWinids(snapshot, true)))

proc restore*(args: seq[string]) =
  requireArgs("layouts restore", args, 0, 1)
  let a = parseArguments("layouts restore", args, [ArgAll])
  if a.all:
    placement.recoverRestoreHistory()
  let snapshot = query.wmSnapshot()
  let clients = clientsFor(snapshot, snapshotWinids(snapshot, not a.all))
  placement.applyRestore(clients, snapshotFocusedWinid(snapshot), a.all)

proc dispatch*(verb: string, rest: seq[string]) =
  case verb
  of "explode": explode(rest)
  of "fold": fold(rest)
  of "grid": echo grid(rest)
  of "level": level(rest)
  of "restore": restore(rest)
  of "spread": spread(rest)
  of "tile": tile(rest)
  of "unexplode": unexplode(rest)
  of "unfold": unfold(rest)
  else: raiseZephyrError("unknown layouts action: " & verb)
