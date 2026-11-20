## Synchronous command API for cirrus' existing ipc.h protocol.
## The standalone sirocco client remains independent. No command-line parsing.
import std/[algorithm, exitprocs, strutils]
import x11_snapshot
import layer_types
import ../zephyr_errors

type
  WindowId* = distinct uint32
  Direction* = enum North, East, South, West
  Selector* = enum NoSelector, ClassSelector, NameSelector
  Reply* = object
    status*: int
    output*, error*: string
  # Explicit values mirror cirrus/ipc.h, not the public CLI grammar.
  Command = enum
    Activate = 0, Deactivate = 1, ClearGroup = 2, CardinalFocus = 3,
    Focus = 6, FocusLast = 7, Focused = 12, Ids = 13,
    Geometry = 16, Move = 17, Resize = 18, Close = 21, Hide = 22,
    StackCycle = 24,
    GroupAdd = 25, GroupRemove = 26, Stack = 27, GroupCurrent = 28,
    Snapshot = 31, StackGeometries = 32, ApplyGeometries = 33,
    RaiseMany = 34, ApplyChecked = 35, GroupCount = 36, SetLayer = 38

# Process-owned, synchronous session. Not thread-safe or reentrant: callers must
# serialize operations (as the current CLI/daemon event loops do).
var transport: X11SnapshotQuery

proc close*() = transport.close()
addExitProc(close)

proc connected(): bool =
  transport.isOpen() or transport.open()

proc windowId*(value: string): WindowId =
  if value.len == 0:
    raiseZephyrError("cirrus IPC: invalid winid " & value)
  if value.len < 3 or value.len > 10 or not value.startsWith("0x") or
      value[2 .. ^1].find(AllChars - HexDigits) >= 0:
    raiseZephyrError("cirrus IPC: invalid winid " & value)
  let parsed = parseHexInt(value).uint32
  if parsed == 0: raiseZephyrError("cirrus IPC: invalid winid " & value)
  WindowId(parsed)

proc explicitWireWindowId(target: WindowId): uint32 =
  result = target.uint32
  if result == 0:
    raiseZephyrError("cirrus IPC: invalid explicit winid 0x00000000")

proc focusedWireWindowId(): uint32 =
  ## Cirrus' protocol reserves zero to select its currently focused client.
  0'u32

proc require*(reply: Reply): string {.discardable.} =
  if reply.status != 0: raiseZephyrError("cirrus IPC: " & reply.error)
  reply.output

proc request(command: Command, arg1 = 0'u32, arg2 = 0'u32,
    arg3 = 0'u32, body = "", groupNo = 0'u32): Reply =
  result.status = 1
  if not connected():
    result.error = transport.lastFailure
    return
  var response: string
  if not transport.tryRequest(command.uint32, arg1, arg2, arg3, body,
      response, groupNo = groupNo):
    result.error = transport.lastFailure
    return
  if response.startsWith("ERROR "):
    result.error = response[6 .. ^1]
    return
  let valid = case command
    of Activate, Deactivate, Hide, StackCycle, SetLayer, RaiseMany, ApplyGeometries, ApplyChecked:
      response == "OK"
    of GroupCurrent, GroupCount:
      response.startsWith("OK ") and response.len > 3 and
        response[3 .. ^1].find(AllChars - Digits) < 0
    of Focused:
      response.startsWith("OK 0x") and response.len == 13 and
        response[5 .. ^1].find(AllChars - HexDigits) < 0
    of Ids, Stack, StackGeometries:
      response == "OK" or response.startsWith("OK\n")
    of Geometry:
      response.startsWith("OK\n") and response.len > 3
    of Snapshot:
      response.startsWith("OK\nSNAPSHOT 1\n") or response.startsWith("OK\nSNAPSHOT 2\n")
    else: false
  if not valid:
    result.error = "malformed WM response"
    transport.close()
    return
  result.status = 0
  if response.len > 3: result.output = response[3 .. ^1].strip()

proc send(command: Command, args: array[4, uint32]): Reply =
  result.status = 1
  if not connected() or not transport.trySend(command.uint32, args):
    result.error = transport.lastFailure
    return
  # These legacy commands acknowledge X submission only, not WM application.
  result.status = 0

proc focused*(): string = request(Focused).require()
proc snapshot*(): Reply = request(Snapshot, 0, 1)
proc groupCurrent*(): string = request(GroupCurrent).require()
proc groupCount*(): string = request(GroupCount).require()

proc targetRequest(command: Command, target: WindowId, value = 0'u32): Reply =
  request(command, 1'u32, explicitWireWindowId(target), value)

proc focusedTargetRequest(command: Command, value = 0'u32): Reply =
  request(command, 0'u32, focusedWireWindowId(), value)

proc geometry*(): string =
  focusedTargetRequest(Geometry).require()
proc geometry*(target: WindowId): string =
  targetRequest(Geometry, target).require()
proc stackGeometries*(): string =
  focusedTargetRequest(StackGeometries).require()
proc stackGeometries*(target: WindowId): string =
  targetRequest(StackGeometries, target).require()
proc stack*(): string =
  focusedTargetRequest(Stack).require()
proc stack*(target: WindowId): string =
  targetRequest(Stack, target).require()
proc stackCycle*(target: WindowId) =
  targetRequest(StackCycle, target).require()
proc hide*(target: WindowId): Reply = targetRequest(Hide, target)
proc hide*(): Reply = focusedTargetRequest(Hide)

proc layerWireValue*(layer: Layer): uint32 =
  ## Explicit mapping to cirrus' LayerNormal/LayerAbove/LayerOverlay values.
  case layer
  of Normal: 0'u32
  of Above: 1'u32
  of Overlay: 2'u32

proc layer*(target: WindowId, layer: Layer) =
  targetRequest(SetLayer, target, layer.layerWireValue).require()
proc layer*(layer: Layer) =
  focusedTargetRequest(SetLayer, layer.layerWireValue).require()
proc focus*(target: WindowId): Reply =
  send(Focus, [explicitWireWindowId(target), 0, 0, 0])
proc focusLast*() = send(FocusLast, [0'u32, 0, 0, 0]).require()
proc focusCardinal*(direction: Direction) =
  send(CardinalFocus, [direction.uint32, 0, 0, 0]).require()
proc closeWindow*(target: WindowId) =
  send(Close, [explicitWireWindowId(target), 0, 0, 0]).require()
proc closeWindow*() =
  send(Close, [focusedWireWindowId(), 0, 0, 0]).require()

proc coordinate(value: int): uint32 =
  if value < low(int32).int or value > high(int32).int:
    raiseZephyrError("cirrus IPC: coordinate outside int32 range")
  cast[uint32](value.int32)
proc move*(x, y: int, target: WindowId, relative = false) =
  send(Move, [uint32(not relative), coordinate(x), coordinate(y),
    explicitWireWindowId(target)]).require()
proc move*(x, y: int, relative = false) =
  send(Move, [uint32(not relative), coordinate(x), coordinate(y),
    focusedWireWindowId()]).require()
proc resize*(width, height: int, target: WindowId, relative = false) =
  if not relative and (width < 0 or height < 0):
    raiseZephyrError("cirrus IPC: malformed dimensions")
  send(Resize, [uint32(not relative), coordinate(width), coordinate(height),
    explicitWireWindowId(target)]).require()
proc resize*(width, height: int, relative = false) =
  if not relative and (width < 0 or height < 0):
    raiseZephyrError("cirrus IPC: malformed dimensions")
  send(Resize, [uint32(not relative), coordinate(width), coordinate(height),
    focusedWireWindowId()]).require()
proc activateGroup*(group: int) = request(Activate, group.uint32).require()
proc deactivateGroup*(group: int) = request(Deactivate, group.uint32).require()
proc clearGroup*(group: int) = send(ClearGroup, [group.uint32, 0, 0, 0]).require()
proc addToGroup*(group: int, target: WindowId) =
  send(GroupAdd, [group.uint32, explicitWireWindowId(target), 0, 0]).require()
proc addToGroup*(group: int) =
  send(GroupAdd, [group.uint32, focusedWireWindowId(), 0, 0]).require()
proc removeFromGroup*(target: WindowId) =
  send(GroupRemove, [explicitWireWindowId(target), 0, 0, 0]).require()
proc removeFromGroup*() =
  send(GroupRemove, [focusedWireWindowId(), 0, 0, 0]).require()

proc ids*(all = false, selector = NoSelector, pattern = "", groupNo = 0): string =
  var atom: uint32
  if selector != NoSelector:
    if not connected() or not transport.atom(pattern, atom):
      transport.close()
      raiseZephyrError("cirrus IPC: unable to intern selector")
  let body = request(Ids, atom, uint32(all), selector.uint32,
    groupNo = groupNo.uint32).require()
  if body.len == 0: return ""
  var ids = body.splitLines()
  for id in ids:
    if id.len != 10: raiseZephyrError("cirrus IPC: malformed ID response")
    discard windowId(id)
  ids.sort()
  ids.join("\n")

proc raiseMany*(targets: seq[WindowId]) =
  if targets.len == 0: return
  var body: string
  for target in targets:
    body.add("0x" & toHex(explicitWireWindowId(target), 8).toLowerAscii() & "\n")
  request(RaiseMany, body = body).require()
proc applyGeometries*(body: string) = request(ApplyGeometries, body = body).require()
proc applyGeometriesChecked*(body: string) = request(ApplyChecked, body = body).require()
proc rootDimensions*(): tuple[width, height: int] =
  if not connected() or not transport.tryRootGeometry(result.width, result.height):
    let reason = transport.lastFailure
    transport.close()
    raiseZephyrError("cirrus IPC: root geometry: " & reason)
