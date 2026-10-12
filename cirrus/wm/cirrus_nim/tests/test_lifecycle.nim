import std/[unittest, options, sequtils]
import ../model/[types, state, lifecycle]

suite "runtime lifecycle model transitions":
  let epoch = ProcessEpoch(hi: 0x1234'u64, lo: 0x5678'u64)
  let client = WindowId(0x100'u32)
  let decoration = WindowId(0x101'u32)
  let group = RawGroup(1)

  test "manage allocates once, prepends order, and emits ordered effects unmapped":
    var state = newWmState()
    let request = WmInput(kind: wiManageRequested, window: client,
        decoration: decoration, initialGroup: group,
        x: 40, y: 50, width: 120, height: 80)
    let first = state.transition(epoch, request)
    check first.created
    check first.client.mapped == false
    check first.client.group == group
    check first.client.decoration == some(decoration)
    check first.effects.mapIt(it.kind) == @[
      weSelectClientEvents, weAddToSaveSet, wePublishDesktop,
      wePublishDesktop, wePublishActiveGroups, wePublishStatus,
      weMapClient, weCreateDecoration, weMapDecoration,
      wePublishWmStateNormal, weCenterPointerOnClient, wePublishClientLists]
    let duplicate = state.transition(epoch, request)
    check not duplicate.created
    check duplicate.client.token == first.client.token
    check state.identityCount == 1
    check state.clientsInManagedOrder()[0].window == client

  test "only client confirmations change confirmed mapped state":
    var state = newWmState()
    discard state.addRuntimeClient(epoch, client, decoration, group)
    check not state.lookup(client).get.mapped
    discard state.transition(epoch, WmInput(kind: wiDecorationMapConfirmed,
        window: decoration))
    check not state.lookup(client).get.mapped
    discard state.transition(epoch, WmInput(kind: wiMapConfirmed,
        window: client))
    check state.lookup(client).get.mapped
    discard state.transition(epoch, WmInput(kind: wiDecorationUnmapConfirmed,
        window: decoration))
    check state.lookup(client).get.mapped
    discard state.transition(epoch, WmInput(kind: wiUnmapConfirmed,
        window: client))
    check not state.lookup(client).get.mapped

  test "destroy removes identity and does not reuse generation":
    var state = newWmState()
    let first = state.addRuntimeClient(epoch, client, decoration, group).state
    let destroyed = state.transition(epoch,
        WmInput(kind: wiDestroyConfirmed, window: client))
    check destroyed.removed
    check destroyed.effects.mapIt(it.kind) ==
        @[weDestroyDecoration, wePublishClientLists, wePublishActiveGroups]
    let second = state.addRuntimeClient(epoch, client, WindowId(0x102), group).state
    check second.token.generation.raw > first.token.generation.raw
    check second.token != first.token

  test "unknown confirmations are safe no-ops":
    var state = newWmState()
    let mapped = state.transition(epoch,
        WmInput(kind: wiMapConfirmed, window: WindowId(0x999)))
    let unmapped = state.transition(epoch,
        WmInput(kind: wiUnmapConfirmed, window: WindowId(0x999)))
    let destroyed = state.transition(epoch,
        WmInput(kind: wiDestroyConfirmed, window: WindowId(0x999)))
    check not mapped.hasClient and mapped.effects.len == 0
    check not unmapped.hasClient and unmapped.effects.len == 0
    check not destroyed.removed and destroyed.effects.len == 0
