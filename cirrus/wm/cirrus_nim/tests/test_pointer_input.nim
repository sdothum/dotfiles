import std/[unittest, options, sequtils]
import ../model/[types, state, lifecycle, pointer]

let epoch = ProcessEpoch(hi: 0x6d2d'u64, lo: 1'u64)

proc addClient(state: var WmState; xid: uint32): ClientState =
  state.addAdoptedClient(epoch, WindowId(xid), true, RawGroup(1),
      wsvNormal, x = 100, y = 100, width = 200, height = 120).state

suite "Stage 6D pointer protocol model":
  test "runtime lock masks expand in frozen-C order for click and Mod4 grabs":
    check modifierVariants(0, [16'u16, 2'u16, 0'u16]) == @[0'u16, 18, 16, 2]
    check modifierVariants(64, [16'u16, 2'u16, 0'u16]) == @[64'u16, 82, 80, 66]
    let plan = buttonGrabPlan(64, [16'u16, 2'u16, 0'u16])
    check plan.len == 24
    check plan[0].button == 1 and plan[0].modifiers == 0
    check plan[4].button == 1 and plan[4].modifiers == 64
    check plan[8].button == 2 and plan[8].modifiers == 0
    check plan[^1].button == 3 and plan[^1].modifiers == 66

  test "missing CapsLock mapping uses the X11 Lock modifier fallback":
    check normalizeLockMasks([16'u16, 0, 0], 2) == [16'u16, 2, 0]
    check normalizeLockMasks([16'u16, 4, 0], 2) == [16'u16, 4, 0]

  test "alternative and overlapping runtime lock masks retain source expansion order":
    check modifierVariants(64, [4'u16, 8'u16, 0'u16]) == @[64'u16, 76, 68, 72]
    # Frozen C emits duplicates when two keysyms share a modifier assignment.
    check modifierVariants(64, [16'u16, 16'u16, 0'u16]) == @[64'u16, 80, 80, 80]

  test "unmodified ButtonPress emits focus, raises, reinstalls grabs, then replays":
    var state = newWmState()
    state.setPointerModifiers(64, 16, 2, 0)
    let a = state.addClient(0x901)
    let press = state.transition(epoch, WmInput(kind: wiButtonPress,
        window: a.window, pointerButton: 1, pointerX: 130, pointerY: 120,
        pointerLockMasks: [16'u16, 2, 0], pointerTime: 77))
    check state.focusedClient.get.id == a.id
    check press.effects.mapIt(it.kind) == @[
      weRaiseClient, weMapClient, weSetInputFocus, wePublishActiveWindow,
      wePublishCurrentDesktop, weInstallButtonGrabs, weRaiseClient,
      weAllowPointer]
    check press.effects[^1].pointerAllowMode == pamReplayPointer

  test "Mod4 starts model-owned MOVE and release ungrabs then thaws pointer":
    var state = newWmState()
    state.setPointerModifiers(64, 16, 2, 0)
    let a = state.addClient(0x911)
    let press = state.transition(epoch, WmInput(kind: wiButtonPress,
        window: a.window, pointerButton: 1, pointerState: 64,
        pointerX: 150, pointerY: 150, pointerTime: 80,
        pointerLockMasks: [16'u16, 2, 0]))
    check state.pointerInteraction.operation == poMove
    check press.effects.mapIt(it.kind) == @[weRaiseClient, weGrabPointer]
    let move = state.transition(epoch, WmInput(kind: wiPointerMotion,
        pointerX: 175, pointerY: 165))
    check move.client.geometry.x == 125
    check move.client.geometry.y == 115
    check move.effects.anyIt(it.kind == weMoveClient)
    let release = state.transition(epoch, WmInput(kind: wiButtonRelease,
        pointerTime: 90))
    check state.pointerInteraction.operation == poNone
    check release.effects.mapIt(it.kind) == @[weUngrabPointer, weAllowPointer]

  test "middle and right Mod4 actions select distinct resize modes":
    var state = newWmState()
    state.setPointerModifiers(64, 16, 2, 0)
    let a = state.addClient(0x921)
    discard state.transition(epoch, WmInput(kind: wiButtonPress,
        window: a.window, pointerButton: 2, pointerState: 64,
        pointerX: 110, pointerY: 110, pointerLockMasks: [16'u16, 2, 0]))
    check state.pointerInteraction.operation == poResizeSide
    discard state.transition(epoch, WmInput(kind: wiButtonRelease))
    discard state.transition(epoch, WmInput(kind: wiButtonPress,
        window: a.window, pointerButton: 3, pointerState: 64,
        pointerX: 110, pointerY: 110, pointerLockMasks: [16'u16, 2, 0]))
    check state.pointerInteraction.operation == poResizeCorner

  test "frozen-C special zoom targets are raised but do not start pointer tracking":
    var state = newWmState()
    state.setPointerModifiers(64, 16, 2, 0)
    var a = state.addClient(0x931)
    a.maxed = true
    discard state.replaceClient(a)
    let press = state.transition(epoch, WmInput(kind: wiButtonPress,
        window: a.window, pointerButton: 1, pointerState: 64,
        pointerX: 110, pointerY: 110, pointerTime: 91,
        pointerLockMasks: [16'u16, 2, 0]))
    check state.pointerInteraction.operation == poNone
    check press.effects.mapIt(it.kind) == @[weRaiseClient, weAllowPointer]
    check press.effects[0].decoration == WindowId(0)
    check press.effects[1].pointerAllowMode == pamSyncPointer

  test "unknown target still thaws the passive synchronous grab":
    var state = newWmState()
    let press = state.transition(epoch, WmInput(kind: wiButtonPress,
        window: WindowId(0xdead), pointerButton: 1, pointerTime: 2))
    check not press.hasClient
    check press.effects.mapIt(it.kind) == @[weAllowPointer]
    check press.effects[0].pointerAllowMode == pamSyncPointer
