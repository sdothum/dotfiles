import std/[unittest, options, sequtils]
import ../model/[types, state, stacking, lifecycle]
import ../runtime/event_types

let epoch = ProcessEpoch(hi: 1, lo: 2)

proc add(state: var WmState; xid: uint32; x: int32; mapped = true): ClientState =
  state.addAdoptedClient(epoch, WindowId(xid), mapped, RawGroup(1), wsvNormal,
      int16(x), 0, 100, 100).state

suite "Stage 6A pure stack selection":
  test "stacking event sequence interval handles uint32 wraparound":
    let lower = high(uint32) - 2'u32
    let upper = 3'u32
    check not sequenceInOpenInterval(lower, lower, upper)
    check sequenceInOpenInterval(high(uint32), lower, upper)
    check sequenceInOpenInterval(0'u32, lower, upper)
    check sequenceInOpenInterval(2'u32, lower, upper)
    check not sequenceInOpenInterval(upper, lower, upper)
    check not sequenceInOpenInterval(upper + 1'u32, lower, upper)
    check sequenceAfter(0'u32, high(uint32))
    check sequenceBefore(high(uint32), 0'u32)

  test "adjacent and overlapping guard sequence intervals retain open boundaries":
    check sequenceInOpenInterval(19'u32, 10'u32, 20'u32)
    check not sequenceInOpenInterval(20'u32, 10'u32, 20'u32)
    check not sequenceInOpenInterval(20'u32, 20'u32, 30'u32)
    check sequenceInOpenInterval(21'u32, 20'u32, 30'u32)
    check sequenceInOpenInterval(19'u32, 10'u32, 22'u32)
    check sequenceInOpenInterval(19'u32, 18'u32, 30'u32)
    check not sequenceInOpenInterval(10'u32, 10'u32, 22'u32)
    check not sequenceInOpenInterval(30'u32, 18'u32, 30'u32)

  test "positive-area overlap, edge contact and negative coordinates":
    let a = Geometry(x: -20, y: 0, width: 10, height: 10)
    check overlaps(a, Geometry(x: -15, y: 5, width: 20, height: 20))
    check not overlaps(a, Geometry(x: -10, y: 0, width: 5, height: 10))
    check not overlaps(a, Geometry(x: -20, y: 10, width: 10, height: 10))
    check overlaps(a, Geometry(x: -11, y: 0, width: 5, height: 10))
    check overlaps(a, Geometry(x: -20, y: 0, width: 10, height: 10))

  test "closure preserves observed bottom-to-top order and filters unmapped/stale":
    var state = newWmState()
    let a = state.add(0x101, 0)
    let bridge = state.add(0x102, 90)
    let c = state.add(0x103, 180)
    let d = state.add(0x104, 500)
    let hidden = state.add(0x105, 45, false)
    let order = StackObservation(managedBottomToTop: @[
      a.window, bridge.window, c.window, d.window, hidden.window,
      WindowId(0xdead)])
    let closure = state.overlapClosure(order, a.window)
    check closure.len == 3
    check closure[0].id == a.id and closure[1].id == bridge.id and
        closure[2].id == c.id
    check state.overlapClosure(order, WindowId(0xbeef)).len == 0

  test "destroyed overlap bridge is removed before a fresh closure":
    var state = newWmState()
    let a = state.add(0x111, 0)
    let bridge = state.add(0x112, 90)
    let c = state.add(0x113, 180)
    let staleBridgeId = bridge.id
    let staleBridgeToken = bridge.token
    let observed = StackObservation(managedBottomToTop: @[
      a.window, bridge.window, c.window])
    check state.overlapClosure(observed, a.window).len == 3

    check state.removeIdentity(bridge.window)
    check state.lookup(staleBridgeId).isNone
    check state.overlapClosure(observed, a.window).mapIt(it.id) == @[a.id]

    let replacement = state.add(0x112, 90)
    check replacement.id != staleBridgeId
    check replacement.token != staleBridgeToken
    check state.overlapClosure(observed, a.window).mapIt(it.id) ==
        @[a.id, replacement.id, c.id]

  test "destroyed decoration identity cannot be resolved after client removal":
    var state = newWmState()
    let client = state.add(0x121, 0)
    var decorated = client
    decorated.decoration = some(WindowId(0x621))
    check state.replaceClient(decorated)
    check state.lookupDecoration(WindowId(0x621)).isSome
    check state.removeIdentity(client.window)
    check state.lookup(client.window).isNone
    check state.lookupDecoration(WindowId(0x621)).isNone

  test "singleton overlap closure has no cycle target":
    var state = newWmState()
    let only = state.add(0x200, 0)
    check state.cycleTarget(@[only], only.window).isNone

  test "homogeneous target follows physical position and wraps":
    var state = newWmState()
    let a = state.add(0x201, 0)
    let b = state.add(0x202, 0)
    let c = state.add(0x203, 0)
    let closure = @[a, b, c]
    check state.cycleTarget(closure, a.window).get.id == a.id
    check state.cycleTarget(closure, c.window).get.id == a.id

  test "mixed target is least-recent focused member, excluding anchor":
    var state = newWmState()
    var a = state.add(0x301, 0)
    var b = state.add(0x302, 0)
    var c = state.add(0x303, 0)
    b.layer = wlAbove
    c.layer = wlOverlay
    discard state.replaceClient(b)
    discard state.replaceClient(c)
    state.setFocused(a.id)
    state.setFocused(b.id)
    state.setFocused(c.id)
    let closure = @[a, b, c]
    check state.cycleTarget(closure, a.window).get.id == b.id

  test "priority derives transient zoom only from full maximize or monocle":
    var client = ClientState(layer: wlNormal)
    check effectivePriority(client) == spNormal
    client.layer = wlAbove
    check effectivePriority(client) == spAbove
    client.maxed = true
    check effectivePriority(client) == spZoomed
    client.maxed = false
    client.monocled = true
    check effectivePriority(client) == spZoomed
    client.monocled = false
    client.hmaxed = true
    check effectivePriority(client) == spAbove
    client.layer = wlOverlay
    check effectivePriority(client) == spOverlay

  test "stack-cycle transition consumes a physical observation, not managed order":
    var state = newWmState()
    let a = state.add(0x401, 0)
    let b = state.add(0x402, 0)
    discard state.transition(epoch, WmInput(kind: wiFocusClient,
        clientId: a.id))
    let transition = state.transition(epoch, WmInput(kind: wiStackCycle,
        window: b.window, physicalBottomToTop: @[a.window, b.window]))
    check transition.hasClient
    check transition.client.id == a.id
    check state.focusedId.get == a.id

  test "layer priority restacking retains unmanaged barrier slots and pairs decor":
    var state = newWmState()
    var normal = state.add(0x501, 0)
    var above = state.add(0x502, 0)
    normal.decoration = some(WindowId(0x601))
    above.decoration = some(WindowId(0x602))
    above.layer = wlAbove
    discard state.replaceClient(normal)
    discard state.replaceClient(above)
    let dock = WindowId(0x701)
    let desktop = WindowId(0x702)
    let observation = StackObservation(
        rootChildrenBottomToTop: @[above.window, WindowId(0x602), desktop,
          normal.window, WindowId(0x601), dock],
        unmanagedAbove: @[dock])
    check state.restackedRootOrder(observation) ==
        @[normal.window, WindowId(0x601), desktop, above.window,
          WindowId(0x602), dock]

  test "raise-many validates all participants and preserves caller order":
    var state = newWmState()
    let a = state.add(0x901, 0)
    let b = state.add(0x902, 0)
    let c = state.add(0x903, 0)
    let rootOrder = @[a.window, b.window, c.window]
    let raised = state.transition(epoch, WmInput(kind: wiRaiseMany,
        windows: @[c.window, a.window, b.window],
        physicalBottomToTop: rootOrder))
    check raised.effects.mapIt(it.kind) ==
        @[weRaiseClient, weRaiseClient, weRaiseClient]
    check raised.effects.mapIt(it.window) == @[c.window, a.window, b.window]
    let duplicate = state.transition(epoch, WmInput(kind: wiRaiseMany,
        windows: @[a.window, a.window], physicalBottomToTop: rootOrder))
    check duplicate.effects.len == 0
    let unknown = state.transition(epoch, WmInput(kind: wiRaiseMany,
        windows: @[a.window, WindowId(0xdead)],
        physicalBottomToTop: rootOrder))
    check unknown.effects.len == 0
    let hidden = state.add(0x904, 0, false)
    let unmapped = state.transition(epoch, WmInput(kind: wiRaiseMany,
        windows: @[a.window, hidden.window],
        physicalBottomToTop: rootOrder & @[hidden.window]))
    check unmapped.effects.len == 0
    var missingDecoration = state.add(0x905, 0)
    missingDecoration.decoration = some(WindowId(0x605))
    discard state.replaceClient(missingDecoration)
    let missingDecor = state.transition(epoch, WmInput(kind: wiRaiseMany,
        windows: @[a.window, missingDecoration.window],
        physicalBottomToTop: rootOrder & @[missingDecoration.window]))
    check missingDecor.effects.len == 0
    let missingClient = state.transition(epoch, WmInput(kind: wiRaiseMany,
        windows: @[a.window, missingDecoration.window],
        physicalBottomToTop: rootOrder & @[missingDecoration.decoration.get]))
    check missingClient.effects.len == 0

  test "CirculateRequest emits the exact forwarding effect without model changes":
    var state = newWmState()
    var a = state.add(0x0a01, 0)
    var b = state.add(0x0a02, 150, false)
    a.layer = wlAbove
    a.layerExplicit = true
    a.geometry = Geometry(x: 12, y: 24, width: 110, height: 90)
    discard state.replaceClient(a)
    b.layer = wlOverlay
    b.monocled = true
    discard state.replaceClient(b)
    discard state.transition(epoch, WmInput(kind: wiFocusClient,
        clientId: a.id))
    let beforeClients = state.clientsInManagedOrder()
    let beforeFocusOrder = state.focusOrderClients()
    let beforeFocused = state.focusedId
    let beforeGroup = state.currentGroup
    let beforeActiveGroups = state.activeGroups

    for place in 0'u8 .. 1'u8:
      let target = if place == 0: a.window else: WindowId(0x0bad)
      let before = state.clientsInManagedOrder()
      let transition = state.transition(epoch, WmInput(
          kind: wiCirculateRequest, window: target, circulatePlace: place))
      check transition.effects.mapIt(it.kind) == @[weCirculateRequest]
      check transition.effects[0].window == target
      check transition.effects[0].circulatePlace == place
      check not transition.hasClient
      check not transition.created and not transition.removed
      check state.clientsInManagedOrder() == before
      check state.focusOrderClients() == beforeFocusOrder
      check state.focusedId == beforeFocused
      check state.currentGroup == beforeGroup
      check state.activeGroups == beforeActiveGroups
    check state.clientsInManagedOrder() == beforeClients

  test "layer transition is authoritative and emits ordered effects":
    var state = newWmState()
    let client = state.add(0x801, 0)
    let changed = state.transition(epoch, WmInput(kind: wiSetLayer,
        window: client.window, layer: wlOverlay))
    check changed.client.layer == wlOverlay
    check changed.client.layerExplicit
    check changed.effects.mapIt(it.kind) == @[weRestackLayers, wePublishLayerState]

  test "failed layer restack restores prior logical layer without publishing":
    var state = newWmState()
    let client = state.add(0x811, 0)
    let changed = state.transition(epoch, WmInput(kind: wiSetLayer,
        window: client.window, layer: wlAbove))
    check changed.effects[0].restoreLayerOnFailure
    check changed.effects[0].previousLayer == wlNormal
    let failed = state.transition(epoch, WmInput(kind: wiLayerRestackFailed,
        window: client.window, layer: changed.effects[0].previousLayer,
        enabled: changed.effects[0].previousLayerExplicit))
    check failed.client.layer == wlNormal
    check not failed.client.layerExplicit
    check failed.effects.mapIt(it.kind) == @[weRestackLayers]
