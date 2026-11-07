import std/[unittest, options]
import model/[types, state, lifecycle, geometry]
import x11/[decoration, bindings]

{.compile: "support/c_border_oracle.c".}
proc referenceGeometry(style: uint32; bw, gap, x, y: int32; w, h: uint32;
    clip: cint; output: ptr uint32) {.importc: "reference_geometry", cdecl.}
proc referencePaint(style, mask, percent: uint32; bw, gap: int32;
    w, h, outer, inner: uint32) {.importc: "reference_paint", cdecl.}
proc resetMock() {.importc: "border_mock_reset", cdecl.}
proc fills(): cint {.importc: "border_mock_fills", cdecl.}
proc rectCount(i: cint): uint32 {.importc: "border_mock_rect_count", cdecl.}
proc rectX(i, j: cint): int16 {.importc: "border_mock_x", cdecl.}
proc rectY(i, j: cint): int16 {.importc: "border_mock_y", cdecl.}
proc rectWidth(i, j: cint): uint16 {.importc: "border_mock_width", cdecl.}
proc rectHeight(i, j: cint): uint16 {.importc: "border_mock_height", cdecl.}
proc red(i: cint): uint16 {.importc: "border_mock_red", cdecl.}
proc green(i: cint): uint16 {.importc: "border_mock_green", cdecl.}
proc blue(i: cint): uint16 {.importc: "border_mock_blue", cdecl.}
proc alpha(i: cint): uint16 {.importc: "border_mock_alpha", cdecl.}

type FillPlan = tuple[color: array[4, uint16], rects: seq[array[4, int]]]
let epoch = ProcessEpoch(hi: 7, lo: 8)
let bounds = GeometryBounds(width: 1024, height: 768)
proc snapshot(): seq[FillPlan] =
  for i in 0.cint..<fills():
    var fill = (color: [red(i), green(i), blue(i), alpha(i)], rects: newSeq[array[4, int]]())
    for j in 0.cint..<cint(rectCount(i)):
      fill.rects.add([int(rectX(i,j)), int(rectY(i,j)), int(rectWidth(i,j)), int(rectHeight(i,j))])
    result.add(fill)
proc expected(g: Geometry; config: WmConfiguration; clip = false): Geometry =
  var raw: array[4, uint32]
  referenceGeometry(config.borderStyle, config.outerBorderWidth,
      config.innerBorderWidth, g.x, g.y, g.width, g.height, cint(clip), addr raw[0])
  Geometry(x: cast[int32](raw[0]), y: cast[int32](raw[1]), width: raw[2], height: raw[3])
proc config(wm: var WmState; key, value: uint32): PrivateCommandResult =
  wm.applyPrivateCommand(epoch, PrivateSemanticInput(opcode: 10,
      words: [key,value,0'u32,0'u32], observations: WmInput(geometryBounds: bounds)))
proc inspectEffects(wm: WmState; effects: seq[WmEffect]): tuple[frames, paints: int, valid: bool] =
  result.valid = true
  template verify(condition: untyped) =
    if not condition: result.valid = false
    check condition
  for e in effects:
    if e.kind notin {weCreateDecoration, weConfigureDecoration, weApplyEwmhGeometry, wePaintDecoration}: continue
    let client = wm.lookup(e.window).get
    case e.kind
    of weCreateDecoration:
      inc result.frames
      verify Geometry(x: int32(e.x), y: int32(e.y), width: uint32(e.width), height: uint32(e.height)) == expected(client.geometry, wm.config)
    of weConfigureDecoration:
      inc result.frames
      verify e.geometry == expected(client.geometry, wm.config, true)
    of weApplyEwmhGeometry:
      if e.decoration.raw != 0:
        inc result.frames
        verify e.frameGeometry == expected(e.geometry, wm.config, true)
    of wePaintDecoration:
      inc result.paints
      verify e.geometry == client.geometry
      let focused = wm.focusedId.isSome and wm.focusedId.get == client.id
      verify e.outerColor == (if focused: wm.config.outerColorFocused else: wm.config.outerColorUnfocused)
      verify e.innerColor == (if focused: wm.config.innerColorFocused else: wm.config.innerColorUnfocused)
      resetMock()
      referencePaint(wm.config.borderStyle, wm.config.cornerMask, wm.config.cornerPercent,
          wm.config.outerBorderWidth, wm.config.innerBorderWidth,
          client.geometry.width, client.geometry.height, e.outerColor, e.innerColor)
      let c = snapshot()
      resetMock()
      paintDecoration(cast[ptr XcbConnection](1), e.decoration.raw, 3,
          e.geometry.width, e.geometry.height, e.outerColor, e.innerColor,
          e.borderStyle, e.cornerMask, e.cornerPercent, e.outerBorderWidth, e.innerBorderWidth)
      verify snapshot() == c
    else: discard

template checkEffects(wm, effects: untyped): untyped =
  block:
    let observed = inspectEffects(wm, effects)
    check observed.valid
    (frames: observed.frames, paints: observed.paints)

suite "C-compatible spine frame placement and paint":
  for style in 0'u32..5'u32:
    test "initial/runtime/focus/move/resize/EWMH style " & $style:
      for settings in [(0'u32,1'u32), (35'u32,10'u32), (100'u32,0'u32)]:
        var wm = newWmState()
        for kv in [(1'u32,style),(2'u32,6'u32),(15'u32,4'u32),
            (7'u32,settings[0]),(6'u32,settings[1]),(4'u32,0xff123456'u32),
            (5'u32,0xffabcdef'u32),(16'u32,0x80765432'u32),(17'u32,0x80443322'u32)]:
          discard wm.config(kv[0],kv[1])
        # Pre-existing startup client, then a newly mapped client.
        discard wm.addAdoptedClient(epoch, WindowId(0x100), true, RawGroup(1), wsvNormal,
            160,180,160,100)
        let startup = wm.transition(epoch, WmInput(kind: wiCompleteStartupClient,
            window: WindowId(0x100), decoration: WindowId(0x200), x:160,y:180,width:160,height:100))
        check checkEffects(wm,startup.effects) == (1,1)
        let managed = wm.transition(epoch, WmInput(kind: wiManageRequested,
            window: WindowId(0x101), decoration: WindowId(0x201), initialGroup: RawGroup(1),
            x: 440,y:300,width:200,height:120, geometryBounds:bounds))
        check checkEffects(wm,managed.effects).frames == 1
        let mapped = wm.transition(epoch,WmInput(kind:wiMapConfirmed,window:WindowId(0x101)))
        check checkEffects(wm,mapped.effects).paints > 0
        # Aurora's configuration IPC path, including style changes on live clients.
        for runtimeStyle in [5'u32,0'u32,style]:
          let refreshed = wm.config(1,runtimeStyle)
          check checkEffects(wm,refreshed.transition.effects) == (2,2)
        for i in 0..3:
          let focused = wm.transition(epoch,WmInput(kind:wiFocusClient,window:WindowId(0x100+i mod 2)))
          check checkEffects(wm,focused.effects).paints > 0
        for input in [WmInput(kind:wiMoveTo,x:220,y:240),
                      WmInput(kind:wiResizeAbsolute,width:180,height:110)]:
          var request = input
          request.window = WindowId(0x100)
          request.geometryBounds = bounds
          let changed = wm.transition(epoch,request)
          check checkEffects(wm,changed.effects) == (1,1)
        let maxed = wm.transition(epoch,WmInput(kind:wiEwmhWmState,window:WindowId(0x100),
            ewmhAction:1,ewmhStates:[(if wm.config.borderStyle == 4: esaMaximizedVert else: esaMaximizedHorz),esaUnknown],ewmhFormat:32,
            ewmhWindowExists:true,geometryBounds:bounds))
        check checkEffects(wm,maxed.effects).frames > 0
        let restored = wm.transition(epoch,WmInput(kind:wiEwmhWmState,window:WindowId(0x100),
            ewmhAction:0,ewmhStates:[(if wm.config.borderStyle == 4: esaMaximizedVert else: esaMaximizedHorz),esaUnknown],ewmhFormat:32,
            ewmhWindowExists:true,geometryBounds:bounds))
        check checkEffects(wm,restored.effects).frames > 0

  test "spines ignore corner length and mask and preserve C clipping":
    for style in 1'u32..4'u32:
      var wm = newWmState()
      for kv in [(1'u32,style),(2'u32,6'u32),(15'u32,4'u32)]: discard wm.config(kv[0],kv[1])
      let g = Geometry(x:160,y:180,width:160,height:100)
      let frame = expected(g,wm.config)
      case style
      of 1: check frame == Geometry(x:150,y:180,width:10,height:100)
      of 2: check frame == Geometry(x:160,y:170,width:160,height:10)
      of 3: check frame == Geometry(x:320,y:180,width:10,height:100)
      of 4: check frame == Geometry(x:160,y:280,width:160,height:10)
      else: discard
      resetMock()
      referencePaint(style,1,0,6,4,160,100,0xff123456'u32,0x80765432'u32)
      let full = snapshot()
      resetMock()
      referencePaint(style,0,100,6,4,160,100,0xff123456'u32,0x80765432'u32)
      check snapshot() == full
      for width in [0'u32,4'u32]:
        discard wm.config(15,width)
        discard wm.addAdoptedClient(epoch,WindowId(0x100+width),true,RawGroup(1),wsvNormal,160,180,160,100)
        discard wm.transition(epoch,WmInput(kind:wiCompleteStartupClient,window:WindowId(0x100+width),
            decoration:WindowId(0x200+width),x:160,y:180,width:160,height:100))
        let moved = wm.transition(epoch,WmInput(kind:wiMoveTo,window:WindowId(0x100+width),
            x:2,y:2,geometryBounds:bounds))
        check checkEffects(wm,moved.effects) == (1,1)
