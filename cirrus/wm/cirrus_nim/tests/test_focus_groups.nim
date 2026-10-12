import std/[unittest, options, sequtils]
import ../model/[types, state, lifecycle]

let epoch = ProcessEpoch(hi: 0x123'u64, lo: 0x456'u64)

proc addClient(state: var WmState; xid, group: uint32; mapped = true): ClientState =
  result = state.addAdoptedClient(epoch, WindowId(xid), mapped,
      RawGroup(group), wsvNormal).state

suite "focus and asynchronous group model":
  test "focus history, focus last, and repeat focus":
    var state = newWmState()
    let a = state.addClient(0x101, 1)
    let b = state.addClient(0x102, 1)
    discard state.addClient(0x103, 1)
    discard state.transition(epoch, WmInput(kind: wiFocusClient, clientId: a.id))
    discard state.transition(epoch, WmInput(kind: wiFocusClient, clientId: b.id))
    let repeated = state.transition(epoch, WmInput(kind: wiFocusClient, clientId: b.id))
    check repeated.effects.mapIt(it.kind).contains(weSetInputFocus)
    check state.focusOrderClients()[0].id == b.id
    discard state.transition(epoch, WmInput(kind: wiFocusLast))
    check state.focusedId.get == a.id

  test "cycle follows managed order, reverse and group cycle filter":
    var state = newWmState()
    let a = state.addClient(0x201, 1)
    let b = state.addClient(0x202, 2)
    let c = state.addClient(0x203, 1)
    discard state.transition(epoch, WmInput(kind: wiFocusClient, clientId: a.id))
    discard state.transition(epoch, WmInput(kind: wiCycle))
    check state.focusedId.get == c.id # C managed order is newest-first: C,B,A.
    discard state.transition(epoch, WmInput(kind: wiFocusClient, clientId: a.id))
    discard state.transition(epoch, WmInput(kind: wiReverseCycle))
    check state.focusedId.get == b.id
    discard state.transition(epoch, WmInput(kind: wiFocusClient, clientId: a.id))
    discard state.transition(epoch, WmInput(kind: wiCycleGroup))
    check state.focusedId.get == c.id
    discard state.transition(epoch, WmInput(kind: wiReverseCycleGroup))
    check state.focusedId.get == a.id

  test "cycle without focus follows the C head/tail starting points":
    var state = newWmState()
    discard state.addClient(0x251, 1)
    let b = state.addClient(0x252, 1)
    discard state.addClient(0x253, 1)
    discard state.transition(epoch, WmInput(kind: wiCycle))
    check state.focusedId.get == b.id
    state.clearFocused()
    discard state.transition(epoch, WmInput(kind: wiReverseCycle))
    check state.focusedId.get == b.id
    state.clearFocused()
    discard state.transition(epoch, WmInput(kind: wiCycleGroup))
    check state.focusedId.isNone

  test "unknown focus and external unmanaged focus are harmless":
    var state = newWmState()
    let a = state.addClient(0x301, 1)
    discard state.transition(epoch, WmInput(kind: wiFocusClient,
        window: WindowId(0xdead)))
    check state.focusedId.isNone
    discard state.transition(epoch, WmInput(kind: wiFocusClient, clientId: a.id))
    let external = state.transition(epoch, WmInput(kind: wiFocusReconcile,
        actualFocus: WindowId(0xbeef), rootWindow: WindowId(1)))
    check external.effects.len == 0
    check state.focusedId.get == a.id
    discard state.transition(epoch, WmInput(kind: wiFocusReconcile,
        actualFocus: WindowId(1), rootWindow: WindowId(1)))
    check state.focusedId.isNone

  test "group assignment and activation retain pending confirmation semantics":
    var state = newWmState()
    let a = state.addClient(0x401, 1, false)
    let assigned = state.transition(epoch, WmInput(kind: wiAssignGroup,
        clientId: a.id, group: RawGroup(2)))
    check assigned.client.group == RawGroup(2)
    state.activeGroups[2] = false
    let activated = state.transition(epoch, WmInput(kind: wiActivateGroup,
        group: RawGroup(2)))
    check activated.effects.mapIt(it.kind).contains(weMapClient)
    check not state.lookup(a.id).get.mapped
    check state.lookup(a.id).get.groupMapPending
    let mapNotify = state.transition(epoch, WmInput(kind: wiMapConfirmed,
        window: a.window))
    check state.lookup(a.id).get.mapped
    check not state.lookup(a.id).get.groupMapPending
    check not mapNotify.effects.mapIt(it.kind).contains(weSetInputFocus)

  test "group removal publishes NullGroup without disturbing another member":
    var state = newWmState()
    let a = state.addClient(0x451, 2)
    discard state.addClient(0x452, 2)
    let removed = state.transition(epoch, WmInput(kind: wiRemoveGroup,
        clientId: a.id))
    check removed.client.group == NullGroup
    check state.activeGroups[2]
    check removed.effects.mapIt(it.kind).contains(wePublishDesktop)

  test "deactivation changes only after UnmapNotify and suppresses group fallback":
    var state = newWmState()
    let a = state.addClient(0x501, 1, true)
    discard state.transition(epoch, WmInput(kind: wiFocusClient, clientId: a.id))
    let deactivated = state.transition(epoch, WmInput(kind: wiDeactivateGroup,
        group: RawGroup(1)))
    check deactivated.effects.mapIt(it.kind).contains(weUnmapClient)
    check state.lookup(a.id).get.mapped
    check state.lookup(a.id).get.groupUnmapPending
    let unmapNotify = state.transition(epoch, WmInput(kind: wiUnmapConfirmed,
        window: a.window))
    check not state.lookup(a.id).get.mapped
    check not state.lookup(a.id).get.groupUnmapPending
    check state.focusedId.isNone
    check not unmapNotify.effects.mapIt(it.kind).contains(weRaiseClient)

  test "Race A and Race B retain the frozen C reversal outcomes":
    var raceA = newWmState()
    let a = raceA.addClient(0x601, 1, true)
    discard raceA.transition(epoch, WmInput(kind: wiDeactivateGroup, group: RawGroup(1)))
    discard raceA.transition(epoch, WmInput(kind: wiActivateGroup, group: RawGroup(1)))
    discard raceA.transition(epoch, WmInput(kind: wiUnmapConfirmed, window: a.window))
    check raceA.activeGroups[1]
    check not raceA.lookup(a.id).get.mapped
    check raceA.focusedId.isNone

    var raceB = newWmState()
    let b = raceB.addClient(0x602, 1, false)
    raceB.activeGroups[1] = false
    discard raceB.transition(epoch, WmInput(kind: wiActivateGroup, group: RawGroup(1)))
    discard raceB.transition(epoch, WmInput(kind: wiDeactivateGroup, group: RawGroup(1)))
    let lateMap = raceB.transition(epoch, WmInput(kind: wiMapConfirmed, window: b.window))
    check not raceB.activeGroups[1]
    check raceB.lookup(b.id).get.mapped
    check not raceB.lookup(b.id).get.groupMapPending
    check raceB.focusedId.isNone
    check not lateMap.effects.mapIt(it.kind).contains(weSetInputFocus)

  test "focused unmap and destroy use fallback or clear when disabled":
    var state = newWmState()
    let a = state.addClient(0x701, 1, true)
    let b = state.addClient(0x702, 1, true)
    discard state.transition(epoch, WmInput(kind: wiFocusClient, clientId: a.id))
    discard state.transition(epoch, WmInput(kind: wiFocusClient, clientId: b.id))
    discard state.transition(epoch, WmInput(kind: wiUnmapConfirmed, window: b.window))
    check state.focusedId.get == a.id
    discard state.transition(epoch, WmInput(kind: wiFocusClient, clientId: b.id))
    discard state.transition(epoch, WmInput(kind: wiDestroyConfirmed, window: b.window))
    check state.focusedId.get == a.id
    discard state.transition(epoch, WmInput(kind: wiSetLastWindowFocus,
        enabled: false))
    discard state.transition(epoch, WmInput(kind: wiUnmapConfirmed, window: a.window))
    check state.focusedId.isNone
