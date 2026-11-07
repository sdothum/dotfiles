import std/[unittest, options, sequtils]
import ../model/[types, state, lifecycle]
import ../x11/[bindings, realize]

suite "runtime lifecycle model transitions":
  let epoch = ProcessEpoch(hi: 0x1234'u64, lo: 0x5678'u64)
  let client = WindowId(0x100'u32)
  let decoration = WindowId(0x101'u32)
  let group = RawGroup(1)

  test "opcode 7 uses focus history, ignores words, and has no reply":
    var state = newWmState()
    let a = state.addAdoptedClient(epoch, WindowId(0x701), true,
        RawGroup(1), wsvNormal).state
    let b = state.addAdoptedClient(epoch, WindowId(0x702), true,
        RawGroup(1), wsvNormal).state
    let c = state.addAdoptedClient(epoch, WindowId(0x703), true,
        RawGroup(1), wsvNormal).state
    discard state.transition(epoch, WmInput(kind: wiFocusClient, clientId: a.id))
    discard state.transition(epoch, WmInput(kind: wiFocusClient, clientId: b.id))

    let lastToA = state.applyPrivateCommand(epoch,
        PrivateSemanticInput(opcode: 7'u32,
            words: [0xdeadbeef'u32, 0x11111111'u32,
                    0x22222222'u32, 0x33333333'u32]))
    check lastToA.disposition == pcdSemanticAccepted
    check not lastToA.reply.required
    check lastToA.transition.effects.mapIt(it.kind).contains(weSetInputFocus)
    check state.focusedId.get == a.id

    let repeat = state.applyPrivateCommand(epoch,
        PrivateSemanticInput(opcode: 7'u32,
            words: [0'u32, 0'u32, 0'u32, 0'u32]))
    check not repeat.reply.required
    check state.focusedId.get == b.id

    # An unmapped historical client is skipped, as C's helper selects the
    # first mapped item after the current focus-list head.
    discard state.confirmMapped(a.window, false)
    let skipUnmapped = state.applyPrivateCommand(epoch,
        PrivateSemanticInput(opcode: 7'u32))
    check state.focusedId.get == c.id
    check not skipUnmapped.reply.required

    # Destroying the historical candidate removes it from focus order. The
    # remaining unmapped historical client is skipped without selecting a
    # stale identity or changing focus.
    state.setFocused(b.id)
    discard state.removeIdentity(c.window)
    let destroyedHistory = state.applyPrivateCommand(epoch,
        PrivateSemanticInput(opcode: 7'u32))
    check state.focusedId.get == b.id
    check destroyedHistory.transition.effects.len == 0
    check not destroyedHistory.reply.required

    # With a single mapped client, C's list-head fallback focuses that client
    # again (including the normal focus and raise effects).
    var singletonState = newWmState()
    let only = singletonState.addAdoptedClient(epoch, WindowId(0x704), true,
        RawGroup(1), wsvNormal).state
    singletonState.setFocused(only.id)
    let singleton = singletonState.applyPrivateCommand(epoch,
        PrivateSemanticInput(opcode: 7'u32))
    check singletonState.focusedId.get == only.id
    check singleton.transition.effects.mapIt(it.kind).contains(weSetInputFocus)
    check not singleton.reply.required

    state.clearFocused()
    let noFocus = state.applyPrivateCommand(epoch,
        PrivateSemanticInput(opcode: 7'u32))
    check noFocus.disposition == pcdSemanticAccepted
    check noFocus.transition.effects.len == 0
    check not noFocus.reply.required
    check state.focusedId.isNone

  test "initial EWMH startup effects are ordered and desktop count stays fixed":
    var state = newWmState()
    let initial = state.transition(epoch, WmInput(kind: wiInitializeEwmh))
    check initial.effects.mapIt(it.kind) == @[
      wePublishCurrentDesktop, wePublishNumberOfDesktops]
    check initial.effects[0].group.raw == 0'u32
    check initial.effects[1].desktopCount == 10'u32
    check state.groupCount == 10'u32
    let configured = state.applyPrivateCommand(epoch,
        PrivateSemanticInput(opcode: 10'u32,
            words: [14'u32, 5'u32, 0'u32, 0'u32]))
    check configured.disposition == pcdSemanticAccepted
    check state.groupCount == 5'u32
    check configured.transition.effects.allIt(
        it.kind != wePublishNumberOfDesktops)

  test "opcode 29 queries explicit target without state effects":
    var state = newWmState()
    let target = WindowId(0x202'u32)
    discard state.addAdoptedClient(epoch, WindowId(0x201), true,
        RawGroup(1), wsvNormal)
    discard state.addAdoptedClient(epoch, target, true,
        RawGroup(2), wsvNormal)
    let beforeClients = state.clientsInManagedOrder()
    let query = state.applyPrivateCommand(epoch,
        PrivateSemanticInput(opcode: 29'u32,
            words: [0x301'u32, 0'u32, target.raw, 0'u32]))
    check query.disposition == pcdSemanticAccepted
    check query.reply.required
    check query.reply.payload == "OK 2"
    check query.transition.effects.len == 0
    check state.clientsInManagedOrder() == beforeClients
    let missing = state.applyPrivateCommand(epoch,
        PrivateSemanticInput(opcode: 29'u32,
            words: [0x302'u32, 0'u32, 0x999'u32, 0'u32]))
    check missing.disposition == pcdSemanticAccepted
    check missing.reply.payload == "ERROR unknown or unmanaged window"
    check missing.transition.effects.len == 0

  test "opcode 30 returns all managed groups in managed order without effects":
    var state = newWmState()
    let first = WindowId(0x201'u32)
    let second = WindowId(0x202'u32)
    discard state.addAdoptedClient(epoch, first, true, RawGroup(1), wsvNormal)
    discard state.addAdoptedClient(epoch, second, false, RawGroup(2), wsvNormal)
    let beforeClients = state.clientsInManagedOrder()
    let query = state.applyPrivateCommand(epoch,
        PrivateSemanticInput(opcode: 30'u32,
            words: [0x301'u32, 0'u32, 0'u32, 0'u32]))
    check query.disposition == pcdSemanticAccepted
    check query.reply.required
    check query.reply.payload == "OK\n0x00000202 2\n0x00000201 1\n"
    check query.transition.effects.len == 0
    check state.clientsInManagedOrder() == beforeClients

    var empty = newWmState()
    let emptyQuery = empty.applyPrivateCommand(epoch,
        PrivateSemanticInput(opcode: 30'u32,
            words: [0x302'u32, 0'u32, 0'u32, 0'u32]))
    check emptyQuery.disposition == pcdSemanticAccepted
    check emptyQuery.reply.payload == "OK"
    check emptyQuery.transition.effects.len == 0

  test "opcode 12 reports authoritative focus without changing model state":
    var state = newWmState()
    let first = state.addAdoptedClient(epoch, WindowId(0x201), true,
        RawGroup(1), wsvNormal).state
    let second = state.addAdoptedClient(epoch, WindowId(0x202), true,
        RawGroup(2), wsvNormal).state
    state.setFocused(first.id)
    let beforeFocus = state.focusedId
    let beforeGroup = state.currentGroup
    let beforeOrder = state.focusOrderClients()
    let requester = 0x301'u32
    let query = state.applyPrivateCommand(epoch,
        PrivateSemanticInput(opcode: 12'u32,
            words: [requester, 0'u32, 0'u32, 0'u32]))
    check query.disposition == pcdSemanticAccepted
    check query.reply.required
    check query.reply.payload == "OK 0x00000201"
    check query.transition.effects.len == 0
    check not query.invalidationRequired
    check query.invalidationRequirementKnown
    check state.focusedId == beforeFocus
    check state.currentGroup == beforeGroup
    check state.focusOrderClients() == beforeOrder

    state.setFocused(second.id)
    let changed = state.applyPrivateCommand(epoch,
        PrivateSemanticInput(opcode: 12'u32,
            words: [requester, 0'u32, 0'u32, 0'u32]))
    check changed.reply.payload == "OK 0x00000202"
    check changed.transition.effects.len == 0
    check not changed.invalidationRequired

    discard state.removeIdentity(second.window)
    let destroyed = state.applyPrivateCommand(epoch,
        PrivateSemanticInput(opcode: 12'u32,
            words: [requester, 0'u32, 0'u32, 0'u32]))
    check destroyed.reply.payload == "ERROR no focused managed window"
    check destroyed.transition.effects.len == 0
    check not destroyed.invalidationRequired

  test "opcode 12 reports no focus without effects or requester-target confusion":
    var state = newWmState()
    discard state.addAdoptedClient(epoch, WindowId(0x201), false,
        RawGroup(1), wsvNormal)
    let requester = 0x301'u32
    let query = state.applyPrivateCommand(epoch,
        PrivateSemanticInput(opcode: 12'u32,
            words: [requester, 0'u32, 0'u32, 0'u32]))
    check query.reply.payload == "ERROR no focused managed window"
    check query.transition.effects.len == 0
    check not query.invalidationRequired
    check state.focusedId.isNone

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
      wePublishInvalidation, weMapClient, weCreateDecoration, weMapDecoration,
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
        @[weDestroyDecoration, wePublishInvalidation, wePublishClientLists, wePublishActiveGroups]
    let second = state.addRuntimeClient(epoch, client, WindowId(0x102), group).state
    check second.token.generation.raw > first.token.generation.raw
    check second.token != first.token

  test "unknown map/unmap are no-ops and unknown destroy republishes groups":
    var state = newWmState()
    let mapped = state.transition(epoch,
        WmInput(kind: wiMapConfirmed, window: WindowId(0x999)))
    let unmapped = state.transition(epoch,
        WmInput(kind: wiUnmapConfirmed, window: WindowId(0x999)))
    let destroyed = state.transition(epoch,
        WmInput(kind: wiDestroyConfirmed, window: WindowId(0x999)))
    check not mapped.hasClient and mapped.effects.len == 0
    check not unmapped.hasClient and unmapped.effects.len == 0
    check not destroyed.removed
    check destroyed.effects.mapIt(it.kind) ==
        @[weRepublishClientLists, wePublishActiveGroups]
    check destroyed.effects[1].groups.len == 0

  test "unmanaged destroy publishes model-derived active groups":
    var state = newWmState()
    discard state.addAdoptedClient(epoch, WindowId(0x998), true,
        RawGroup(2), wsvNormal)
    discard state.addAdoptedClient(epoch, WindowId(0x997), true,
        RawGroup(1), wsvNormal)
    let groupsBefore = state.activeGroups
    let firstBefore = state.lookup(WindowId(0x998)).get
    let secondBefore = state.lookup(WindowId(0x997)).get
    let destroyed = state.transition(epoch, WmInput(kind: wiDestroyConfirmed,
        window: WindowId(0x999)))
    check not destroyed.removed
    check not destroyed.hasClient
    check destroyed.effects.mapIt(it.kind) ==
        @[weRepublishClientLists, wePublishActiveGroups]
    check destroyed.effects[1].groups == @[RawGroup(1), RawGroup(2)]
    check state.identityCount == 2
    check state.lookup(WindowId(0x998)).isSome
    check state.lookup(WindowId(0x997)).isSome
    check state.activeGroups == groupsBefore
    check state.focusedId.isNone
    let firstAfter = state.lookup(WindowId(0x998)).get
    let secondAfter = state.lookup(WindowId(0x997)).get
    check firstAfter.mapped == firstBefore.mapped
    check firstAfter.group == firstBefore.group
    check firstAfter.geometry == firstBefore.geometry
    check secondAfter.mapped == secondBefore.mapped
    check secondAfter.group == secondBefore.group
    check secondAfter.geometry == secondBefore.geometry
    check destroyed.effects.countIt(it.kind == wePublishInvalidation) == 0

  test "checked status publication tolerates only opted-in stale-window errors":
    check checkedErrorDisposition(none(uint8), true) == cedRequestSucceeded
    check checkedErrorDisposition(some(ErrorBadWindow), true) == cedIgnoreMissingWindow
    check checkedErrorDisposition(some(ErrorBadWindow), false) == cedPropagate
    check checkedErrorDisposition(some(8'u8), true) == cedPropagate
    check checkedErrorDisposition(none(uint8), missingIsOk = false,
        badValueIsOk = true) ==
        cedRequestSucceeded
    check checkedErrorDisposition(some(ErrorBadValue), missingIsOk = false,
        badValueIsOk = true) ==
        cedIgnoreBadValue
    check checkedErrorDisposition(some(ErrorBadWindow), missingIsOk = false,
        badValueIsOk = true) ==
        cedPropagate
    check checkedErrorDisposition(some(ErrorBadAccess), missingIsOk = false,
        badValueIsOk = true) ==
        cedPropagate

  test "mapped unmap retains status-before-invalidation effect order":
    var state = newWmState()
    discard state.addAdoptedClient(epoch, client, true, group, wsvNormal)
    let unmap = state.transition(epoch,
        WmInput(kind: wiUnmapConfirmed, window: client))
    let kinds = unmap.effects.mapIt(it.kind)
    check kinds == @[weRepublishClientLists, wePublishStatus, wePublishInvalidation]

    let statusDisposition = checkedErrorDisposition(
        some(ErrorBadWindow), missingIsOk = true)
    check statusDisposition == cedIgnoreMissingWindow
    var continuedEffects: seq[WmEffectKind]
    for effect in unmap.effects:
      if effect.kind == wePublishStatus and
          statusDisposition == cedPropagate:
        break
      continuedEffects.add(effect.kind)
    check continuedEffects == kinds
    check continuedEffects[^1] == wePublishInvalidation

