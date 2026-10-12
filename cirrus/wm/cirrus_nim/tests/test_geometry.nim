import std/[unittest, sequtils, options]
import ../model/[types, state, lifecycle, geometry]
import ../x11/configure_values

let epoch = ProcessEpoch(hi: 0x111'u64, lo: 0x222'u64)
let screen = GeometryBounds(x: 0, y: 0, width: 1280, height: 900,
    borderExtent: 0, gapLeft: 12, gapRight: 18, gapTop: 7, gapBottom: 9)

proc addClient(state: var WmState; geometry: Geometry;
               hints = ResizeHints()): ClientState =
  result = state.addAdoptedClient(epoch, WindowId(0x800001), true,
      RawGroup(1), wsvNormal, int16(geometry.x), int16(geometry.y),
      uint16(geometry.width), uint16(geometry.height), hints = hints).state

suite "Stage 5 geometry arithmetic and transitions":
  test "decoration derivation and clipped frame geometry":
    let client = Geometry(x: 0, y: 0, width: 270, height: 180)
    let frame = fitDecoration(decorationGeometry(client, 5),
        GeometryBounds(x: 0, y: 0, width: 1280, height: 900))
    check frame == Geometry(x: 0, y: 0, width: 285, height: 195)

  test "mathematical decoration geometry remains signed before clipping":
    let derived = decorationGeometry(Geometry(x: 3000, y: -36,
        width: 120, height: 80), 5)
    check derived == Geometry(x: 2995, y: -41, width: 130, height: 90)
    check decorationClipWouldFailC(derived,
        GeometryBounds(x: 0, y: 0, width: 1024, height: 768))
    check fitDecoration(derived,
        GeometryBounds(x: 0, y: 0, width: 1024, height: 768)) ==
        Geometry(x: 2995, y: 0, width: 0, height: 131)

  test "fully offscreen right decoration emits no corrupt configure effect":
    var state = newWmState()
    let client = state.addClient(Geometry(x: 40, y: 50, width: 120, height: 80))
    discard state.transition(epoch, WmInput(kind: wiCompleteStartupClient,
        window: client.window, decoration: WindowId(0x900001), x: 40, y: 50,
        width: 120, height: 80))
    let moved = state.transition(epoch, WmInput(kind: wiMoveTo,
        window: client.window, x: 3000, y: -36,
        geometryBounds: GeometryBounds(x: 0, y: 0, width: 1024, height: 768)))
    check moved.client.geometry == Geometry(x: 3000, y: -36, width: 120, height: 80)
    check weConfigureDecoration notin moved.effects.mapIt(it.kind)

  test "ConfigureWindow packing follows ascending mask-bit order":
    let xOnly = packGeometryValues(1, -1, -2, 120, 80)
    check xOnly.mask == 1 and xOnly.count == 1 and xOnly.values[0] == 0xffff'u32
    let yOnly = packGeometryValues(2, -1, -2, 120, 80)
    check yOnly.count == 1 and yOnly.values[0] == 0xfffe'u32
    let widthOnly = packGeometryValues(4, -1, -2, 120, 80)
    check widthOnly.count == 1 and widthOnly.values[0] == 120
    let heightOnly = packGeometryValues(8, -1, -2, 120, 80)
    check heightOnly.count == 1 and heightOnly.values[0] == 80
    let position = packGeometryValues(3, -100, -36, 120, 80)
    check position.count == 2 and position.values[0] == 0xff9c'u32 and
        position.values[1] == 0xffdc'u32
    let complete = packGeometryValues(15, -5, 10, 130, 90)
    check complete.mask == 15 and complete.count == 4
    check complete.values == [0xfffb'u32, 10'u32, 130'u32, 90'u32]
    let configure = packConfigureRequestValues(0x7f'u16, -2, 5, 120, 80, 7,
        0x12345678'u32, 4)
    check configure == [0xfffe'u32, 5'u32, 120'u32, 80'u32, 7'u32,
        0x12345678'u32, 4'u32]
    let sparse = packConfigureRequestValues((1'u16 shl 5) or (1'u16 shl 6),
        -2, 5, 120, 80, 7, 0x12345678'u32, 3)
    check sparse[0 .. 1] == [0x12345678'u32, 3'u32]
    check sparse[2 .. ^1] == [0'u32, 0, 0, 0, 0]
    let lowerLimit = packGeometryValues(3, -32768, -32768, 1, 1)
    check lowerLimit.values[0] == 0x8000'u32 and lowerLimit.values[1] == 0x8000'u32
    expect ValueError:
      discard packGeometryValues(4, 0, 0, 65536, 1)

  test "ordinary fit clamps edges and oversized sizes":
    let hints = ResizeHints()
    check fitConfigure(Geometry(x: -25, y: -4, width: 270, height: 180),
        hints, GeometryBounds(x: 0, y: 0, width: 1280, height: 900)) ==
        Geometry(x: 0, y: 0, width: 270, height: 180)
    check fitConfigure(Geometry(x: 100, y: 100, width: 1500, height: 1000),
        hints, GeometryBounds(x: 0, y: 0, width: 1280, height: 900)) ==
        Geometry(x: 0, y: 0, width: 1280, height: 900)
    check fitConfigure(Geometry(x: 1200, y: 850, width: 200, height: 100),
        hints, GeometryBounds(x: 0, y: 0, width: 1280, height: 900)) ==
        Geometry(x: 1080, y: 800, width: 200, height: 100)

  test "relative resize clamps minimum before increment rounding":
    let hints = ResizeHints(minWidth: 165, minHeight: 45,
        widthIncrement: 10, heightIncrement: 10)
    check resizeRelative(Geometry(width: 160, height: 50), hints, 0, 0, true) ==
        Geometry(width: 160, height: 50)
    check resizeRelative(Geometry(width: 160, height: 50), hints, -4, 0, true) ==
        Geometry(width: 160, height: 50) # 165 clamps, then floors to 160.
    check resizeRelative(Geometry(width: 160, height: 50), hints, 37, -6, true) ==
        Geometry(width: 190, height: 40)
    check resizeRelative(Geometry(width: 160, height: 50), hints, 37, -6, false) ==
        Geometry(width: 197, height: 45)

  test "absolute resize bypasses increments and direct move stays offscreen":
    var state = newWmState()
    let client = state.addClient(Geometry(x: 20, y: 30, width: 160, height: 50),
        ResizeHints(minWidth: 150, minHeight: 40, widthIncrement: 10,
                    heightIncrement: 10))
    let absolute = state.transition(epoch, WmInput(kind: wiResizeAbsolute,
        window: client.window, width: 177, height: 47, geometryBounds: screen))
    check absolute.client.geometry == Geometry(x: 20, y: 30, width: 177, height: 47)
    let moved = state.transition(epoch, WmInput(kind: wiMoveTo,
        window: client.window, x: -120, y: 1000, geometryBounds: screen))
    check moved.client.geometry.x == -120 and moved.client.geometry.y == 1000

  test "H, V, full, monocle and reset overwrite orig geometry per C":
    var state = newWmState()
    let initial = Geometry(x: 90, y: 70, width: 400, height: 250)
    let client = state.addClient(initial)
    let h = state.transition(epoch, WmInput(kind: wiMaximizeHorizontal,
        window: client.window, geometryBounds: screen))
    check h.client.geometry == Geometry(x: 12, y: 70, width: 1250, height: 250)
    check h.client.origGeometry == initial and h.client.hmaxed
    check weSetInputFocus in h.effects.mapIt(it.kind)
    check weRaiseClient in h.effects.mapIt(it.kind)
    let v = state.transition(epoch, WmInput(kind: wiMaximizeVertical,
        window: client.window, geometryBounds: screen))
    check v.client.geometry == Geometry(x: 90, y: 7, width: 400, height: 884)
    check v.client.origGeometry == initial and v.client.vmaxed and not v.client.hmaxed
    let full = state.transition(epoch, WmInput(kind: wiMaximizeFull,
        window: client.window, geometryBounds: screen))
    check full.client.geometry == Geometry(x: 0, y: 0, width: 1280, height: 900)
    check full.client.origGeometry == initial and full.client.maxed
    check weSetInputFocus in full.effects.mapIt(it.kind)
    check weRestackLayers in full.effects.mapIt(it.kind)
    let restored = state.transition(epoch, WmInput(kind: wiResetGeometry,
        window: client.window, geometryBounds: screen))
    check restored.client.geometry == initial
    check not restored.client.maxed and not restored.client.hmaxed and
        not restored.client.vmaxed and not restored.client.monocled
    check restored.effects.mapIt(it.kind).find(weRestackLayers) <
        restored.effects.mapIt(it.kind).find(weSetInputFocus)
    check weRaiseClient in restored.effects.mapIt(it.kind)
    check state.transition(epoch, WmInput(kind: wiResetGeometry,
        window: client.window, geometryBounds: screen)).effects.len == 0
    let monocle = state.transition(epoch, WmInput(kind: wiMonocle,
        window: client.window, geometryBounds: screen))
    check monocle.client.geometry == Geometry(x: 12, y: 7, width: 1250, height: 884)
    let ordinaryReset = state.transition(epoch, WmInput(kind: wiResetGeometry,
        window: client.window, geometryBounds: screen))
    check ordinaryReset.client.geometry == initial

  test "ConfigureRequest respects masks then fits; hint records are setup state":
    var state = newWmState()
    let hints = ResizeHints(minWidth: 100, minHeight: 50,
        widthIncrement: 10, heightIncrement: 10)
    let client = state.addClient(Geometry(x: 80, y: 90, width: 200, height: 100), hints)
    discard state.transition(epoch, WmInput(kind: wiCompleteStartupClient,
        window: client.window, decoration: WindowId(0x900001), x: 80, y: 90,
        width: 200, height: 100))
    let changed = state.transition(epoch, WmInput(kind: wiConfigureRequest,
        window: client.window, x: -10, y: 890, width: 300, height: 200,
        configureMask: ConfigureMask(x: true, y: true, height: true), geometryBounds: screen))
    check changed.client.geometry == Geometry(x: 0, y: 700, width: 200, height: 200)
    check changed.client.resizeHints.widthIncrement == 10
    check changed.effects.mapIt(it.kind) == @[weMoveClient, weResizeClient,
        weConfigureDecoration, wePaintDecoration, wePublishStatus]

  test "ConfigureRequest keeps stack modes before geometry and drops managed sibling":
    for mode in 0'u8 .. 4'u8:
      var state = newWmState()
      var client = state.addClient(Geometry(x: 80, y: 90, width: 200, height: 100),
          ResizeHints(minWidth: 100, minHeight: 50))
      client.decoration = some(WindowId(0x900001))
      discard state.replaceClient(client)
      let request = state.transition(epoch, WmInput(kind: wiConfigureRequest,
          window: client.window, x: 120, y: 140, width: 80, height: 40,
          configureMask: ConfigureMask(x: true, width: true, height: true),
          configureValueMask: (1'u16 shl 5) or (1'u16 shl 6),
          configureSibling: WindowId(0x800002), configureStackMode: mode,
          geometryBounds: screen))
      check request.effects.mapIt(it.kind) == @[weConfigureRequest,
          weMoveClient, weResizeClient, weConfigureDecoration, wePaintDecoration, wePublishStatus]
      check request.effects[0].configureValueMask == (1'u16 shl 6)
      check request.effects[0].configureStackMode == mode
      check request.effects[0].configureSibling.raw == 0'u32
      check request.client.geometry == Geometry(x: 120, y: client.geometry.y,
          width: 100, height: 50)

  test "ConfigureRequest geometry-only has no stack effect and unmanaged path preserves sibling":
    var state = newWmState()
    let managed = state.addClient(Geometry(x: 80, y: 90, width: 200, height: 100))
    let geometryOnly = state.transition(epoch, WmInput(kind: wiConfigureRequest,
        window: managed.window, x: 100, configureMask: ConfigureMask(x: true),
        configureValueMask: 1'u16, geometryBounds: screen))
    check geometryOnly.effects[0].kind == weMoveClient
    check weConfigureRequest notin geometryOnly.effects.mapIt(it.kind)

    let unmanaged = state.transition(epoch, WmInput(kind: wiConfigureRequest,
        window: WindowId(0x800099), x: -4, y: 8, width: 50, height: 40,
        configureValueMask: 0x7f'u16,
        configureSibling: WindowId(0x800077), configureStackMode: 2,
        configureBorderWidth: 9))
    check not unmanaged.hasClient
    check unmanaged.effects.len == 1
    check unmanaged.effects[0].kind == weConfigureRequest
    check unmanaged.effects[0].configureValueMask == 0x6f'u16
    check unmanaged.effects[0].configureSibling == WindowId(0x800077)
    check unmanaged.effects[0].configureStackMode == 2

  test "ConfigureRequest preserves C full-screen fit promotion from monocle":
    var state = newWmState()
    var client = state.addClient(Geometry(x: 40, y: 50, width: 120, height: 80))
    client.origGeometry = Geometry(x: 40, y: 50, width: 120, height: 80)
    client.geometry = Geometry(x: screen.x, y: screen.y,
        width: uint32(screen.width), height: uint32(screen.height))
    client.monocled = true
    discard state.replaceClient(client)
    let changed = state.transition(epoch, WmInput(kind: wiConfigureRequest,
        window: client.window, configureValueMask: 1'u16 shl 6,
        configureStackMode: 0, geometryBounds: screen))
    check changed.client.maxed
    check not changed.client.monocled
    check changed.client.origGeometry == Geometry(x: screen.x, y: screen.y,
        width: uint32(screen.width), height: uint32(screen.height))
    check changed.effects.mapIt(it.kind).find(weConfigureRequest) == 0
    check weRestackLayers in changed.effects.mapIt(it.kind)
    let reset = state.transition(epoch, WmInput(kind: wiResetGeometry,
        window: client.window, geometryBounds: screen))
    check reset.client.geometry == changed.client.origGeometry

  test "startup completion preserves the setup-time hint cache":
    var state = newWmState()
    let hints = ResizeHints(minWidth: 90, minHeight: 60,
        widthIncrement: 10, heightIncrement: 8)
    let client = state.addAdoptedClient(epoch, WindowId(0x800001), true,
        RawGroup(1), wsvNormal, 20, 30, 200, 100, hints = hints).state
    let completed = state.transition(epoch, WmInput(kind: wiCompleteStartupClient,
        window: client.window, decoration: WindowId(0x900001),
        x: 20, y: 30, width: 200, height: 100, hints: hints))
    check completed.client.token == client.token
    check completed.client.geometry == Geometry(x: 20, y: 30, width: 200, height: 100)
    check completed.client.resizeHints == hints

  test "ConfigureRequest clears independent H/V flags before fitting":
    var state = newWmState()
    let client = state.addClient(Geometry(x: 90, y: 70, width: 400, height: 250))
    discard state.transition(epoch, WmInput(kind: wiMaximizeHorizontal,
        window: client.window, geometryBounds: screen))
    let request = state.transition(epoch, WmInput(kind: wiConfigureRequest,
        window: client.window, configureMask: ConfigureMask(x: true),
        x: 200, geometryBounds: screen))
    check not request.client.hmaxed and not request.client.vmaxed
