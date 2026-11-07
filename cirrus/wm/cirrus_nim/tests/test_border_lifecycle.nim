import std/unittest
import model/[types, state, lifecycle]
import x11/[decoration, bindings]

{.compile: "support/border_raster.c".}
proc resetRaster() {.importc: "reset_raster", cdecl.}
proc leftRows(): cint {.importc: "left_rows", cdecl.}
proc countPixels(): cint {.importc: "count_pixels", cdecl.}
proc cPaint(style, mask, percent: uint32) {.importc: "c_paint", cdecl.}

let epoch = ProcessEpoch(hi: 1, lo: 1)
proc config(wm: var WmState; key, value: uint32): PrivateCommandResult =
  wm.applyPrivateCommand(epoch, PrivateSemanticInput(opcode: 10,
      words: [key, value, 0'u32, 0'u32]))
proc paints(effects: seq[WmEffect]): seq[WmEffect] =
  for e in effects:
    if e.kind == wePaintDecoration: result.add(e)
proc render(e: WmEffect): tuple[left, pixels: int] =
  paintDecoration(cast[ptr XcbConnection](1), e.decoration.raw, 3,
      e.geometry.width, e.geometry.height, e.outerColor, e.innerColor,
      e.borderStyle, e.cornerMask, e.cornerPercent,
      e.outerBorderWidth, e.innerBorderWidth)
  (int(leftRows()), int(countPixels()))
proc checkParameters(e: WmEffect; config: WmConfiguration; focused: bool) =
  check e.borderStyle == config.borderStyle
  check e.cornerMask == config.cornerMask
  check e.cornerPercent == config.cornerPercent
  check e.outerBorderWidth == config.outerBorderWidth
  check e.innerBorderWidth == config.innerBorderWidth
  check e.outerColor == (if focused: config.outerColorFocused else: config.outerColorUnfocused)
  check e.innerColor == (if focused: config.innerColorFocused else: config.innerColorUnfocused)

suite "configured lifecycle borders match C and runtime refresh":
  for values in [(5'u32, 1'u32, 0'u32), (0'u32, 1'u32, 0'u32),
                 (5'u32, 10'u32, 28'u32), (5'u32, 4'u32, 35'u32)]:
    test "style/mask/percent " & $values:
      let (style, mask, percent) = values
      var wm = newWmState()
      for kv in [(1'u32, style), (2'u32, 6'u32), (15'u32, 4'u32),
          (6'u32, mask), (7'u32, percent), (4'u32, 0xffff0000'u32),
          (5'u32, 0xff00ff00'u32), (16'u32, 0'u32), (17'u32, 0'u32)]:
        discard wm.config(kv[0], kv[1])
      resetRaster()
      cPaint(style, mask, percent)
      let expected = (int(leftRows()), int(countPixels()))
      resetRaster()
      for i in 0..1:
        let window = WindowId(0x100+i)
        discard wm.addAdoptedClient(epoch, window, true, RawGroup(1), wsvNormal,
            160, 180, 160, 100)
        let initial = paints(wm.transition(epoch, WmInput(kind: wiCompleteStartupClient,
            window: window, decoration: WindowId(0x200+i),
            x: 160, y: 180, width: 160, height: 100)).effects)
        require initial.len == 1
        checkParameters(initial[0], wm.config, false)
        check render(initial[0]) == expected
        let firstMap = paints(wm.transition(epoch,
            WmInput(kind: wiMapConfirmed, window: window)).effects)
        require firstMap.len > 0
        for e in firstMap:
          checkParameters(e, wm.config, e.window.raw == window.raw)
          check render(e) == expected
      for i in 0..5:
        let target = WindowId(0x100+i mod 2)
        let focused = paints(wm.transition(epoch,
            WmInput(kind: wiFocusClient, window: target)).effects)
        require focused.len > 0
        let refreshed = paints(wm.config(7, percent).transition.effects)
        for e in focused:
          checkParameters(e, wm.config, e.window.raw == target.raw)
          check render(e) == expected
          var found = false
          for r in refreshed:
            if r.window.raw == e.window.raw:
              found = true
              check r == e
          check found
      if percent == 0:
        check expected[0] == (if style == 5: 110 else: 120)
        check expected[0] != 20

  test "configured inner focus colors and signed widths retain their meaning":
    var wm = newWmState()
    discard wm.addAdoptedClient(epoch, WindowId(0x100), true, RawGroup(1),
        wsvNormal, 160, 180, 160, 100)
    discard wm.transition(epoch, WmInput(kind: wiCompleteStartupClient,
        window: WindowId(0x100), decoration: WindowId(0x200),
        x: 160, y: 180, width: 160, height: 100))
    discard wm.config(16, 0x80112233'u32)
    discard wm.config(17, 0x40445566'u32)
    discard wm.config(2, 0xfffffff0'u32)
    let focused = paints(wm.transition(epoch,
        WmInput(kind: wiFocusClient, window: WindowId(0x100))).effects)
    require focused.len == 1
    checkParameters(focused[0], wm.config, true)
    check focused[0].outerBorderWidth == -16
    let unfocused = paints(wm.transition(epoch, WmInput(kind: wiClearFocus)).effects)
    require unfocused.len == 1
    checkParameters(unfocused[0], wm.config, false)
