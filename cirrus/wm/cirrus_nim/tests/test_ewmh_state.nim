import std/[unittest, options, sequtils]
import ../model/[types, state, lifecycle, geometry]

let epoch = ProcessEpoch(hi: 0x6d2c'u64, lo: 1'u64)
let bounds = GeometryBounds(x: 0, y: 0, width: 800, height: 600,
    borderExtent: 0)

proc clientState(layer = wlNormal; explicit = false): tuple[state: WmState,
    client: ClientState] =
  result.state = newWmState()
  result.client = result.state.addAdoptedClient(epoch, WindowId(0x801), true,
      RawGroup(1), wsvNormal, 40, 50, 200, 120).state
  result.client = result.state.lookup(WindowId(0x801)).get
  result.client.layer = layer
  result.client.layerExplicit = explicit
  discard result.state.replaceClient(result.client)

proc apply(state: var WmState; target: WindowId; action: uint32;
           first: EwmhStateAtom; second: EwmhStateAtom = esaUnknown;
           format = 32'u8;
           exists = true; dock = false): TransitionResult =
  state.transition(epoch, WmInput(kind: wiEwmhWmState, window: target,
      ewmhAction: action, ewmhStates: [first, second],
      ewmhFormat: format, ewmhWindowExists: exists, ewmhDock: dock,
      geometryBounds: bounds))

suite "Stage 6D-2C-1 pure _NET_WM_STATE transitions":
  test "Above ADD emits restack then property without changing focus, geometry or mapping":
    var pair = clientState()
    let before = pair.state.lookup(pair.client.window).get
    let changed = pair.state.apply(pair.client.window, 1, esaAbove)
    check changed.client.layer == wlAbove
    check changed.client.geometry == before.geometry
    check changed.client.mapped == before.mapped
    check pair.state.focusedId.isNone
    check changed.effects.mapIt(it.kind) == @[weRestackLayers, wePublishLayerState]
    check changed.effects[0].restoreLayerOnFailure
    check changed.effects[0].stackingState[0].layer == wlAbove
    check changed.effects[1].layer == wlAbove

  test "Above REMOVE, TOGGLE, repeated ADD, explicit layer and stale resource follow C":
    var pair = clientState(wlAbove)
    check pair.state.apply(pair.client.window, 0, esaAbove).client.layer == wlNormal
    check pair.state.apply(pair.client.window, 2, esaAbove).client.layer == wlAbove
    check pair.state.apply(pair.client.window, 1, esaAbove).client.layer == wlAbove
    pair = clientState(wlNormal, explicit = true)
    let explicit = pair.state.apply(pair.client.window, 1, esaAbove)
    check explicit.client.layer == wlNormal and explicit.effects.len == 0
    pair = clientState()
    let stale = pair.state.apply(pair.client.window, 1, esaAbove, exists = false)
    check stale.client.layer == wlNormal and stale.effects.len == 0

  test "Fullscreen ADD is idempotent and REMOVE restores orig geometry then focuses and raises":
    var pair = clientState()
    let initial = pair.client.geometry
    let added = pair.state.apply(pair.client.window, 1, esaFullscreen)
    check added.client.maxed
    check added.client.geometry == Geometry(x: 0, y: 0, width: 800, height: 600)
    check added.client.origGeometry == initial
    check added.effects.mapIt(it.kind) == @[
      weApplyEwmhGeometry, weMapClient, weSetInputFocus,
      wePublishActiveWindow, wePublishCurrentDesktop, weRestackLayers,
      wePublishEwmhState, wePublishStatus]
    check added.effects[0].maxed # C sets client border width to zero.
    let repeated = pair.state.apply(pair.client.window, 1, esaFullscreen)
    check repeated.client.maxed
    check repeated.client.origGeometry == initial
    let removed = pair.state.apply(pair.client.window, 0, esaFullscreen)
    check not removed.client.maxed
    check removed.client.geometry == initial
    check removed.effects.mapIt(it.kind) == @[
      weApplyEwmhGeometry, weRestackLayers, wePublishEwmhState,
      wePublishStatus, weMapClient, weSetInputFocus,
      wePublishActiveWindow, wePublishCurrentDesktop, weRaiseClient]

  test "axis maximize replaces special geometry and publishes canonical state":
    var pair = clientState()
    let horizontal = pair.state.apply(pair.client.window, 1, esaMaximizedHorz)
    check horizontal.client.hmaxed
    check horizontal.client.geometry == Geometry(x: 0, y: 50,
        width: 800, height: 120)
    check horizontal.effects.mapIt(it.kind) == @[
      weApplyEwmhGeometry, wePublishEwmhState, wePublishStatus]
    let vertical = pair.state.apply(pair.client.window, 1, esaMaximizedVert)
    check vertical.client.vmaxed and not vertical.client.hmaxed
    check vertical.client.origGeometry == Geometry(x: 40, y: 50,
        width: 200, height: 120)
    let remove = pair.state.apply(pair.client.window, 0, esaMaximizedVert)
    check not remove.client.vmaxed and remove.client.geometry == vertical.client.origGeometry
    check weSetInputFocus notin remove.effects.mapIt(it.kind)

  test "ordered two-atom processing preserves intermediate priority snapshots":
    var pair = clientState()
    let combo = pair.state.apply(pair.client.window, 1,
        esaAbove, esaFullscreen)
    check combo.client.layer == wlAbove and combo.client.maxed
    let restacks = combo.effects.filterIt(it.kind == weRestackLayers)
    check restacks.len == 2
    check restacks[0].stackingState[0].layer == wlAbove
    check not restacks[0].stackingState[0].maxed
    check restacks[1].stackingState[0].layer == wlAbove
    check restacks[1].stackingState[0].maxed
    let reverse = pair.state.apply(pair.client.window, 0,
        esaFullscreen, esaAbove)
    check not reverse.client.maxed and reverse.client.layer == wlNormal

  test "unsupported action and state atoms are no-ops for managed clients":
    var pair = clientState()
    let invalid = pair.state.apply(pair.client.window, 3, esaAbove)
    check invalid.client.layer == wlNormal and invalid.effects.len == 0
    let below = pair.state.apply(pair.client.window, 1, esaUnknown)
    check below.client == pair.client and below.effects.len == 0

  test "managed malformed formats consume the data32 payload; unmanaged requires format 32":
    var pair = clientState()
    let malformed = pair.state.apply(pair.client.window, 1, esaAbove,
        format = 8)
    check malformed.client.layer == wlAbove
    let unmanagedInput = WmInput(kind: wiEwmhWmState,
        window: WindowId(0x901), rootWindow: WindowId(0x1),
        ewmhAction: 1, ewmhFormat: 8, ewmhUnmanaged: true,
        ewmhStates: [esaAbove, esaUnknown], ewmhAboveAtom: 99,
        unmanagedStateAtoms: @[12'u32])
    let ignored = pair.state.transition(epoch, unmanagedInput)
    check ignored.effects.len == 0

  test "unmanaged Above changes preserve unrelated atom order and always enforce layers":
    var state = newWmState()
    let input = WmInput(kind: wiEwmhWmState, window: WindowId(0x902),
        rootWindow: WindowId(0x1), ewmhAction: 1, ewmhFormat: 32,
        ewmhUnmanaged: true, ewmhStates: [esaAbove, esaAbove],
        ewmhAboveAtom: 99, unmanagedStateAtoms: @[11'u32, 99, 12, 99])
    let result = state.transition(epoch, input)
    check result.effects.mapIt(it.kind) == @[
        weSetUnmanagedEwmhState, weSetUnmanagedEwmhState, weRestackLayers]
    check result.effects[0].stateAtoms == @[11'u32, 12, 99]
    check result.effects[1].stateAtoms == @[11'u32, 12, 99]

  test "destroyed post-cleanup and unknown managed targets do not create identity":
    var state = newWmState()
    let unknown = state.transition(epoch, WmInput(kind: wiEwmhWmState,
        window: WindowId(0xfeed), ewmhAction: 1,
        ewmhStates: [esaAbove, esaUnknown]))
    check not unknown.hasClient and unknown.effects.len == 0
