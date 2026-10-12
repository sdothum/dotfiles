import std/[unittest, options, sequtils]
import ../model/[types, state, lifecycle]
import ../model/geometry

proc addClient(state: var WmState; xid: uint32;
              decoration = none(WindowId)): ClientState =
  result = state.addAdoptedClient(ProcessEpoch(hi: 1, lo: 1), WindowId(xid),
      true, RawGroup(1), wsvNormal).state
  result.decoration = decoration
  result.geometry = Geometry(x: 40, y: 50, width: 120, height: 80)
  discard state.replaceClient(result)

suite "Stage 1C decoration focus and lifecycle contract":
  test "focus paints target before focus request and old client after publication":
    var state = newWmState()
    let a = state.addClient(0xa01, decoration = some(WindowId(0xa11)))
    let b = state.addClient(0xa02, decoration = some(WindowId(0xa12)))
    let epoch = ProcessEpoch(hi: 1, lo: 1)
    discard state.transition(epoch, WmInput(kind: wiFocusClient, clientId: a.id))
    let changed = state.transition(epoch, WmInput(kind: wiEwmhActiveWindow, window: b.window))
    let kinds = changed.effects.mapIt(it.kind)
    let paints = changed.effects.filterIt(it.kind == wePaintDecoration)
    check paints.len == 2
    check paints[0].window == b.window
    check paints[0].outerColor == 0xff97a293'u32
    check paints[1].window == a.window
    check paints[1].outerColor == 0xff393638'u32
    check kinds.find(wePaintDecoration) < kinds.find(weSetInputFocus)
    check changed.effects.find(paints[1]) > kinds.find(wePublishActiveWindow)
    let repeated = state.transition(epoch, WmInput(kind: wiEwmhActiveWindow, window: b.window))
    check repeated.effects.filterIt(it.kind == wePaintDecoration).len == 1
    let reversed = state.transition(epoch, WmInput(kind: wiEwmhActiveWindow, window: a.window))
    check reversed.effects.filterIt(it.kind == wePaintDecoration).mapIt(it.outerColor) ==
        @[0xff97a293'u32, 0xff393638'u32]

  test "resize keeps unfocused painting and absent decoration emits no paint":
    var state = newWmState()
    let a = state.addClient(0xa01, decoration = some(WindowId(0xa11)))
    let b = state.addClient(0xa02)
    let epoch = ProcessEpoch(hi: 1, lo: 1)
    let resized = state.transition(epoch, WmInput(kind: wiResizeAbsolute,
        window: a.window, width: 160, height: 110,
        geometryBounds: GeometryBounds(width: 1280, height: 900)))
    let paints = resized.effects.filterIt(it.kind == wePaintDecoration)
    check paints.len == 1
    check paints[0].outerColor == 0xff393638'u32
    check paints[0].geometry.width == 160
    check paints[0].geometry.height == 110
    let focused = state.transition(epoch, WmInput(kind: wiFocusClient, clientId: b.id))
    check focused.effects.filterIt(it.kind == wePaintDecoration).len == 0
