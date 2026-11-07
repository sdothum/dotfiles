import std/[unittest, options]
import model/[types, state, lifecycle, geometry]
import x11/[decoration, bindings]

{.compile: "support/c_border_oracle.c".}
proc referencePaint(style, mask, percent: uint32; bw, gap: int32;
    w, h, outer, inner: uint32) {.importc: "reference_paint", cdecl.}
proc resetMock() {.importc: "border_mock_reset", cdecl.}
proc fills(): cint {.importc: "border_mock_fills", cdecl.}
proc count(i: cint): uint32 {.importc: "border_mock_rect_count", cdecl.}
proc rx(i,j: cint): int16 {.importc: "border_mock_x", cdecl.}
proc ry(i,j: cint): int16 {.importc: "border_mock_y", cdecl.}
proc rw(i,j: cint): uint16 {.importc: "border_mock_width", cdecl.}
proc rh(i,j: cint): uint16 {.importc: "border_mock_height", cdecl.}
proc red(i: cint): uint16 {.importc: "border_mock_red", cdecl.}
proc green(i: cint): uint16 {.importc: "border_mock_green", cdecl.}
proc blue(i: cint): uint16 {.importc: "border_mock_blue", cdecl.}
proc alpha(i: cint): uint16 {.importc: "border_mock_alpha", cdecl.}

let epoch = ProcessEpoch(hi:7,lo:9)
let bounds = GeometryBounds(width:1024,height:768)
# External numbers are the explicitly requested Aurora-facing contract.
# Internal tags retain the inspected C renderer's established dispatch.
const internal = [0'u32,1,2,4,3,5]
const expectedFrame = [
  Geometry(x:150,y:170,width:180,height:120),
  Geometry(x:150,y:180,width:10,height:100),
  Geometry(x:160,y:170,width:160,height:10),
  Geometry(x:320,y:180,width:10,height:100),
  Geometry(x:160,y:280,width:160,height:10),
  Geometry(x:150,y:170,width:180,height:120)]
proc config(wm: var WmState; key,value: uint32): PrivateCommandResult =
  wm.applyPrivateCommand(epoch,PrivateSemanticInput(opcode:10,
      words:[key,value,0'u32,0'u32],observations:WmInput(geometryBounds:bounds)))
proc snapshot(): seq[int] =
  for i in 0.cint..<fills():
    result.add([int(red(i)),int(green(i)),int(blue(i)),int(alpha(i)),int(count(i))])
    for j in 0.cint..<cint(count(i)):
      result.add([int(rx(i,j)),int(ry(i,j)),int(rw(i,j)),int(rh(i,j))])
proc checkPaint(wm: WmState; e: WmEffect; style: uint32): bool =
  let focused = wm.focusedClient
  let isFocused = focused.isSome and focused.get.window.raw == e.window.raw
  if e.borderStyle != internal[style] or e.cornerMask != 1 or e.cornerPercent != 0 or
      e.outerBorderWidth != 6 or e.innerBorderWidth != 4: return false
  if e.outerColor != (if isFocused:wm.config.outerColorFocused else:wm.config.outerColorUnfocused): return false
  if e.innerColor != (if isFocused:wm.config.innerColorFocused else:wm.config.innerColorUnfocused): return false
  resetMock()
  referencePaint(internal[style],1,0,6,4,160,100,e.outerColor,e.innerColor)
  let reference = snapshot()
  resetMock()
  paintDecoration(cast[ptr XcbConnection](1),e.decoration.raw,3,
      e.geometry.width,e.geometry.height,e.outerColor,e.innerColor,e.borderStyle,
      e.cornerMask,e.cornerPercent,e.outerBorderWidth,e.innerBorderWidth)
  snapshot() == reference

suite "public border-style numbers and stable internal geometry":
  for style in 0'u32..5'u32:
    test "public numeric style " & $style:
      var wm = newWmState()
      for kv in [(1'u32,style),(2'u32,6'u32),(15'u32,4'u32),
          (6'u32,1'u32),(7'u32,0'u32)]: discard wm.config(kv[0],kv[1])
      check wm.config.borderStyle == internal[style]
      for i in 0..1:
        discard wm.addAdoptedClient(epoch,WindowId(0x100+i),true,RawGroup(1),wsvNormal,160,180,160,100)
        let initial = wm.transition(epoch,WmInput(kind:wiCompleteStartupClient,
            window:WindowId(0x100+i),decoration:WindowId(0x200+i),
            x:160,y:180,width:160,height:100))
        var sawFrame,sawPaint: bool
        for e in initial.effects:
          if e.kind == weCreateDecoration:
            sawFrame = true
            check Geometry(x:int32(e.x),y:int32(e.y),width:uint32(e.width),height:uint32(e.height)) == expectedFrame[style]
          if e.kind == wePaintDecoration:
            sawPaint = true
            check wm.checkPaint(e,style)
        check sawFrame and sawPaint
      for i in 0..5:
        let focused = wm.transition(epoch,WmInput(kind:wiFocusClient,window:WindowId(0x100+i mod 2)))
        var paints = 0
        for e in focused.effects:
          if e.kind == wePaintDecoration:
            inc paints
            check wm.checkPaint(e,style)
        check paints > 0
      # Reapplying a number is idempotent; each request translates the input,
      # rather than swapping the already stored internal tag.
      for repeat in 0..1:
        let refreshed = wm.config(1,style)
        check wm.config.borderStyle == internal[style]
        var frames,paints: int
        for e in refreshed.transition.effects:
          if e.kind == weConfigureDecoration:
            inc frames
            check e.geometry == expectedFrame[style]
          if e.kind == wePaintDecoration:
            inc paints
            check wm.checkPaint(e,style)
        check frames == 2 and paints == 2

  test "runtime changes across every public style and invalid-value fallback":
    var wm = newWmState()
    discard wm.addAdoptedClient(epoch,WindowId(0x100),true,RawGroup(1),wsvNormal,160,180,160,100)
    discard wm.transition(epoch,WmInput(kind:wiCompleteStartupClient,window:WindowId(0x100),
        decoration:WindowId(0x200),x:160,y:180,width:160,height:100))
    wm.config.outerBorderWidth = 6
    wm.config.innerBorderWidth = 4
    for style in [0'u32,1,2,3,4,5,4,3,3,4]:
      discard wm.config(1,style)
      check wm.config.borderStyle == internal[style]
      check decorationGeometry(wm.lookup(WindowId(0x100)).get.geometry,wm.config) == expectedFrame[style]
      discard wm.transition(epoch,WmInput(kind:wiFocusClient,window:WindowId(0x100)))
    for value in [6'u32,99,high(uint32)]:
      discard wm.config(1,value)
      check wm.config.borderStyle == value
      check decorationGeometry(wm.lookup(WindowId(0x100)).get.geometry,wm.config) == expectedFrame[0]
