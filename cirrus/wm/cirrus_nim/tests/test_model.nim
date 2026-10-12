import std/[unittest, options, strutils]
import ../model/[types, identity, state]
import ../startup/[adoption, identity_service]
import ../x11/[queries, atoms]

proc prop(kind: uint32; value: uint32): Property32 =
  Property32(present: true, typeAtom: kind, format: 32, values: @[value])

proc observation(window: uint32; mapped = false;
                 wmState = wsvAbsent; desktop: Option[uint32] = none(uint32);
                 overrideRedirect = false; windowTypes: seq[uint32] = @[]): StartupWindowObservation =
  result.window = window
  result.mapState = if mapped: 2 else: 0
  result.overrideRedirect = overrideRedirect
  if wmState != wsvAbsent:
    let value = case wmState
      of wsvNormal: 1'u32
      of wsvIconic: 3'u32
      of wsvWithdrawn: 0'u32
      of wsvAbsent, wsvOther: 99'u32
    result.wmState = prop(10, value)
  if desktop.isSome: result.desktop = prop(11, desktop.get)
  if windowTypes.len > 0:
    result.windowTypes = Property32(present: true, typeAtom: 12,
                                    format: 32, values: windowTypes)

suite "Stage 2 authoritative identity model":
  test "deterministic epoch and frozen token format":
    let epoch = ProcessEpoch(hi: 0x0123456789abcdef'u64,
                             lo: 0xfedcba9876543210'u64)
    var mutable = newWmState()
    let client = mutable.addAdoptedClient(epoch, WindowId(0x1234), true,
                                           RawGroup(1), wsvAbsent).state
    check client.token.formatToken() == "0123456789abcdeffedcba9876543210:0000000000000001"
    check client.token.formatToken().len == 49
    check client.token.formatToken().toLowerAscii == client.token.formatToken()
    let otherEpoch = ProcessEpoch(hi: 1, lo: 2)
    check otherEpoch != client.token.epoch

  test "OS process epochs differ across calls":
    check newProcessEpoch() != newProcessEpoch()

  test "duplicate XID is idempotent and order is explicit":
    let epoch = ProcessEpoch(hi: 1, lo: 2)
    var wm = newWmState()
    let a = wm.addAdoptedClient(epoch, WindowId(10), true, RawGroup(1), wsvAbsent)
    let b = wm.addAdoptedClient(epoch, WindowId(20), false, RawGroup(3), wsvNormal)
    let duplicate = wm.addAdoptedClient(epoch, WindowId(10), false, RawGroup(9), wsvIconic)
    check a.created and b.created
    check not duplicate.created
    check duplicate.state.token == a.state.token
    check wm.identityCount == 2
    check wm.clientsInManagedOrder()[0].window == WindowId(20)
    check wm.clientsInManagedOrder()[1].window == WindowId(10)
    check wm.lookup(WindowId(20)).get.mapped == false
    check wm.lookup(WindowId(20)).get.group == RawGroup(3)

  test "removed XID receives a strictly newer token on re-add":
    let epoch = ProcessEpoch(hi: 3, lo: 4)
    var wm = newWmState()
    let first = wm.addAdoptedClient(epoch, WindowId(77), true, RawGroup(1), wsvAbsent).state
    check wm.removeIdentity(WindowId(77))
    let second = wm.addAdoptedClient(epoch, WindowId(77), true, RawGroup(1), wsvAbsent).state
    check first.token != second.token
    check second.token.generation.raw > first.token.generation.raw

  test "generation exhaustion fails instead of wrapping":
    let epoch = ProcessEpoch(hi: 0, lo: 1)
    var wm = newWmState(high(uint64))
    let last = wm.addAdoptedClient(epoch, WindowId(1), true, RawGroup(1), wsvAbsent)
    check last.state.token.generation.raw == high(uint64)
    expect ValueError:
      discard wm.addAdoptedClient(epoch, WindowId(2), true, RawGroup(1), wsvAbsent)

suite "Stage 2 frozen startup adoption predicate":
  let atoms = Atoms(netWmWindowTypeDock: 21,
      netWmWindowTypeToolbar: 22, netWmWindowTypeDesktop: 23)

  test "mapped ordinary and Normal hidden are adopted":
    let mapped = observation(1, mapped = true).decideAdoption(atoms, 10)
    check mapped.adopted and mapped.mapped and mapped.group == RawGroup(1)
    let hidden = observation(2, wmState = wsvNormal,
        desktop = some(4'u32)).decideAdoption(atoms, 10)
    check hidden.adopted and not hidden.mapped and hidden.group == RawGroup(4)

  test "Iconic Withdrawn and absent unmapped clients are skipped":
    for state in [wsvIconic, wsvWithdrawn, wsvAbsent]:
      check not observation(3, wmState = state, desktop = some(1'u32))
          .decideAdoption(atoms, 10).adopted

  test "unmapped Normal requires an in-range CARDINAL desktop":
    check not observation(4, wmState = wsvNormal).decideAdoption(atoms, 10).adopted
    check not observation(4, wmState = wsvNormal,
        desktop = some(10'u32)).decideAdoption(atoms, 10).adopted
    check not observation(4, wmState = wsvNormal,
        desktop = some(0xffffffff'u32)).decideAdoption(atoms, 10).adopted

  test "mapped invalid/missing group uses C default; one-group fallback is NULL_GROUP":
    check observation(5, mapped = true, desktop = some(10'u32))
        .decideAdoption(atoms, 10).group == RawGroup(1)
    check observation(5, mapped = true).decideAdoption(atoms, 1).group == NullGroup

  test "override redirect and three special types are skipped":
    check not observation(6, mapped = true, overrideRedirect = true)
        .decideAdoption(atoms, 10).adopted
    for kind in [21'u32, 22'u32, 23'u32]:
      check not observation(7, mapped = true, windowTypes = @[kind])
          .decideAdoption(atoms, 10).adopted
