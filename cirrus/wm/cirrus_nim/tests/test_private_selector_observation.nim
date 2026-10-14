import std/[unittest, sequtils]
import ../model/[types, state, lifecycle]

let epoch = ProcessEpoch(hi: 0xabc'u64, lo: 0xdef'u64)

proc add(state: var WmState; xid: uint32; mapped: bool; group: uint32): ClientState =
  state.addAdoptedClient(epoch, WindowId(xid), mapped, RawGroup(group), wsvNormal).state

proc observation(state: WmState; sequence: uint32; matched: openArray[ClientState];
                 includeAll = true; mappedOnly = false; group = 0'u32): QuerySelectionObservation =
  result = QuerySelectionObservation(status: qosAvailable, requestSequence: sequence)
  if includeAll:
    for client in state.clientsInManagedOrder():
      if mappedOnly and not client.mapped: continue
      if group != 0'u32 and uint32(client.group) != group: continue
      let found = client.id in matched.mapIt(it.id)
      result.facts.add(QueryMatchFact(clientId: client.id, token: client.token,
          window: client.window, requestSequence: sequence,
          propertyStatus: if found: qpsMatched else: qpsNoMatch))

proc execute(state: var WmState; obs: QuerySelectionObservation;
             sequence = 7'u32; scopeAll = true; payload: seq[byte] = @[]): PrivateCommandResult =
  state.applyPrivateCommand(epoch, PrivateSemanticInput(opcode: 13'u32,
      words: [0'u32, 0'u32, (if scopeAll: 1'u32 else: 0'u32), 1'u32],
      propertyPayload: payload, requestSequence: sequence,
      querySelectionObservation: obs))

suite "opcode 13 identity-bound selector observations":
  test "available-empty differs from unavailable":
    var state = newWmState()
    discard state.add(0x100'u32, true, 1)
    let empty = state.execute(state.observation(7, []), 7)
    check empty.disposition == pcdSemanticAccepted
    check empty.reply.payload == "OK"
    let unavailable = state.execute(QuerySelectionObservation(status: qosUnavailable, requestSequence: 7), 7)
    check unavailable.disposition == pcdDeferred

  test "managed order remains authoritative regardless of fact order":
    var state = newWmState()
    let a = state.add(0x101'u32, true, 1)
    let b = state.add(0x102'u32, true, 1)
    var obs = QuerySelectionObservation(status: qosAvailable, requestSequence: 7)
    obs.facts = @[QueryMatchFact(clientId: a.id, token: a.token, window: a.window, requestSequence: 7, propertyStatus: qpsMatched),
                  QueryMatchFact(clientId: b.id, token: b.token, window: b.window, requestSequence: 7, propertyStatus: qpsMatched)]
    let result = state.execute(obs)
    check result.disposition == pcdSemanticAccepted
    check result.reply.payload == "OK\n0x00000102\n0x00000101"

  test "stale generation and duplicate facts defer":
    var state = newWmState()
    let old = state.add(0x103'u32, true, 1)
    discard state.transition(epoch, WmInput(kind: wiDestroyConfirmed, window: old.window))
    let replacement = state.add(0x103'u32, true, 1)
    let stale = QuerySelectionObservation(status: qosAvailable, requestSequence: 7, facts: @[
      QueryMatchFact(clientId: replacement.id, token: old.token, window: old.window, requestSequence: 7, propertyStatus: qpsMatched)])
    check state.execute(stale).disposition == pcdDeferred
    var duplicate = state.observation(7, [replacement])
    duplicate.facts.add(duplicate.facts[0])
    check state.execute(duplicate).disposition == pcdDeferred

  test "partial, error, invalid pattern, and wrong request serial are distinct":
    var state = newWmState()
    discard state.add(0x104'u32, true, 1)
    check state.execute(QuerySelectionObservation(status: qosPartial, requestSequence: 7), 7).disposition == pcdDeferred
    let failed = state.execute(QuerySelectionObservation(status: qosError, requestSequence: 7), 7)
    check failed.disposition == pcdSemanticRejected
    check failed.reply.payload == "ERROR unable to prepare selector query"
    let regex = state.execute(QuerySelectionObservation(status: qosInvalidPattern, requestSequence: 7), 7)
    check regex.reply.payload == "ERROR invalid title regex"
    check state.execute(state.observation(8, []), 7).disposition == pcdDeferred

  test "mapped and raw-group scope are applied by pure adapter":
    var state = newWmState()
    let visible = state.add(0x105'u32, true, 1)
    discard state.add(0x106'u32, false, 1)
    discard state.add(0x107'u32, true, 2)
    let allObs = state.observation(7, [visible], true, mappedOnly = true)
    let mapped = state.execute(allObs, 7, false)
    check mapped.disposition == pcdSemanticAccepted
    check mapped.reply.payload == "OK\n0x00000105"
    let groupPayload = @[2'u8, 0, 0, 0]
    let other = state.clientsInManagedOrder()[0]
    let groupObs = state.observation(7, [other], true, group = 2)
    let group = state.execute(groupObs, 7, true, groupPayload)
    check group.disposition == pcdSemanticAccepted
    check group.reply.payload == "OK\n0x00000107"
