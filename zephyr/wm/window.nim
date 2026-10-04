import native_ipc as ipc
import std/envvars
import std/options
import std/os
import std/strutils
import std/algorithm
import std/sequtils
import ../zephyr_errors

import cliargs
import compat
import constants
import display
import group as groups
import screen
import state
import types

import window_query as query
import daemon_client
import group_id
import layer_types

export layer_types

type
  WindowChain* = object
    id: string
    token: query.ClientToken

proc capturedWinid*(chain: WindowChain): string = chain.id

proc checkedChainTarget(chain: WindowChain) =
  var snapshot: query.WmSnapshot
  if not query.tryWmSnapshot(snapshot):
    raiseZephyrError("window chain: unable to validate captured window " & chain.id)
  for client in snapshot.clients:
    if client.winid == chain.id:
      if client.token.isSome and client.token.get == chain.token:
        return
      raiseZephyrError("window chain: captured window identity changed for " & chain.id)
  raiseZephyrError("window chain: captured window no longer exists: " & chain.id)

proc restoreChainFocus(chain: WindowChain, focusedBefore: string) =
  if focusedBefore.len == 0 or query.focusedWinid() == focusedBefore:
    return
  chain.checkedChainTarget()
  # Restore only the focus that was authoritative before this operation. This
  # undoes EnterNotify/sloppy-focus side effects from geometry changes without
  # focusing the chain target or following focus between separate operations.
  ipc.focus(ipc.windowId(focusedBefore)).require()

proc chainForSnapshot(id: string, snapshot: query.WmSnapshot): WindowChain =
  for client in snapshot.clients:
    if client.winid == id:
      if client.token.isNone:
        raiseZephyrError("window target: client identity unavailable for " & id)
      return WindowChain(id: id, token: client.token.get)
  raiseZephyrError("window target: no managed window " & id)

proc target*(winid: string): WindowChain =
  let parsed = parseArguments("window target", @[winid], [ArgWinid]).winid
  if parsed.len == 0:
    raiseZephyrError("window target: expected an explicit winid")
  let id = parsed.toLowerAscii()
  chainForSnapshot(id, query.wmSnapshot())

proc target*(): WindowChain =
  let snapshot = query.wmSnapshot()
  if snapshot.focused.isNone:
    raiseZephyrError("window target: no focused window")
  chainForSnapshot(snapshot.focused.get(), snapshot)

proc validateChainArgumentTarget(parsedWinid, targetOverride,
    action: string): string =
  if targetOverride.len > 0 and parsedWinid.len > 0 and
      parsedWinid.toLowerAscii() != targetOverride.toLowerAscii():
    raiseZephyrError("window chain: operation cannot replace its captured target")
  if targetOverride.len > 0: targetOverride
  elif parsedWinid.len > 0: parsedWinid
  else: query.focusedWinid()

#
# Queries
#

proc classname*(args: seq[string]): string =
  requireNoArgs("window classname", args)
  query.classname(query.focusedWinid())

proc classname*(): string =
  classname(@[])

proc liveIds*(args: seq[string]): string =
  requireArgs("window ids", args, 0, 3)

  let a = parseArguments(
    "window ids",
    args,
    [
      ArgAll,
      ArgClassname,
      ArgName
    ]
  )

  if a.classname != "" and a.name != "":
    raiseZephyrError("window ids: only one of " & a.classname & " or --name " & a.name & " is allowed")

  if a.classname == "" and a.name == "":
    if a.all:
      ipc.ids(all = true)
    else:
      ipc.ids(all = false)
  elif a.classname != "":
    if a.all:
      ipc.ids(all = true, selector = ipc.ClassSelector, pattern = a.classname)
    else:
      ipc.ids(all = false, selector = ipc.ClassSelector, pattern = a.classname)
  else:
    if a.all:
      ipc.ids(all = true, selector = ipc.NameSelector, pattern = a.name)
    else:
      ipc.ids(all = false, selector = ipc.NameSelector, pattern = a.name)

proc cachedFilteredIds(includeAll: bool, classname, name: string,
    groupNo = none(PublicGroupId)): string =
  let kind = if name.len > 0: RequestQueryNameList else: RequestQueryClassList
  let pattern = if name.len > 0: name else: classname
  let reply = queryDaemonFiltered(kind, includeAll, pattern, groupNo)
  if not reply.ok:
    raiseZephyrError("window ids: " & reply.error)
  reply.body

proc cachedIds(includeAll: bool, groupNo = none(PublicGroupId)): string =
  let reply = queryDaemonClientList()
  if not reply.ok:
    raiseZephyrError("window ids: " & reply.error)
  var values: seq[string] = @[]
  for client in reply.clients:
    if (includeAll or client.mapped) and
        (groupNo.isNone or client.group == groupNo.get.intValue.uint32):
      values.add(client.winid)
  # Sirocco preserves its historical numeric-XID ordering for ids queries;
  # snapshot client order is WM list order and is not equivalent.
  values.sort()
  values.join("\n")

proc ids*(args: seq[string]): string =
  requireArgs("window ids", args, 0, 5)
  let a = parseArguments(
    "window ids",
    args,
    [
      ArgAll,
      ArgClassname,
      ArgName,
      ArgGroupNo
    ], groups.count
  )
  if a.classname == "" and a.name == "":
    return cachedIds(a.all, a.groupNo)
  if a.classname != "":
    return cachedFilteredIds(a.all, a.classname, "", a.groupNo)
  if a.name != "":
    return cachedFilteredIds(a.all, "", a.name, a.groupNo)
  liveIds(args)

proc ids*(arg: string): string =
  ids(@[arg])

proc ids*(): string =
  ids(@[])

proc count*(args: seq[string]): string =
  # Keep the historical argument-validation contract: count delegated to the
  # ids parser, whose diagnostics are named "window ids".
  requireArgs("window ids", args, 0, 3)
  let a = parseArguments(
    "window ids",
    args,
    [
      ArgAll,
      ArgClassname,
      ArgName
    ]
  )
  if a.classname == "" and a.name == "":
    let reply = queryDaemonClientList()
    if not reply.ok:
      raiseZephyrError("window count: " & reply.error)
    var total = 0
    for client in reply.clients:
      if a.all or client.mapped:
        inc total
    return $total
  let filtered = cachedFilteredIds(a.all, a.classname, a.name)
  return $filtered.splitLines().filterIt(it.len > 0).len

proc count*(classname: string): int =
  parseInt(count(@[classname]))

proc count*(): int =
  parseInt(count(@[]))

proc focusTarget(winid: string, token = none(query.ClientToken)) =
  if token.isSome:
    WindowChain(id: winid, token: token.get).checkedChainTarget()
  if winid == "--last": ipc.focusLast()
  else: ipc.focus(ipc.windowId(winid)).require()
  if token.isSome:
    WindowChain(id: winid, token: token.get).checkedChainTarget()

proc focus*(winid: string) =
  focusTarget(winid)

proc focus*(chain: WindowChain): WindowChain =
  focusTarget(chain.id, some(chain.token))
  chain

proc stackCycle*(chain: WindowChain): WindowChain =
  chain.checkedChainTarget()
  ipc.stackCycle(ipc.windowId(chain.id))
  chain.checkedChainTarget()
  chain

proc close*(chain: WindowChain): WindowChain =
  chain.checkedChainTarget()
  ipc.closeWindow(ipc.windowId(chain.id))
  chain

proc layerTarget(winid: string, layer: Layer,
    token = none(query.ClientToken)) =
  if token.isSome:
    WindowChain(id: winid, token: token.get).checkedChainTarget()
  ipc.layer(ipc.windowId(winid), layer)
  if token.isSome:
    WindowChain(id: winid, token: token.get).checkedChainTarget()

proc layer*(args: seq[string]) =
  requireArgs("window layer", args, 1, 2)
  let a = parseArguments("window layer", args, [ArgLayer, ArgWinid])
  if a.winid.len == 0:
    ipc.layer(a.layer)
  else:
    layerTarget(a.winid, a.layer)

proc layer*(chain: WindowChain, layer: Layer): WindowChain =
  layerTarget(chain.id, layer, some(chain.token))
  chain

proc layer*(value: string, winid: string = "") =
  layer(@[value, winid])

proc geometry*(args: seq[string]) =
  requireArgs("window geometry", args, 0, 1)

  let a = parseArguments(
    "window geometry",
    args,
    [
      ArgWinid
    ]
  )

  let g = query.geometry(a.winid)

  echo "X=" & $g.x
  echo "Y=" & $g.y
  echo "WIDTH=" & $g.width
  echo "HEIGHT=" & $g.height

proc wmGroup*(args: seq[string]) =
  requireArgs("window wm-group", args, 1, 1)

  let a = parseArguments(
    "window wm-group",
    args,
    [
      ArgWinid
    ]
  )

  echo query.wmGroup(a.winid)

proc wmGroups*(args: seq[string]) =
  requireNoArgs("window wm-groups", args)

  for entry in query.wmGroups():
    echo entry.winid & " " & $entry.group

proc snapshot*(args: seq[string]) =
  requireNoArgs("window snapshot", args)
  stdout.write(query.serializeWmSnapshot(query.cachedWmSnapshot()))

proc stack*(args: seq[string]): string =

  let a = parseArguments(
    "window stack",
    args,
    [
      ArgWinid
    ]
  )

  if args.len == 0:
    ipc.stack()
  else:
    ipc.stack(ipc.windowId(a.winid))

proc screenGeometry*(): ScreenGeometry =
  let metrics = screen.metrics()
  let dimensions = display.dimensions()
  result.gap = metrics.gap
  result.margin = metrics.margin
  result.top = metrics.top
  result.bottom = metrics.bottom

  result.width =
    dimensions.width - result.margin * 2

  result.height =
    dimensions.height - (result.top + result.bottom)

#
# Helpers
#

proc wtpTarget(rect: Geometry, winid: string,
    token: Option[query.ClientToken] = none(query.ClientToken))

proc wtp*(rect: Geometry, winid: string = "") =
  let wid =
    if winid.len == 0:
      query.focusedWinid()
    else:
      winid

  wtpTarget(rect, wid)

proc wtpTarget(rect: Geometry, winid: string,
    token: Option[query.ClientToken]) =
  if token.isSome:
    WindowChain(id: winid, token: token.get).checkedChainTarget()
  ipc.move(rect.x, rect.y, ipc.windowId(winid))
  if token.isSome:
    WindowChain(id: winid, token: token.get).checkedChainTarget()
  ipc.resize(rect.width, rect.height, ipc.windowId(winid))
  if token.isSome:
    WindowChain(id: winid, token: token.get).checkedChainTarget()

proc saveOriginalForTarget(source, destination: Geometry, winid: string,
    token: query.ClientToken) =
  if source == destination:
    return
  if destination.x == source.x and destination.y == source.y and
      destination.width <= source.width and destination.height <= source.height and
      query.geometry(winid) == source:
    return
  saveGeometryWithToken(source, winid, token)

proc saveGeometryForTarget(geometry: Geometry, winid: string,
    token: query.ClientToken, precheck = true) =
  if precheck and query.geometry(winid) == geometry:
    return
  saveGeometryWithToken(geometry, winid, token)

type GeometryApplication* = tuple[
  winid: string,
  geometry: Geometry
]

type CheckedGeometryApplication* = tuple[
  winid: string,
  token: query.ClientToken,
  geometry: Geometry
]

proc serializeCheckedGeometries*(entries: seq[CheckedGeometryApplication]): string

proc applyGeometries*(entries: seq[GeometryApplication]) =
  if entries.len == 0:
    raiseZephyrError("window apply-geometries: no geometry records")

  var body = newStringOfCap(entries.len * 64)
  for entry in entries:
    body.add(entry.winid & " " & $entry.geometry.x & " " &
      $entry.geometry.y & " " & $entry.geometry.width & " " &
      $entry.geometry.height & "\n")

  query.applyGeometriesBody(body)

proc applyGeometriesChecked*(entries: seq[CheckedGeometryApplication]) =
  if entries.len == 0:
    raiseZephyrError("window apply-geometries-checked: no geometry records")
  query.applyGeometriesCheckedBody(serializeCheckedGeometries(entries))

proc serializeCheckedGeometries*(entries: seq[CheckedGeometryApplication]): string =
  if entries.len == 0:
    return ""
  var body = newStringOfCap(entries.len * 120)
  for entry in entries:
    query.validateClientToken(entry.token)
    body.add(entry.winid & " " & $entry.token & " " & $entry.geometry.x & " " &
      $entry.geometry.y & " " & $entry.geometry.width & " " &
      $entry.geometry.height & "\n")
  result = body

proc raiseMany*(winids: seq[string]) =
  if winids.len == 0:
    return
  ipc.raiseMany(winids.mapIt(ipc.windowId(it)))

#
# Actions
#

proc moveTarget(dx, dy: int, winid: string,
    token = none(query.ClientToken),
    restoreFocus = false) =
  let focusedBefore = if token.isSome: query.focusedWinid() else: ""
  if token.isSome:
    WindowChain(id: winid, token: token.get).checkedChainTarget()
  ipc.move(dx, dy, ipc.windowId(winid), relative = true)
  if token.isSome:
    WindowChain(id: winid, token: token.get).checkedChainTarget()
  if restoreFocus:
    focusTarget(winid, token)
  elif token.isSome:
    WindowChain(id: winid, token: token.get).restoreChainFocus(focusedBefore)

proc move*(args: seq[string]) =
  requireArgs("window move", args, 2, 2)
  let a = parseArguments("window move", args, [ArgXY])
  let winid = focusedWinid()
  if winid.len == 0:
    return
  moveTarget(a.xy.x, a.xy.y, winid, restoreFocus = true)

proc move*(chain: WindowChain, dx, dy: int): WindowChain =
  moveTarget(dx, dy, chain.id, some(chain.token))
  chain

proc move*(chain: WindowChain, args: seq[string]): WindowChain =
  requireArgs("window move", args, 2, 2)
  let a = parseArguments("window move", args, [ArgXY])
  chain.move(a.xy.x, a.xy.y)

proc extend*(args: seq[string]) =
  requireArgs("window extend", args, 1, 3)

  let a = parseArguments(
    "window extend",
    args,
    [
      ArgDirection,
      ArgSide,
      ArgWinid
    ]
  )

  let g = query.geometry(a.winid)
  let s = screenGeometry()

  let leftWidth = g.x + g.width - s.margin
  let rightWidth = s.width - g.x + s.margin

  proc oppositeSide(): int =
    s.width + s.margin * 2 - (g.x + g.width)

  proc applyGeometry(destination: Geometry) =
    wtp(destination, a.winid)
    saveOriginalIfChanged(g, destination, a.winid)

  proc extendLeft() =
    applyGeometry(Geometry(
      x: s.margin,
      y: g.y,
      width: leftWidth,
      height: g.height
    ))

  proc extendRight() =
    applyGeometry(Geometry(
      x: g.x,
      y: g.y,
      width: rightWidth,
      height: g.height
    ))

  proc near() =
    if g.x <= oppositeSide():
      extendLeft()
    else:
      extendRight()

  proc far() =
    if g.x <= oppositeSide():
      extendRight()
    else:
      extendLeft()

  if a.direction in [Left, Right, Near, Far] and a.side != "" or a.direction == Center:
    raiseZephyrError("window extend: invalid direction " & a.direction & " " & a.side)

  case a.direction
  of Left:
    extendLeft()

  of Right:
    extendRight()

  of "near":
    near()

  of "far":
    far()

  of Top:
    let verticalHeight = g.y + g.height - s.top

    case a.side
    of "":
      applyGeometry(Geometry(
        x: g.x,
        y: s.top,
        width: g.width,
        height: verticalHeight
      ))
    of Left:
      applyGeometry(Geometry(
        x: s.margin,
        y: s.top,
        width: leftWidth,
        height: verticalHeight
      ))
    of Right:
      applyGeometry(Geometry(
        x: g.x,
        y: s.top,
        width: rightWidth,
        height: verticalHeight
      ))

  of Bottom:
    let verticalHeight = s.height - g.y + s.top

    case a.side
    of "":
      applyGeometry(Geometry(
        x: g.x,
        y: g.y,
        width: g.width,
        height: verticalHeight
      ))
    of Left:
      applyGeometry(Geometry(
        x: s.margin,
        y: g.y,
        width: leftWidth,
        height: verticalHeight
      ))
    of Right:
      applyGeometry(Geometry(
        x: g.x,
        y: g.y,
        width: rightWidth,
        height: verticalHeight
      ))

proc groupTarget(group: PublicGroupId, winid: string, sourceGroup: int,
    token = none(query.ClientToken), teleport = false) =
  let groupNo = group.intValue

  var source = sourceGroup
  if token.isSome:
    var snapshot: query.WmSnapshot
    if not query.tryWmSnapshot(snapshot):
      raiseZephyrError("window chain: unable to validate captured window " & winid)
    var found = false
    for client in snapshot.clients:
      if client.winid == winid:
        if client.token.isNone or client.token.get != token.get:
          raiseZephyrError("window chain: captured window identity changed for " & winid)
        found = true
        if source < 0:
          source = client.group.int
        break
    if not found:
      raiseZephyrError("window chain: captured window no longer exists: " & winid)

  let root = getEnv("GROUP")
  if dirExists(root / $groupNo / winid):
    return

  if source < 0:
    source = groups.currentLiveId()
  ipc.removeFromGroup(ipc.windowId(winid))
  if token.isSome:
    WindowChain(id: winid, token: token.get).checkedChainTarget()
  removeDir(root / $source / winid)
  ipc.addToGroup(groupNo, ipc.windowId(winid))
  if token.isSome:
    WindowChain(id: winid, token: token.get).checkedChainTarget()
  createDir(root / $groupNo / winid)

  let sourceFocus = (root & ":focus") / $source / winid
  if dirExists(sourceFocus):
    removeDir(sourceFocus)

  if not teleport:
    return

  let nextWinid = groups.singleChildName(root / $source)

  if nextWinid.isSome:
    var snapshot: query.WmSnapshot
    if query.tryWmSnapshot(snapshot):
      for client in snapshot.clients:
        if client.winid == nextWinid.get and client.group == uint32(source):
          focusTarget(client.winid, client.token)
          groups.add(source, client.winid)
          break

proc group*(args: seq[string]) =
  requireArgs("window group", args, 1, 2)

  let a = parseArguments("window group", args, [ArgGroup, ArgTeleport])
  let winid = query.focusedWinid()
  let groupNo = a.group.get
  if groupNo == 0:
    raiseZephyrError("window group: group 0 is reserved VOID")
  groupTarget(publicGroupId(groupNo, groups.count(), "window group"),
    winid, groups.currentLiveId(), teleport = a.teleport)

proc group*(groupNo: int) =
  if groupNo == 0:
    raiseZephyrError("window group: group 0 is reserved VOID")
  groupTarget(publicGroupId(groupNo, groups.count(), "window group"),
    query.focusedWinid(), groups.currentLiveId())

proc group*(group: PublicGroupId) =
  groupTarget(group, query.focusedWinid(), groups.currentLiveId())

proc group*(groupname: string) =
  group(groups.publicId(groupname, "window group"))

proc group*(chain: WindowChain, groupname: string): WindowChain =
  groupTarget(groups.publicId(groupname, "window group"),
    chain.id, -1, some(chain.token))
  chain

proc group*(chain: WindowChain, groupNo: int): WindowChain =
  if groupNo == 0:
    raiseZephyrError("window group: group 0 is reserved VOID")
  groupTarget(publicGroupId(groupNo, groups.count(), "window group"),
    chain.id, -1, some(chain.token))
  chain

proc group*(chain: WindowChain, group: PublicGroupId): WindowChain =
  groupTarget(group, chain.id, -1, some(chain.token))
  chain

proc hide*(args: seq[string]) =
  requireArgs("window hide", args, 0, 1)

  var a = parseArguments(
    "window hide",
    args,
    [
      ArgWinid
    ]
  )

  if a.winid == "":
    a.winid = query.focusedWinid()

  if a.winid == "":
    return

  var group = -1
  let groupRoot = getEnv("GROUP")

  for g in 1 ..< groups.count():
    if dirExists(groupRoot / $g / a.winid):
      group = g
      break

  if group < 0:
    group = groups.currentLiveId()

  let targetClassname = query.classname(a.winid)

  ipc.hide(ipc.windowId(a.winid)).require()

  let hiddenPath = getEnv("HIDDEN") / a.winid
  removeDir(hiddenPath)
  createDir(hiddenPath / $group & ":" & targetClassname)

  focus("--last")


proc restore*(args: seq[string]) =
  requireArgs("window restore", args, 0, 1)

  var a = parseArguments(
    "window restore",
    args,
    [
      ArgWinid
    ]
  )

  if a.winid == "":
    a.winid = query.focusedWinid()

  if a.winid == "":
    return

  let token = query.tryClientToken(a.winid)
  if token.isNone:
    return
  if not hasGeometryForToken(a.winid, token.get):
    return

  let g = loadGeometryForToken(a.winid, token.get)
  let source = query.geometry(a.winid)
  applyGeometriesChecked(@[(a.winid, token.get, g)])
  saveGeometryWithToken(source, a.winid, token.get)

proc restore*(winid: string) =
  restore(@[winid])

proc shiftTarget(cardinal, winid: string, token = none(query.ClientToken)) =
  let focusedBefore = if token.isSome: query.focusedWinid() else: ""
  if token.isSome:
    WindowChain(id: winid, token: token.get).checkedChainTarget()
  let g = query.geometry(winid)
  var
    height = 0
    width = 0

  case cardinal
  of Up:
    height = -g.height
  of Down:
    height = g.height
  of Left:
    width = -g.width
  of Right:
    width = g.width

  if token.isSome:
    WindowChain(id: winid, token: token.get).checkedChainTarget()
  ipc.move(width, height, ipc.windowId(winid), relative = true)

  # Relative movement can first reset WM-owned special state, so its final
  # rectangle is not always derivable from the source rectangle alone.
  if token.isSome:
    WindowChain(id: winid, token: token.get).checkedChainTarget()
    saveGeometryForTarget(g, winid, token.get)
    WindowChain(id: winid, token: token.get).restoreChainFocus(focusedBefore)
  else:
    saveGeometry(g, winid)

proc shift*(args: seq[string]) =
  requireArgs("window shift", args, 1, 2)
  var a = parseArguments("window shift", args, [ArgCardinal, ArgWinid])
  if a.winid == "":
    a.winid = query.focusedWinid()
  shiftTarget(a.cardinal, a.winid)

proc shift*(chain: WindowChain, cardinal: string): WindowChain =
  let a = parseArguments("window shift", @[cardinal], [ArgCardinal])
  shiftTarget(a.cardinal, chain.id, some(chain.token))
  chain

proc rotate*(args: seq[string]) =
  requireArgs("window rotate", args, 0, 1)

  let a = parseArguments(
    "window rotate",
    args,
    [
      ArgWinid
    ]
  )

  let g = query.geometry(a.winid)

  let destination = Geometry(
    x: g.x,
    y: g.y,
    width: g.height,
    height: g.width
  )

  wtp(destination, a.winid)
  saveOriginalIfChanged(g, destination, a.winid)

proc snapTarget(args: seq[string], providedScreen: ScreenGeometry,
    targetOverride = "", token = none(query.ClientToken), restoreFocus = true) =
  requireArgs("window snap", args, 1, 3)

  let a = parseArguments(
    "window snap",
    args,
    [
      ArgDirection,
      ArgAxis,
      ArgWinid
    ]
  )

  if targetOverride.len > 0 and a.winid.len > 0 and
      a.winid.toLowerAscii() != targetOverride.toLowerAscii():
    raiseZephyrError("window chain: operation cannot replace its captured target")

  let winid = if targetOverride.len > 0: targetOverride
    elif a.winid.len > 0: a.winid
    else: query.focusedWinid()

  let focusedBefore = if token.isSome: query.focusedWinid() else: ""
  if token.isSome:
    WindowChain(id: winid, token: token.get).checkedChainTarget()
  let g = query.geometry(winid)
  let s =
    if providedScreen.width == 0:
      screenGeometry()
    else:
      providedScreen

  let right = s.width - g.width + s.margin
  let verticalCenter = (s.height - g.height) div 2 + s.top
  let halfGap = s.gap div 2

  proc oppositeSide(): int =
    s.width + s.margin * 2 - (g.x + g.width)

  proc move(x, y: int) =
    let destination = Geometry(
      x: x,
      y: y,
      width: g.width,
      height: g.height
    )

    if token.isSome:
      WindowChain(id: winid, token: token.get).checkedChainTarget()
    ipc.move(x, y, ipc.windowId(winid))
    if token.isSome:
      WindowChain(id: winid, token: token.get).checkedChainTarget()

    if destination == g:
      # A move can reset WM-owned special state even at unchanged coordinates.
      if token.isSome:
        saveGeometryForTarget(g, winid, token.get)
      else:
        saveGeometry(g, winid)
    else:
      if token.isSome:
        saveOriginalForTarget(g, destination, winid, token.get)
      else:
        saveOriginalIfChanged(g, destination, winid)

  proc moveLeft() =
    move(s.margin, g.y)

  proc moveRight() =
    move(right, g.y)

  proc near() =
    if g.x <= oppositeSide():
      moveLeft()
    else:
      moveRight()

  proc fail() =
    raiseZephyrError("window snap: invalid position: " & a.direction & " " & a.axis)

  if a.direction in [Left, Right, Near] and a.axis != "":
    fail()

  case a.direction
  of Left:
    moveLeft()

  of Right:
    moveRight()

  of "near":
    near()

  of Center:
    case a.axis
    of "":
      move((s.width - g.width) div 2 + s.margin, verticalCenter)
    of Left:
      move(s.width div 2 + s.margin - g.width - halfGap, g.y)
    of Right:
      move(s.width div 2 + s.margin + halfGap, g.y)
    of "horizontal":
      move((s.width - g.width) div 2 + s.margin, g.y)
    of "vertical":
      move(g.x, verticalCenter)

  of Top:
    case a.axis
    of "":
      move(g.x, s.top)
    of Left:
      move(s.margin, s.top)
    of Right:
      move(right, s.top)
    else:
      fail()

  of Bottom:
    let bottom = s.height - g.height + s.top

    case a.axis
    of "":
      move(g.x, bottom)
    of Left:
      move(s.margin, bottom)
    of Right:
      move(right, bottom)
    else:
      fail()

  if restoreFocus:
    focusTarget(winid, token)
  elif token.isSome:
    WindowChain(id: winid, token: token.get).restoreChainFocus(focusedBefore)

proc snap*(args: seq[string], providedScreen = ScreenGeometry()) =
  snapTarget(args, providedScreen)

proc snap*(chain: WindowChain, args: varargs[string]): WindowChain =
  let normalized = args.mapIt(it.toLowerAscii())
  snapTarget(normalized, ScreenGeometry(), chain.id, some(chain.token),
    restoreFocus = false)
  chain

proc snap*(position1, position2, winid: string) =
  snap(@[position1, position2, winid])

proc snap*(position, argument: string) =
  snap(@[position, argument])

proc snap*(position: string) =
  snap(@[position])

proc sizeTarget(args: seq[string], targetOverride = "",
    token = none(query.ClientToken)) =
  requireArgs("window size", args, 1, 4)

  var a = parseArguments(
    "window size",
    args,
    [
      ArgAspect,
      ArgPreset,
      ArgRotate,
      ArgSize,
      ArgZoom,
      ArgWinid
    ]
  )

  if targetOverride.len > 0 and a.winid.len > 0 and
      a.winid.toLowerAscii() != targetOverride.toLowerAscii():
    raiseZephyrError("window chain: operation cannot replace its captured target")

  let winid = if targetOverride.len > 0: targetOverride
    elif a.winid.len > 0: a.winid
    else: query.focusedWinid()

  let focusedBefore = if token.isSome: query.focusedWinid() else: ""
  if token.isSome:
    WindowChain(id: winid, token: token.get).checkedChainTarget()
  let g = query.geometry(winid)
  let s = screenGeometry()

  # proc fail(error: string) =
  #   raiseZephyrError("window size: " & error)

  proc applyGeometry(destination: Geometry) =
    wtpTarget(destination, winid, token)
    if token.isSome:
      saveOriginalForTarget(g, destination, winid, token.get)
    else:
      saveOriginalIfChanged(g, destination, winid)

  proc paperDimensions(name: string): array[2, int] =
    case name
    of A3: result = [1334, 1890]
    of B4: result = [1123, 1587]
    of A4: result = [945, 1334]
    of B5: result = [794, 1123]
    of A5: result = [665, 945]
    of B6: result = [559, 794]
    of A6: result = [472, 665]
    of B7: result = [397, 559]
    else:
      raiseZephyrError("unknown paper size " & name)

  proc paperArea(name: string): int =
    let size = paperDimensions(name)
    size[0] * size[1]

  proc paperSize(name: string, rotate = false) =
    var paper = paperDimensions(name)

    if rotate:
      swap(paper[0], paper[1])

    applyGeometry(Geometry(
      x: g.x,
      y: g.y,
      width: paper[0],
      height: paper[1]
    ))

  proc videoDimensions(name: string): array[2, int] =
    case name
    of "1080p": result = [1920, 1080]
    of "720p": result = [1280, 720]
    of "480p": result = [720, 480]
    else:
      raiseZephyrError("unknown video size " & name)

  proc videoArea(name: string): int =
    let size = videoDimensions(name)
    size[0] * size[1]

  proc videoSize(name: string, centerHorizontal = false, centerVertical = false) =
    let video = videoDimensions(name)
    let x =
      if centerHorizontal:
        (s.width - video[0]) div 2 + s.margin
      else:
        g.x
    let y =
      if centerVertical:
        (s.height - video[1]) div 2 + s.top
      else:
        g.y

    applyGeometry(Geometry(
      x: x,
      y: y,
      width: video[0],
      height: video[1]
    ))

  case args[0]
  of Viewport:
    if a.rotate or a.zoom != "":
      raiseZephyrError("viewport has no options")

    applyGeometry(Geometry(
      x: s.width div 4 + s.margin,
      y: s.top,
      width: s.width div 2,
      height: s.height
    ))

  # NOTE: Terminal is a special case requiring saving the revert geometry immediately
  of Terminal:
    if token.isSome:
      saveGeometryForTarget(g, winid, token.get, precheck = false)
    else:
      saveGeometry(g, winid, false)

    let t = loadGeometry(ClassTerm)

    wtpTarget(Geometry(
      x: g.x,
      y: g.y,
      width: t.width,
      height: t.height
    ), winid, token)

    if token.isNone:
      quit(0)
    WindowChain(id: winid, token: token.get).restoreChainFocus(focusedBefore)
    return

  of "paper", "video":
    if a.zoom == "":
      raiseZephyrError("missing --larger/--smaller zoom")

    let area = g.width * g.height

    case a.preset
    of "paper":
      var rotate = false
      let size =
        if g.height > g.width:  # portrait
          if a.zoom == "--larger":
            if area >= paperArea(B5): A4
            elif area >= paperArea(A5): B5
            elif area >= paperArea(B6): A5
            elif area >= paperArea(A6): B6
            elif area >= paperArea(B7): A6
            else: B7
          else:                 # "--smaller"
            if area <= paperArea(A6): B7
            elif area <= paperArea(B6): A6
            elif area <= paperArea(A5): B6
            elif area <= paperArea(B5): A5
            elif area <= paperArea(A4): B5
            else: A4
        else:                   # landscape
          rotate = true
          if a.zoom == "--larger":
            if area >= paperArea(B4): A3
            elif area >= paperArea(A4): B4
            elif area >= paperArea(B5): A4
            elif area >= paperArea(A5): B5
            elif area >= paperArea(B6): A5
            elif area >= paperArea(A6): B6
            elif area >= paperArea(B7): A6
            else: B7
          else:                 # "--smaller"
            if area <= paperArea(A6): B7
            elif area <= paperArea(B6): A6
            elif area <= paperArea(A5): B6
            elif area <= paperArea(B5): A5
            elif area <= paperArea(A4): B5
            elif area <= paperArea(B4): A4
            elif area <= paperArea(A3): B4
            else: A3

      paperSize(size, rotate)

    of "video":
      let size =
        if a.zoom == "--larger":
          if area >= videoArea("720p"): "1080p"
          elif area >= videoArea("480p"): "720p"
          else: "480p"
        else:         # "--smaller"
          if area <= videoArea("720p"): "480p"
          elif area <= videoArea("1080p"): "720p"
          else: "1080p"

      videoSize(size, centerVertical = true)

  of A3, B4, A4, B5, A5, B6, A6, B7:
    paperSize(
      a.preset,
      a.rotate
    )

  of "1080p", "720p", "480p":
    if a.rotate or a.zoom != "":
      raiseZephyrError("invalid option")

    videoSize(a.preset, centerHorizontal = true, centerVertical = true)

  else:
    if 'x' in args[0]:
      if a.rotate:
        swap(a.size.width, a.size.height)

      if a.size.height > s.height:
        swap(a.size.width, a.size.height)

      applyGeometry(Geometry(
        x: g.x,
        y: g.y,
        width: a.size.width,
        height: a.size.height
      ))

    elif ':' in args[0]:
      var width, height: int

      if a.aspect.width > a.aspect.height:
        width = g.width * a.aspect.width div a.aspect.height
        height = width * a.aspect.height div a.aspect.width
      else:
        height = g.height
        width = height * a.aspect.width div a.aspect.height

      applyGeometry(Geometry(
        x: g.x,
        y: g.y,
        width: width,
        height: height
      ))

    else:
      raiseZephyrError("undefined option")

  if token.isSome:
    WindowChain(id: winid, token: token.get).restoreChainFocus(focusedBefore)

proc size*(args: seq[string]) =
  sizeTarget(args)

proc size*(chain: WindowChain, args: varargs[string]): WindowChain =
  sizeTarget(@args, chain.id, some(chain.token))
  chain

proc size*(size, orientation: string) =
  size(@[size, orientation])

proc size*(size: string) =
  size(@[size])

proc applySpreadGridGeometry(columns, column, rows, row: int,
    g: Geometry, s: ScreenGeometry, winid: string,
    token: Option[query.ClientToken]) =
  let spreadWidth =
    (s.width - (columns - 1) * s.gap) div columns
  let spreadHeight =
    (s.height - (rows - 1) * s.gap) div rows
  let destination = Geometry(
    x: spreadWidth * (column - 1) + s.margin +
      (column - 1) * s.gap + (spreadWidth - g.width) div 2,
    y: spreadHeight * (row - 1) + s.top +
      (row - 1) * s.gap + (spreadHeight - g.height) div 2,
    width: g.width,
    height: g.height
  )
  wtpTarget(destination, winid, token)
  if token.isSome:
    saveOriginalForTarget(g, destination, winid, token.get)
  else:
    saveOriginalIfChanged(g, destination, winid)

proc spreadTarget(args: seq[string],
    providedScreen = ScreenGeometry(),
    providedGeometry = Geometry(), targetOverride = "",
    token = none(query.ClientToken)) =
  requireArgs("window spread", args, 1, 7)

  let a = parseArguments(
    "window spread",
    args,
    [
      ArgColumns,
      ArgColumn,
      ArgColumnName,
      ArgRows,
      ArgRow,
      ArgRowName,
      ArgWinid
    ]
  )

  let winid = validateChainArgumentTarget(a.winid, targetOverride,
    "window spread")
  let focusedBefore = if token.isSome: query.focusedWinid() else: ""
  if token.isSome:
    WindowChain(id: winid, token: token.get).checkedChainTarget()

  let rows = a.rows.get(1)

  let g =
    if providedGeometry.width == 0:
      query.geometry(winid)
    else:
      providedGeometry
  let s =
    if providedScreen.width == 0:
      screenGeometry()
    else:
      providedScreen

  # proc fail(error: string) =
  #   raiseZephyrError("window spread: " & error)

  if a.columns.isNone and a.column.isNone and a.columnName == "":
    raiseZephyrError("no column position specified")

  proc calculateColumns(): int =
      (s.width + s.gap) div (g.width + s.gap)

  proc centerColumn(columns: int): int =
    case getEnv("CENTER_BIAS", "right")
    of Left:
      result = (columns + 1) div 2
    of Right:
      result = (columns + 2) div 2
    else:
      raiseZephyrError("CENTER_BIAS expects left or right")

  proc resolveColumn(columns: int): int =
    if a.column.isSome:
      result = a.column.get
      if result > columns:
        raiseZephyrError("column must be <= " & $columns)
      return

    case a.columnName:
    of Left:
      result = 1
    of Right:
      result = columns
    of Center:
      result = centerColumn(columns)
    else:
      raiseZephyrError("column out of range")

    if result < 1 or result > columns:
      raiseZephyrError("column out of range")

  proc resolveRow(): int =
    if a.row.isSome:
      result = a.row.get
    else:
      case a.rowName:
      of "", Top:
        result = 1
      else:  # Bottom
        result = rows

    if result < 1 or result > rows:
      raiseZephyrError("row out of range")

    if s.height < rows * g.height + (rows - 1) * s.gap:
      raiseZephyrError("window exceeds row height")

  proc spreadGeometry(columns, column, row: int) =
    applySpreadGridGeometry(columns, column, rows, row, g, s, winid, token)

  case args[0]
  # spread left/right/center ...
  of Left, Right, Center:
    let columns = calculateColumns()
    let row = resolveRow()
    let column = resolveColumn(columns)
    spreadGeometry(columns, column, row)

  else:
    # spread column ... NOTE: one numeric operand means column of auto-sized grid
    if a.column.isNone and a.columnName == "":
      let column = a.columns.get
      if column < 1:
        raiseZephyrError("column must be >= 1")

      let columns = calculateColumns()
      let row = resolveRow()
      spreadGeometry(columns, column, row)

    # spread columns column/left/right/center ...
    else:
      if a.columns.isNone:
        raiseZephyrError("columns must be >= 1")
      let columns = a.columns.get

      if a.column.isSome and a.column.get > columns:
        raiseZephyrError("column must be <= " & $columns)

      if columns > calculateColumns():
        raiseZephyrError("window exceeds column width")

      let row = resolveRow()
      let column = resolveColumn(columns)
      spreadGeometry(columns, column, row)

  if token.isSome:
    WindowChain(id: winid, token: token.get).restoreChainFocus(focusedBefore)

proc spread*(
  args: seq[string],
  providedScreen = ScreenGeometry(),
  providedGeometry = Geometry()
) =
  spreadTarget(args, providedScreen, providedGeometry)

proc spread*(selector: string) =
  spread(@[selector])

proc spread*(chain: WindowChain, args: varargs[string]): WindowChain =
  spreadTarget(@args, ScreenGeometry(), Geometry(), chain.id, some(chain.token))
  chain

proc spreadGridTarget(columns, column, rows, row: int, targetOverride: string,
    providedScreen: ScreenGeometry, providedGeometry: Geometry,
    token = none(query.ClientToken)) =
  let winid = validateChainArgumentTarget("", targetOverride, "window spread")
  let focusedBefore = if token.isSome: query.focusedWinid() else: ""
  if token.isSome:
    WindowChain(id: winid, token: token.get).checkedChainTarget()
  let g =
    if providedGeometry.width == 0: query.geometry(winid)
    else: providedGeometry
  let s =
    if providedScreen.width == 0: screenGeometry()
    else: providedScreen
  let availableColumns = (s.width + s.gap) div (g.width + s.gap)
  if columns < 1:
    raiseZephyrError("window spread: columns must be >= 1")
  if column < 1 or column > columns:
    raiseZephyrError("window spread: column out of range")
  if columns > availableColumns:
    raiseZephyrError("window spread: window exceeds column width")
  if rows < 1:
    raiseZephyrError("window spread: rows must be >= 1")
  if row < 1 or row > rows:
    raiseZephyrError("window spread: row out of range")
  if s.height < rows * g.height + (rows - 1) * s.gap:
    raiseZephyrError("window spread: window exceeds row height")
  applySpreadGridGeometry(columns, column, rows, row, g, s, winid, token)
  if token.isSome:
    WindowChain(id: winid, token: token.get).restoreChainFocus(focusedBefore)

proc spreadGrid*(columns, column, rows, row: int, winid = "",
    providedScreen = ScreenGeometry(), providedGeometry = Geometry()) =
  spreadGridTarget(columns, column, rows, row, winid,
    providedScreen, providedGeometry)

proc swap*(args: seq[string]) =
  requireArgs("window swap", args, 1)

  # proc fail(error: string) =
  #   raiseZephyrError("window swap: " & error)

  let a = parseArguments(
    "window swap",
    args,
    [
      ArgCardinal
    ]
  )

  if a.cardinal == "":
    raiseZephyrError("missing cardinal direction")

  let source = query.focusedWinid()
  let sourceGeometry = query.geometry(source)

  let direction = case a.cardinal.toLowerAscii()
    of "up", "north": ipc.North
    of "right", "east": ipc.East
    of "down", "south": ipc.South
    of "left", "west": ipc.West
    else: raiseZephyrError("window swap: invalid direction")
  ipc.focusCardinal(direction)

  let target = query.focusedWinid()

  if target == source:
    raiseZephyrError("no adjacent window")

  let targetGeometry = query.geometry(target)

  wtp(targetGeometry, source)
  wtp(sourceGeometry, target)

  saveGeometry(sourceGeometry, source)
  saveGeometry(targetGeometry, target)

proc await*(args: seq[string]) =
  requireArgs("window await", args, 1, 2)

  proc fail(error: string) =
    raiseZephyrError("window await: " & error)

  let a = parseArguments(
    "window await",
    args,
    [
      ArgClassname,
      ArgDelay,
      ArgName
    ]
  )

  # `--name PATTERN` occupies two CLI arguments but is itself the await
  # selector; do not treat it as the legacy two-parameter form.
  if args.len == 2 and a.name == "":
    if a.delay != -1.0 or a.classname != "":
      raiseZephyrError("multiple parameters not allowed")

  elif a.delay > 0.0:
    sleep((a.delay * 1000).int)

  elif a.classname != "":
    let reply = waitForClass(a.classname)
    if not reply.ok:
      fail(reply.error)
    let winids = reply.body.splitLines().filterIt(it.len > 0)
    if winids.len == 0:
      raiseZephyrError("could not sync " & a.classname)
    if winids.len > 1:
      raiseZephyrError("indeterminate window")
    if ipc.focus(ipc.windowId(winids[0])).status != 0:
      raiseZephyrError("could not focus " & winids[0])

  elif a.name != "":
    let reply = waitForName(a.name)
    if not reply.ok:
      if reply.code == ErrorTimeout:
        raiseZephyrError("could not sync --name " & a.name)
      raiseZephyrError("window await: " & reply.error)
    let winids = reply.body.splitLines().filterIt(it.len > 0)
    if winids.len == 0:
      raiseZephyrError("could not sync --name " & a.name)
    if winids.len > 1:
      raiseZephyrError("indeterminate window")
    discard ipc.focus(ipc.windowId(winids[0])).status

proc await*(selector, property: string) =
  await(@[selector, property])

proc await*(selector: string) =
  await(@[selector])

proc applyTileGridGeometry(columns, rows, column, row: int,
    g: Geometry, s: ScreenGeometry, winid: string,
    token: Option[query.ClientToken])

proc tileTarget(args: seq[string],
    providedScreen = ScreenGeometry(),
    providedGeometry = Geometry(), targetOverride = "",
    token = none(query.ClientToken)) =
  requireArgs("window tile", args, 1, 7)

  let a = parseArguments(
    "window tile",
    args,
    [
      ArgColumns,
      ArgColumn,
      ArgColumnName,
      ArgRows,
      ArgRow,
      ArgWinid
    ]
  )

  let winid = validateChainArgumentTarget(a.winid, targetOverride,
    "window tile")
  let focusedBefore = if token.isSome: query.focusedWinid() else: ""
  if token.isSome:
    WindowChain(id: winid, token: token.get).checkedChainTarget()

  let rows = a.rows.get(1)
  let row = a.row.get(1)

  let g =
    if providedGeometry.width == 0:
      query.geometry(winid)
    else:
      providedGeometry
  let s =
    if providedScreen.width == 0:
      screenGeometry()
    else:
      providedScreen

  # proc fail(error: string) =
  #   raiseZephyrError("window tile: " & error)

  proc applyGeometry(destination: Geometry) =
    wtpTarget(destination, winid, token)
    if token.isSome:
      saveOriginalForTarget(g, destination, winid, token.get)
    else:
      saveOriginalIfChanged(g, destination, winid)

  case args[0]
  of Left:
    applyGeometry(Geometry(
      x: s.margin,
      y: s.top,
      width: g.x + g.width - s.margin,
      height: s.height
    ))

  of Right:
    applyGeometry(Geometry(
    x: g.x,
    y: s.top,
    width: s.width - g.x + s.margin,
    height: s.height
    ))

  else:
    # unused columnName check
    if a.columnName == Center:
      raiseZephyrError("invalid column")

    if a.columns.isNone:
      raiseZephyrError("columns must be >= 1")
    let columns = a.columns.get
    let column = a.column.get(columns)
    applyTileGridGeometry(columns, rows, column, row, g, s, winid, token)

  if token.isSome:
    WindowChain(id: winid, token: token.get).restoreChainFocus(focusedBefore)

proc tile*(
  args: seq[string],
  providedScreen = ScreenGeometry(),
  providedGeometry = Geometry()
) =
  tileTarget(args, providedScreen, providedGeometry)

proc tile*(chain: WindowChain, args: varargs[string]): WindowChain =
  tileTarget(@args, ScreenGeometry(), Geometry(), chain.id, some(chain.token))
  chain

proc applyTileGridGeometry(columns, rows, column, row: int,
    g: Geometry, s: ScreenGeometry, winid: string,
    token: Option[query.ClientToken]) =
  if columns < 1:
    raiseZephyrError("window tile: columns must be >= 1")
  if column < 1 or column > columns:
    raiseZephyrError("window tile: column out of range")
  if rows < 1:
    raiseZephyrError("window tile: rows must be >= 1")
  if row < 1 or row > rows:
    raiseZephyrError("window tile: row out of range")
  let tileWidth = (s.width - (columns - 1) * s.gap) div columns
  let tileHeight = (s.height - (rows - 1) * s.gap) div rows
  let destination = Geometry(
    x: tileWidth * (column - 1) + s.margin + (column - 1) * s.gap,
    y: tileHeight * (row - 1) + s.top + (row - 1) * s.gap,
    width: tileWidth,
    height: tileHeight
  )
  wtpTarget(destination, winid, token)
  if token.isSome:
    saveOriginalForTarget(g, destination, winid, token.get)
  else:
    saveOriginalIfChanged(g, destination, winid)

proc tileGridTarget(columns, rows, column, row: int, targetOverride: string,
    providedScreen: ScreenGeometry, providedGeometry: Geometry,
    token = none(query.ClientToken)) =
  let winid = validateChainArgumentTarget("", targetOverride, "window tile")
  let focusedBefore = if token.isSome: query.focusedWinid() else: ""
  if token.isSome:
    WindowChain(id: winid, token: token.get).checkedChainTarget()
  let g =
    if providedGeometry.width == 0: query.geometry(winid)
    else: providedGeometry
  let s =
    if providedScreen.width == 0: screenGeometry()
    else: providedScreen
  applyTileGridGeometry(columns, rows, column, row, g, s, winid, token)
  if token.isSome:
    WindowChain(id: winid, token: token.get).restoreChainFocus(focusedBefore)

proc tileGrid*(columns, rows, column, row: int, winid = "",
    providedScreen = ScreenGeometry(), providedGeometry = Geometry()) =
  tileGridTarget(columns, rows, column, row, winid,
    providedScreen, providedGeometry)

proc tile*(columns, position: string) =
  tile(@[columns, position])

proc tile*(side: string) =
  tile(@[side])

proc toggle*(args: seq[string]) =
  requireArgs("window toggle", args, 1, 2)

  let a = parseArguments(
    "window toggle",
    args,
    [
      ArgClassname,
      ArgName,
    ]
  )

  let winids =
    if a.classname != "":
      ipc.ids(all = true, selector = ipc.ClassSelector, pattern = a.classname)
    else:
      ipc.ids(all = true, selector = ipc.NameSelector, pattern = a.name)

  if winids == "":
    quit(1)

  for winid in winids.splitLines():
    let retcode =
      ipc.hide(ipc.windowId(winid)).status

    if retcode != 0:
      ipc.focus(ipc.windowId(winid)).require()

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
  of "layer":
    layer(rest)
  of "geometry":
    geometry(rest)
  of "wm-group":
    wmGroup(rest)
  of "wm-groups":
    wmGroups(rest)
  of "snapshot":
    snapshot(rest)
  of "group":
    group(rest)
  of "hide":
    hide(rest)
  of "ids":
    echo ids(rest)
  of "move":
    move(rest)
  of "stack":
    echo stack(rest)
  of "restore":
    restore(rest)
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
  of "tile":
    tile(rest)
  of "swap":
    swap(rest)
  of "await":
    await(rest)
  of "toggle":
    toggle(rest)
  else:
    raiseZephyrError("unknown window action: " & verb)
