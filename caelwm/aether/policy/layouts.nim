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
import ../wm/daemon_client
import ../wm/group as groups
import ../wm/group_id
import ../wm/placement
import ../wm/types
import ../wm/window
import ../wm/window_query as query
import ./layout_bias
import ./layout_bias_access

export layout_bias.LayoutBias
export layout_bias_access.bias


# Updates resident policy bias when initialized; otherwise sets it through daemon IPC.
# Raises an error if the remote update fails or its acknowledgement differs.

proc setBias*(value: LayoutBias) =
  if localBias().isSome:
    setResidentBias(value)
    return
  let reply = queryDaemon(RequestSetLayoutBias, $value)
  if not reply.ok:
    raiseZephyrError("layout bias: " & reply.error)
  if reply.responseKind != RequestSetLayoutBias or reply.body != $value:
    raiseZephyrError("layout bias: unexpected response")


# Prints the current bias or sets it from a single left or right argument.

proc biasCommand(args: seq[string]) =
  requireArgs("layout bias", args, 0, 1)
  if args.len == 0:
    echo bias()
  else:
    setBias(parseLayoutBias(args[0]))


# Returns lexically sorted snapshot window IDs, optionally restricted to mapped clients
# and a group.

proc snapshotWinids*(snapshot: query.WmSnapshot, mappedOnly: bool,
    groupNo = none(PublicGroupId)): seq[string] =
  for client in snapshot.clients:
    if (not mappedOnly or client.mapped) and
        (groupNo.isNone or client.group == groupNo.get.intValue.uint32):
      result.add(client.winid)
  result.sort()


# Returns the snapshot focus ID, or an empty string when no window is focused.

proc snapshotFocusedWinid*(snapshot: query.WmSnapshot): string =
  if snapshot.focused.isSome:
    result = snapshot.focused.get()

proc columnOrder*(columns, rows, position: int,
    layoutBias: LayoutBias): int


# Attaches snapshot identity tokens to window IDs while preserving the supplied order.
# Leaves tokens absent for IDs missing from the snapshot.

proc clientsFor(snapshot: query.WmSnapshot,
    winids: seq[string]): seq[PlacementClient] =
  var tokens = initTable[string, Option[query.ClientToken]]()
  for client in snapshot.clients:
    tokens[client.winid] = client.token
  for winid in winids:
    result.add(PlacementClient(winid: winid, token: tokens.getOrDefault(winid)))


# Assigns windows to physical grid cells using the supplied bias and column-first row order.
# Wraps assignments when the count exceeds grid capacity; applies no geometry.

proc gridCells(count, columns, rows: int,
    layoutBias: LayoutBias): seq[PlacementCell] =
  for position in 1 .. count:
    let column = columnOrder(columns, rows, position, layoutBias)
    let row = (position - 1) mod rows + 1
    result.add(PlacementCell(column: column, row: row))


# Selects the fixed explode grid dimensions for a window count.

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


# Maps a one-based assignment position to a physical column using the captured bias.
# Preserves left-bias preference, fills columns before advancing and wraps at capacity.
# Requires positive column, row and position values; callers must not mirror the result.

proc columnOrder*(columns, rows, position: int,
    layoutBias: LayoutBias): int =
  let order =
    case columns
    of 1: @[1]
    of 2: @[2, 1]
    of 3: @[2, 3, 1]
    of 4: @[3, 4, 2, 1]
    of 5: @[3, 4, 5, 2, 1]
    else: toSeq(1 .. columns)
  let logicalColumn = order[((position - 1) div rows) mod columns]
  physicalColumn(columns, logicalColumn, layoutBias)


# Keeps the requested grid when it fits, otherwise selects two or three rows.
# For larger counts, uses three rows with an extra blank column
# when count is divisible by three.

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


# Selects snapshot IDs by group first, then live WM IDs by class, or snapshot IDs otherwise.
# The class branch uses the live query's mapped-window filtering rather than mappedOnly.

proc selectedWinids(snapshot: query.WmSnapshot, mappedOnly: bool,
    groupNo: Option[PublicGroupId], classname: string): seq[string] =
  if groupNo.isSome:
    return snapshotWinids(snapshot, mappedOnly, groupNo)
  if classname.len > 0:
    # Query the WM directly. A layout policy can run synchronously inside
    # Aetherd, where a request to its own IPC socket would deadlock the loop.
    return window.liveIds(@[classname]).splitLines()
  snapshotWinids(snapshot, mappedOnly)


# Returns the class fold checkpoint path under WME with the class name URL-encoded.

proc classFoldRoot(classname: string): string =
  getEnv("WME") / "layout" / ("fold:class:" & encodeUrl(classname, usePlus = false))


# Returns the group fold checkpoint path under WME using the public group number.

proc groupFoldRoot(group: PublicGroupId): string =
  getEnv("WME") / "layout" / ("fold:group:" & $group.intValue)


# Returns the checkpoint path under WME for folding all selected windows.

proc allFoldRoot(): string =
  getEnv("WME") / "layout" / "fold:all"


# Assigns selected windows to grid cells using one bias snapshot for the operation.
# Delegates geometry application and restore history to placement, optionally recording
# a group, class or all-windows checkpoint; spread mode preserves window sizes.

proc fold*(args: seq[string]) =
  requireArgs("layouts fold", args, 1, 7)
  let a = parseArguments("layouts fold", args,
    [ArgColumns, ArgRows, ArgClassname, ArgGroupNo, ArgSpread, ArgRecord],
    groups.count)
  let operationBias = bias()
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
    gridCells(winids.len, columns, rows, operationBias), columns, rows, a.spread,
    checkpointRoot, snapshotFocusedWinid(snapshot))


# Restores the group, class or all-windows fold checkpoint, in that precedence order.
# Delegates recovery, identity checks and checkpoint removal to placement;
# raises an error when the selected checkpoint contains no recorded state.

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


# Assigns mapped group windows or the live stack to a count-based grid
# using one bias snapshot.
# Delegates geometry application and checkpoint recording to placement, using separate
# group and stack checkpoint paths for later restoration.

proc explode*(args: seq[string]) =
  requireArgs("layouts explode", args, 0, 2)
  let a = parseArguments("layouts explode", args, [ArgGroupNo], groups.count)
  let operationBias = bias()
  let snapshot = query.wmSnapshot()
  if a.groupNo.isSome:
    let group = a.groupNo.get
    let winids = snapshotWinids(snapshot, true, some(group))
    let dimensions = spreadGrid(winids.len)
    placement.applyGroupExplode(clientsFor(snapshot, winids),
      gridCells(winids.len, dimensions.columns, dimensions.rows, operationBias),
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
    gridCells(stack.len, dimensions.columns, dimensions.rows, operationBias),
    dimensions.columns, dimensions.rows,
    getEnv("WME") / "layout" / "explode", query.focusedWinid())


# Restores the selected group or stack explode checkpoint through placement.
# Delegates recovery, identity checks and checkpoint removal;
# errors on missing recorded state.

proc unexplode*(args: seq[string]) =
  requireArgs("layouts unexplode", args, 0, 2)
  let a = parseArguments("layouts unexplode", args, [ArgGroupNo], groups.count)
  if a.groupNo.isSome:
    let root = getEnv("WME") / "layout" / ("explode:group:" & $a.groupNo.get.intValue)
    placement.restoreCheckpoint(root, "layouts unexplode --group")
  else:
    placement.restoreCheckpoint(getEnv("WME") / "layout" / "explode",
      "layouts unexplode")


# Returns grid dimensions as command arguments for the selected window count.
# Raises an error when no windows match; calculates dimensions without applying geometry.

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


# Resolves grid arguments into physical cells using the captured operation bias.
# Implicit assignments are already oriented; only tile explicit columns are bias-relative.
# Queries the screen when its supplied width is zero and delegates geometry to the action.

proc gridOperation(command: string, args: seq[string], layoutBias: LayoutBias,
    action: GridAction, biasRelativeColumn = false,
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
    if a.column.isSome:
      if biasRelativeColumn: physicalColumn(columns, a.column.get, layoutBias)
      else: a.column.get
    else: columnOrder(columns, rows, position, layoutBias)
  let row = (position - 1) mod rows + 1
  action(columns, rows, column, row, a.winid, screenGeometry, sourceGeometry)


# Tiles the target using one bias snapshot, orienting explicit and implicit columns once.
# Passes the resolved physical cell to the bias-independent geometry boundary.

proc tile*(args: seq[string]) =
  let operationBias = bias()
  gridOperation("tile", args, operationBias,
    proc(columns, rows, column, row: int, winid: string,
        screen: ScreenGeometry, geometry: Geometry) =
      window.tileGrid(columns, rows, column, row, winid, screen, geometry),
    biasRelativeColumn = true)


# Positions the target window within a grid while preserving its size.
# Uses one bias snapshot for implicit assignment; explicit spread columns stay physical.

proc spread*(args: seq[string]) =
  let operationBias = bias()
  gridOperation("spread", args, operationBias,
    proc(columns, rows, column, row: int, winid: string,
        screen: ScreenGeometry, geometry: Geometry) =
      window.spreadGrid(columns, column, rows, row, winid, screen, geometry))


# Vertically centers mapped snapshot windows through placement and records restore geometry.

proc level*(args: seq[string]) =
  requireNoArgs("layouts level", args)
  let snapshot = query.wmSnapshot()
  placement.applyLevel(clientsFor(snapshot, snapshotWinids(snapshot, true)))


# Restores saved geometry for mapped snapshot clients, or all clients with --all.
# Recovers restore history before acquiring the all-client snapshot; placement checks
# identity-bound history and records current geometry for subsequent restoration.

proc restore*(args: seq[string]) =
  requireArgs("layouts restore", args, 0, 1)
  let a = parseArguments("layouts restore", args, [ArgAll])
  if a.all:
    placement.recoverRestoreHistory()
  let snapshot = query.wmSnapshot()
  let clients = clientsFor(snapshot, snapshotWinids(snapshot, not a.all))
  placement.applyRestore(clients, snapshotFocusedWinid(snapshot), a.all)


# Routes layout actions, prints grid results and raises an error for unknown verbs.

proc dispatch*(verb: string, rest: seq[string]) =
  case verb
  of "bias": biasCommand(rest)
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
