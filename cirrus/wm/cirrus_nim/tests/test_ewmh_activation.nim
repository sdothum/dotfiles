import std/[unittest, options, sequtils]
import ../model/[types, state, lifecycle]

let epoch = ProcessEpoch(hi: 0x6d2c'u64, lo: 2'u64)

proc addClient(state: var WmState; xid: uint32; mapped = true;
              decoration = none(WindowId)): ClientState =
  result = state.addAdoptedClient(epoch, WindowId(xid), mapped,
      RawGroup(1), wsvNormal).state
  result.decoration = decoration
  discard state.replaceClient(result)

suite "Stage 6D-2C-2 pure _NET_ACTIVE_WINDOW transitions":
  test "mapped managed activation changes focus history and emits ordered focus and raise effects":
    var state = newWmState()
    let a = state.addClient(0xa01, decoration = some(WindowId(0xa11)))
    let b = state.addClient(0xa02)
    discard state.transition(epoch, WmInput(kind: wiFocusClient, clientId: b.id))
    let activation = state.transition(epoch, WmInput(
        kind: wiEwmhActiveWindow, window: a.window))
    check activation.hasClient
    check state.focusedId == some(a.id)
    check state.focusOrderClients()[0].id == a.id
    check activation.effects.mapIt(it.kind) == @[
      weMapDecoration, weMapClient, wePaintDecoration, weSetInputFocus, wePublishActiveWindow,
      wePublishCurrentDesktop, weRaiseClient]
    check activation.effects[^1].decoration == WindowId(0xa11)
    check activation.effects[^1].activationRaise
    check activation.effects.allIt(it.ignoreFailure)
    check activation.effects.filterIt(it.kind != weRaiseClient).allIt(not it.activationRaise)
    let ordinaryFocus = state.transition(epoch, WmInput(
        kind: wiFocusClient, clientId: b.id))
    check ordinaryFocus.effects.filterIt(it.kind == weRaiseClient).allIt(
        not it.activationRaise)

  test "confirmed-unmapped activation requests mapping without confirming it":
    var state = newWmState()
    let a = state.addClient(0xa21, mapped = false,
        decoration = some(WindowId(0xa31)))
    let activation = state.transition(epoch, WmInput(
        kind: wiEwmhActiveWindow, window: a.window))
    check activation.hasClient
    check state.focusedId == some(a.id)
    check not state.lookup(a.id).get.mapped
    check activation.effects.mapIt(it.kind) == @[
      weMapDecoration, weMapClient, weSetInputFocus, wePublishActiveWindow,
      wePublishCurrentDesktop, weRaiseClient]
    let confirmed = state.transition(epoch, WmInput(kind: wiMapConfirmed,
        window: a.window))
    check confirmed.client.mapped
    check confirmed.effects.mapIt(it.kind).contains(weRaiseClient)

  test "unknown and post-cleanup targets produce no effects or focus change":
    var state = newWmState()
    let a = state.addClient(0xa41)
    let unknown = state.transition(epoch, WmInput(
        kind: wiEwmhActiveWindow, window: WindowId(0xdead)))
    check unknown.effects.len == 0
    check state.focusedId.isNone
    discard state.transition(epoch, WmInput(kind: wiDestroyConfirmed,
        window: a.window))
    let removed = state.transition(epoch, WmInput(
        kind: wiEwmhActiveWindow, window: a.window))
    check removed.effects.len == 0
    check state.focusedId.isNone

  test "stale managed record and reused raw XID retain managed identity lookup":
    var state = newWmState()
    let original = state.addClient(0xa51)
    let activation = state.transition(epoch, WmInput(
        kind: wiEwmhActiveWindow, window: original.window))
    check activation.hasClient
    check activation.client.id == original.id
    check activation.client.token == original.token
    check activation.effects.anyIt(it.window == original.window)
