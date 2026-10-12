## X-free lifecycle, focus and group transitions. X requests are ordered effects.

import std/options
import ./[types, state]
import ./geometry as geometryMath
import ./stacking

const DefaultOuterBorderWidth* = 5'i32

type
  WmInputKind* = enum
    wiManageRequested, wiMapConfirmed, wiDecorationMapConfirmed,
    wiUnmapConfirmed, wiDecorationUnmapConfirmed, wiDestroyConfirmed,
    wiManagementFailed, wiFocusClient, wiFocusClientNoRaise,
    wiClearFocus, wiFocusLast,
    wiCycle, wiReverseCycle, wiCycleGroup, wiReverseCycleGroup,
    wiFocusReconcile, wiAssignGroup, wiRemoveGroup, wiActivateGroup,
    wiDeactivateGroup, wiSetLastWindowFocus, wiStartupFocus,
    wiCompleteStartupClient, wiMoveBy, wiMoveTo, wiResizeRelative,
    wiResizeAbsolute, wiConfigureRequest, wiStackCycle, wiSetLayer,
    wiLayerRestackFailed, wiLayerPublicationFailed, wiRaiseMany, wiCirculateRequest,
    wiEwmhWmState, wiEwmhActiveWindow,
    wiButtonPress, wiPointerMotion, wiButtonRelease,
    wiMaximizeHorizontal,
    wiMaximizeVertical, wiMaximizeFull, wiMonocle, wiResetGeometry
  WmInput* = object
    kind*: WmInputKind
    window*, decoration*, actualFocus*, rootWindow*: WindowId
    initialGroup*, group*: RawGroup
    hints*: ResizeHints
    clientId*: ClientId
    x*, y*: int16
    pointerX*, pointerY*: int16
    pointerState*, pointerTime*: uint32
    pointerButton*: uint8
    pointerLockMasks*: array[3, uint16]
    width*, height*: uint16
    deltaWidth*, deltaHeight*: int32
    geometryBounds*: geometryMath.GeometryBounds
    configureMask*: geometryMath.ConfigureMask
    configureValueMask*: uint16
    configureSibling*: WindowId
    configureStackMode*: uint8
    configureBorderWidth*: uint16
    circulatePlace*: uint8
    physicalBottomToTop*: seq[WindowId]
    ewmhAction*: uint32
    ewmhFormat*: uint8
    ewmhStates*: array[2, EwmhStateAtom]
    ewmhWindowExists*, ewmhDock*, ewmhUnmanaged*: bool
    ewmhAboveAtom*: uint32
    unmanagedStateAtoms*: seq[uint32]
    windows*: seq[WindowId]
    layer*: WindowLayer
    resizeHintsEnabled*: bool
    setByUser*, enabled*, centerOnPointer*: bool
  WmEffectKind* = enum
    weSelectClientEvents, weAddToSaveSet, weRemoveFromSaveSet,
    wePublishDesktop, weMapClient, weUnmapClient, weCreateDecoration,
    weMapDecoration, wePaintDecoration, wePlaceClientAboveDecoration,
    weUnmapDecoration, weDestroyDecoration,
    wePublishWmStateNormal, wePublishClientLists, weSetInputFocus,
    weCenterPointerOnClient,
    wePublishActiveWindow, wePublishCurrentDesktop, weRaiseClient,
    weInstallButtonGrabs, weAllowPointer, weGrabPointer, weUngrabPointer,
    wePublishActiveGroups, wePublishStatus, weMoveClient, weResizeClient,
    weConfigureDecoration, weConfigureRequest, weCirculateRequest,
    weRestackLayers, wePublishLayerState, weApplyEwmhGeometry,
    wePublishEwmhState, weSetUnmanagedEwmhState
  WmEffect* = object
    kind*: WmEffectKind
    window*, decoration*: WindowId
    group*: RawGroup
    groups*: seq[RawGroup]
    x*, y*: int16
    width*, height*: uint16
    geometry*: Geometry
    frameGeometry*: Geometry
    configureValueMask*: uint16
    configureSibling*: WindowId
    configureStackMode*: uint8
    configureBorderWidth*: uint16
    circulatePlace*: uint8
    stateAtoms*: seq[uint32]
    aboveAtom*: uint32
    outerColor*: uint32
    stackingState*: seq[StackingLayerSnapshot]
    resizeHints*: ResizeHints
    mapped*, setByUser*: bool
    maxed*, hmaxed*, vmaxed*, monocled*: bool
    layer*: WindowLayer
    previousLayer*: WindowLayer
    previousLayerExplicit*, restoreLayerOnFailure*, ignoreFailure*: bool
    activationRaise*: bool
    pointerAllowMode*: PointerAllowMode
    pointerTime*: uint32
    pointerModifier*: uint16
    pointerLockMasks*: array[3, uint16]
  TransitionResult* = object
    client*: ClientState
    hasClient*, created*, removed*: bool
    effects*: seq[WmEffect]

proc effect(kind: WmEffectKind; window: WindowId;
            decoration = WindowId(0); group = NullGroup;
            x = 0'i16; y = 0'i16; width = 0'u16; height = 0'u16): WmEffect =
  WmEffect(kind: kind, window: window, decoration: decoration, group: group,
           x: x, y: y, width: width, height: height)

proc groupEffect(state: WmState; window: WindowId): WmEffect =
  result = WmEffect(kind: wePublishActiveGroups, window: window)
  for index, active in state.activeGroups:
    if active: result.groups.add(RawGroup(index))

proc statusEffect(client: ClientState): WmEffect =
  WmEffect(kind: wePublishStatus, window: client.window,
      group: client.group, x: client.x, y: client.y,
      width: client.width, height: client.height,
      mapped: client.mapped, setByUser: client.setByUser,
      resizeHints: client.resizeHints, maxed: client.maxed,
      hmaxed: client.hmaxed, vmaxed: client.vmaxed, monocled: client.monocled)

proc paintEffect(client: ClientState; focused: bool): WmEffect =
  WmEffect(kind: wePaintDecoration, window: client.window,
      decoration: client.decoration.get, geometry: client.geometry,
      outerColor: if focused: 0xff97a293'u32 else: 0xff393638'u32)

proc geometryEffects(client: ClientState; moveClient, resizeClient: bool;
                     bounds: geometryMath.GeometryBounds; focused: bool): seq[WmEffect] =
  if moveClient:
    result.add(WmEffect(kind: weMoveClient, window: client.window,
        geometry: client.geometry))
  if resizeClient:
    result.add(WmEffect(kind: weResizeClient, window: client.window,
        geometry: client.geometry))
  if client.decoration.isSome and client.mapped:
    let derived = geometryMath.decorationGeometry(client.geometry,
        DefaultOuterBorderWidth)
    if not geometryMath.decorationClipWouldFailC(derived, bounds):
      let frame = geometryMath.fitDecoration(derived, bounds)
      result.add(WmEffect(kind: weConfigureDecoration, window: client.window,
          decoration: client.decoration.get, geometry: frame))
      result.add(paintEffect(client, focused))
  result.add(statusEffect(client))

proc resetGeometry(state: var WmState; client: var ClientState) =
  client.geometry = client.origGeometry
  client.maxed = false
  client.hmaxed = false
  client.vmaxed = false
  client.monocled = false
  discard state.replaceClient(client)

proc focusEffects(state: var WmState; id: ClientId;
                  raiseClient: bool): seq[WmEffect]

proc ewmhGeometryEffects(client: ClientState;
                         bounds: geometryMath.GeometryBounds;
                         focused: bool; zeroBorder = false): seq[WmEffect] =
  var geometry = WmEffect(kind: weApplyEwmhGeometry,
      window: client.window, geometry: client.geometry, maxed: zeroBorder)
  if client.decoration.isSome and client.mapped:
    let derived = geometryMath.decorationGeometry(client.geometry,
        DefaultOuterBorderWidth)
    if not geometryMath.decorationClipWouldFailC(derived, bounds):
      geometry.decoration = client.decoration.get
      geometry.frameGeometry = geometryMath.fitDecoration(derived, bounds)
  result.add(geometry)
  if geometry.decoration.raw != 0:
    result.add(paintEffect(client, focused))

proc ewmhStatePropertyEffect(client: ClientState): WmEffect =
  WmEffect(kind: wePublishEwmhState, window: client.window,
      layer: client.layer, maxed: client.maxed,
      hmaxed: client.hmaxed, vmaxed: client.vmaxed)

proc ewmhRestackEffect(state: WmState; window: WindowId): WmEffect =
  result = WmEffect(kind: weRestackLayers, window: window)
  for client in state.clientsInManagedOrder():
    result.stackingState.add(StackingLayerSnapshot(
        window: client.window,
        decoration: if client.decoration.isSome: client.decoration.get else: WindowId(0),
        layer: client.layer, maxed: client.maxed, monocled: client.monocled))

proc resetForEwmh(state: var WmState; client: var ClientState;
                  bounds: geometryMath.GeometryBounds;
                  effects: var seq[WmEffect]) =
  if not (client.maxed or client.hmaxed or client.vmaxed or client.monocled):
    return
  state.resetGeometry(client)
  for geometryEffect in client.ewmhGeometryEffects(bounds,
      state.focusedId.isSome and state.focusedId.get == client.id):
    effects.add(geometryEffect)
  effects.add(state.ewmhRestackEffect(client.window))
  effects.add(ewmhStatePropertyEffect(client))
  effects.add(statusEffect(client))

proc applyEwmhMaximize(state: var WmState; client: var ClientState;
                       kind: WmInputKind; bounds: geometryMath.GeometryBounds;
                       effects: var seq[WmEffect]) =
  state.resetForEwmh(client, bounds, effects)
  client.origGeometry = client.geometry
  case kind
  of wiMaximizeFull:
    client.geometry = Geometry(x: bounds.x, y: bounds.y,
        width: uint32(max(0, bounds.width)),
        height: uint32(max(0, bounds.height)))
    client.maxed = true
  of wiMaximizeHorizontal:
    client.geometry.x = bounds.x + bounds.gapLeft
    client.geometry.width = uint32(max(0, bounds.width - bounds.gapLeft -
        bounds.gapRight - 2 * bounds.borderExtent))
    client.hmaxed = true
  of wiMaximizeVertical:
    client.geometry.y = bounds.y + bounds.gapTop
    client.geometry.height = uint32(max(0, bounds.height - bounds.gapTop -
        bounds.gapBottom - 2 * bounds.borderExtent))
    client.vmaxed = true
  else:
    return
  discard state.replaceClient(client)
  for geometryEffect in client.ewmhGeometryEffects(bounds,
      state.focusedId.isSome and state.focusedId.get == client.id,
      kind == wiMaximizeFull):
    effects.add(geometryEffect)
  if kind == wiMaximizeFull:
    effects.add(state.focusEffects(client.id, false))
    effects.add(state.ewmhRestackEffect(client.window))
  effects.add(ewmhStatePropertyEffect(client))
  effects.add(statusEffect(client))

proc resetEwmhMaximize(state: var WmState; client: var ClientState;
                       focusAndRaise: bool;
                       bounds: geometryMath.GeometryBounds;
                       effects: var seq[WmEffect]) =
  state.resetGeometry(client)
  for geometryEffect in client.ewmhGeometryEffects(bounds,
      state.focusedId.isSome and state.focusedId.get == client.id):
    effects.add(geometryEffect)
  effects.add(state.ewmhRestackEffect(client.window))
  effects.add(ewmhStatePropertyEffect(client))
  effects.add(statusEffect(client))
  if focusAndRaise:
    effects.add(state.focusEffects(client.id, true))

proc applyUnmanagedAbove(input: WmInput; stateAtoms: var seq[uint32];
                         effects: var seq[WmEffect]) =
  if input.ewmhAction > 2: return
  let present = input.ewmhAboveAtom in stateAtoms
  let above = input.ewmhAction == 1 or
      (input.ewmhAction == 2 and not present)
  var next: seq[uint32]
  for atom in stateAtoms:
    if atom != input.ewmhAboveAtom: next.add(atom)
  if above: next.add(input.ewmhAboveAtom)
  stateAtoms = next
  effects.add(WmEffect(kind: weSetUnmanagedEwmhState,
      window: input.window, aboveAtom: input.ewmhAboveAtom,
      stateAtoms: stateAtoms))

proc applyManagedEwmhAtom(state: var WmState; client: var ClientState;
                          input: WmInput; atom: EwmhStateAtom;
                          effects: var seq[WmEffect]) =
  case atom
  of esaAbove:
    if client.layerExplicit or not input.ewmhWindowExists: return
    var layer = client.layer
    case input.ewmhAction
    of 0: layer = if input.ewmhDock: wlAbove else: wlNormal
    of 1: layer = wlAbove
    of 2:
      layer = if client.layer == wlAbove and not input.ewmhDock:
          wlNormal else: wlAbove
    else: return
    let previousLayer = client.layer
    let previousExplicit = client.layerExplicit
    client.layer = layer
    client.layerExplicit = false
    discard state.replaceClient(client)
    effects.add(state.ewmhRestackEffect(client.window))
    effects[^1].layer = layer
    effects[^1].previousLayer = previousLayer
    effects[^1].previousLayerExplicit = previousExplicit
    effects[^1].restoreLayerOnFailure = true
    effects.add(WmEffect(kind: wePublishLayerState, window: client.window,
        layer: layer, previousLayer: previousLayer,
        previousLayerExplicit: previousExplicit, restoreLayerOnFailure: true))
  of esaFullscreen, esaMaximizedVert, esaMaximizedHorz:
    if input.ewmhAction > 2: return
    let mode = case atom
      of esaFullscreen: wiMaximizeFull
      of esaMaximizedVert: wiMaximizeVertical
      of esaMaximizedHorz: wiMaximizeHorizontal
      else: wiResetGeometry
    let active = case atom
      of esaFullscreen: client.maxed
      of esaMaximizedVert: client.vmaxed
      of esaMaximizedHorz: client.hmaxed
      else: false
    if input.ewmhAction == 1 or
        (input.ewmhAction == 2 and not active):
      state.applyEwmhMaximize(client, mode, input.geometryBounds, effects)
    elif active:
      state.resetEwmhMaximize(client, atom == esaFullscreen,
          input.geometryBounds, effects)
  of esaUnknown:
    discard

proc applySpecialGeometry(state: var WmState; client: var ClientState;
                          mode: WmInputKind;
                          bounds: geometryMath.GeometryBounds): bool =
  let sameMode = (mode == wiMaximizeHorizontal and client.hmaxed) or
      (mode == wiMaximizeVertical and client.vmaxed) or
      (mode == wiMaximizeFull and client.maxed) or
      (mode == wiMonocle and client.monocled)
  if sameMode:
    state.resetGeometry(client)
    result = true
    return
  if client.maxed or client.hmaxed or client.vmaxed or client.monocled:
    state.resetGeometry(client)
  client.origGeometry = client.geometry
  case mode
  of wiMaximizeHorizontal:
    client.geometry.x = bounds.x + bounds.gapLeft
    client.geometry.width = uint32(max(0, bounds.width - bounds.gapLeft -
        bounds.gapRight - 2 * bounds.borderExtent))
    client.hmaxed = true
  of wiMaximizeVertical:
    client.geometry.y = bounds.y + bounds.gapTop
    client.geometry.height = uint32(max(0, bounds.height - bounds.gapTop -
        bounds.gapBottom - 2 * bounds.borderExtent))
    client.vmaxed = true
  of wiMaximizeFull:
    client.geometry.x = bounds.x
    client.geometry.y = bounds.y
    client.geometry.width = uint32(max(0, bounds.width))
    client.geometry.height = uint32(max(0, bounds.height))
    client.maxed = true
  of wiMonocle:
    client.geometry.x = bounds.x + bounds.gapLeft
    client.geometry.y = bounds.y + bounds.gapTop
    client.geometry.width = uint32(max(0, bounds.width - 2 * bounds.borderExtent -
        bounds.gapLeft - bounds.gapRight))
    client.geometry.height = uint32(max(0, bounds.height - 2 * bounds.borderExtent -
        bounds.gapTop - bounds.gapBottom))
    client.monocled = true
  else:
    return
  discard state.replaceClient(client)
  result = true

proc focusEffects(state: var WmState; id: ClientId;
                  raiseClient: bool): seq[WmEffect] =
  let found = state.lookup(id)
  if found.isNone: return
  let client = found.get
  let previous = state.focusedClient
  state.setFocused(id)
  if client.decoration.isSome:
    result.add(effect(weMapDecoration, client.window, client.decoration.get))
  result.add(effect(weMapClient, client.window))
  if client.decoration.isSome and client.mapped and not client.maxed:
    result.add(paintEffect(client, true))
  result.add(effect(weSetInputFocus, client.window))
  result.add(effect(wePublishActiveWindow, client.window))
  if previous.isSome and previous.get.id != id and previous.get.mapped and
      previous.get.decoration.isSome:
    result.add(paintEffect(previous.get, false))
  result.add(effect(wePublishCurrentDesktop, client.window, group = client.group))
  if state.pointerModifier != 0:
    result.add(WmEffect(kind: weInstallButtonGrabs, window: client.window,
        pointerModifier: state.pointerModifier,
        pointerLockMasks: state.pointerLockMasks))
  if raiseClient:
    result.add(effect(weRaiseClient, client.window,
        decoration = if client.decoration.isSome: client.decoration.get else: WindowId(0)))

proc chooseLast(state: WmState): Option[ClientId] =
  let order = state.focusOrderClients
  if order.len == 0: return none(ClientId)
  let start = if order.len > 1: 1 else: 0
  for index in start ..< order.len:
    if order[index].mapped: return some(order[index].id)
  none(ClientId)

proc cycleTarget(state: WmState; reverse, sameGroup: bool): Option[ClientId] =
  let ordered = state.clientsInManagedOrder
  let count = ordered.len
  if count < 2: return none(ClientId)
  let focused = state.focusedId
  if sameGroup and focused.isNone: return none(ClientId)
  var index = -1
  if focused.isSome:
    for itemIndex, client in ordered:
      if client.id == focused.get: index = itemIndex
  if index < 0: index = if reverse: count - 1 else: 0
  let anchorGroup = if focused.isSome: state.lookup(focused.get).get.group else: NullGroup
  for offset in 1 .. count:
    let candidate = if reverse:
      (index - offset + count * 2) mod count
    else:
      (index + offset) mod count
    let client = ordered[candidate]
    if client.mapped and (not sameGroup or client.group == anchorGroup) and
        (focused.isNone or client.id != focused.get):
      return some(client.id)
  none(ClientId)

proc transition*(state: var WmState; epoch: ProcessEpoch;
                 input: WmInput): TransitionResult =
  case input.kind
  of wiCirculateRequest:
    # Frozen C forwards every CirculateRequest without managed lookup or
    # logical stacking/focus changes. The intentionally reversed XCB call
    # mapping is kept explicit in the effect's typed payload.
    result.effects.add(WmEffect(kind: weCirculateRequest,
        window: input.window, circulatePlace: input.circulatePlace))
  of wiEwmhWmState:
    if input.ewmhUnmanaged:
      if input.ewmhFormat != 32 or input.window == input.rootWindow: return
      var atoms = input.unmanagedStateAtoms
      for atom in input.ewmhStates:
        if atom == esaAbove:
          input.applyUnmanagedAbove(atoms, result.effects)
      # Frozen C enforces layers once after both slots, even when neither
      # slot changes the unmanaged window's state.
      result.effects.add(WmEffect(kind: weRestackLayers))
      return
    let target = state.lookup(input.window)
    if target.isNone: return
    var client = target.get
    for atom in input.ewmhStates:
      state.applyManagedEwmhAtom(client, input, atom, result.effects)
      client = state.lookup(target.get.id).get
    result.client = client
    result.hasClient = true
  of wiEwmhActiveWindow:
    # Frozen C resolves the target through its managed list and calls
    # set_focused(client), regardless of ClientMessage format or payload.
    # Reuse the same model focus transition and ordered focus/raise effects.
    let target = state.lookup(input.window)
    if target.isSome:
      result.client = target.get
      result.hasClient = true
      result.effects = state.focusEffects(result.client.id, true)
      # C submits focus/map/raise X requests unchecked and continues through
      # later requests when a stale managed XID has already been destroyed.
      for index in 0 ..< result.effects.len:
        result.effects[index].ignoreFailure = true
        if result.effects[index].kind == weRaiseClient:
          result.effects[index].activationRaise = true
  of wiButtonPress:
    let target = state.lookup(input.window)
    if target.isNone:
      result.effects.add(WmEffect(kind: weAllowPointer, pointerAllowMode: pamSyncPointer,
          pointerTime: input.pointerTime))
      return
    let client = target.get
    result.client = client
    result.hasClient = true
    if input.pointerButton in 1'u8..3'u8:
      let lockMask = input.pointerLockMasks[0] or input.pointerLockMasks[1] or
          input.pointerLockMasks[2]
      let cleanState = uint16(input.pointerState and 0xffff'u32) and not lockMask
      if cleanState == 0:
        result.effects.add(WmEffect(kind: weRaiseClient, window: client.window,
            decoration: WindowId(0)))
        if state.focusedId.isNone or state.focusedId.get != client.id:
          result.effects.add(state.focusEffects(client.id, true))
        # Frozen C replays the click after its focus/raise work when replay is
        # enabled. The passive synchronous grab must always be released.
        result.effects.add(WmEffect(kind: weAllowPointer, pointerAllowMode: pamReplayPointer,
            pointerTime: input.pointerTime))
      elif cleanState == state.pointerModifier:
        # C raises the client through configure_window_stacking before it
        # checks is_special(); maximized clients stop here without an active
        # pointer grab. Keep the first raise layer-aware but client-only.
        result.effects.add(WmEffect(kind: weRaiseClient, window: client.window,
            decoration: WindowId(0)))
        if client.maxed or client.hmaxed or client.vmaxed or client.monocled:
          result.effects.add(WmEffect(kind: weAllowPointer, pointerAllowMode: pamSyncPointer,
              pointerTime: input.pointerTime))
          return
        let operation = case input.pointerButton
          of 1: poMove
          of 2: poResizeSide
          else: poResizeCorner
        state.pointerInteraction = PointerInteraction(operation: operation,
            clientId: client.id, startX: input.pointerX, startY: input.pointerY,
            startGeometry: client.geometry, button: input.pointerButton,
            active: true)
        result.effects.add(WmEffect(kind: weGrabPointer, window: client.window,
            pointerTime: input.pointerTime))
      else:
        result.effects.add(WmEffect(kind: weAllowPointer, pointerAllowMode: pamSyncPointer,
            pointerTime: input.pointerTime))
    else:
      result.effects.add(WmEffect(kind: weAllowPointer, pointerAllowMode: pamSyncPointer,
          pointerTime: input.pointerTime))
  of wiPointerMotion:
    let interaction = state.pointerInteraction
    if interaction.operation == poNone or not interaction.active: return
    let target = state.lookup(interaction.clientId)
    if target.isNone:
      state.pointerInteraction = PointerInteraction()
      result.effects.add(WmEffect(kind: weUngrabPointer, pointerTime: input.pointerTime))
      result.effects.add(WmEffect(kind: weAllowPointer, pointerAllowMode: pamSyncPointer,
          pointerTime: input.pointerTime))
      return
    var client = target.get
    let dx = int32(input.pointerX - interaction.startX)
    let dy = int32(input.pointerY - interaction.startY)
    let start = interaction.startGeometry
    case interaction.operation
    of poMove:
      client.geometry.x = start.x + dx
      client.geometry.y = start.y + dy
      result.effects.add(WmEffect(kind: weMoveClient, window: client.window,
          geometry: client.geometry))
    of poResizeSide, poResizeCorner:
      # Handle selection follows input.c's root-coordinate classification.
      let left = interaction.startX < int32(start.x) + int32(start.width div 2)
      let top = interaction.startY < int32(start.y) + int32(start.height div 2)
      var handle: int
      if interaction.operation == poResizeSide:
        let px = int32(interaction.startX) - start.x
        let py = int32(interaction.startY) - start.y
        let leftOfA = px * int32(start.height) < int32(start.width) * py
        let leftOfB = (int32(start.width) - px) * int32(start.height) > int32(start.width) * py
        if leftOfA:
          handle = if leftOfB: 2 else: 1
        else:
          handle = if leftOfB: 0 else: 3
      else:
        handle = if top: (if left: 6 else: 7) else: (if left: 4 else: 5)
      var geom = start
      if handle in [2, 4, 6]:
        geom.x = start.x + dx
        geom.width = uint32(max(int32(client.resizeHints.minWidth), int32(start.width) - dx))
        if geom.width == client.resizeHints.minWidth: geom.x = client.geometry.x
      if handle in [1, 4, 5]:
        geom.height = uint32(max(int32(client.resizeHints.minHeight), int32(start.height) + dy))
        if geom.height == client.resizeHints.minHeight: geom.y = client.geometry.y
      if handle in [0, 6, 7]:
        geom.y = start.y + dy
        geom.height = uint32(max(int32(client.resizeHints.minHeight), int32(start.height) - dy))
        if geom.height == client.resizeHints.minHeight: geom.y = client.geometry.y
      if handle in [3, 5, 7]:
        geom.width = uint32(max(int32(client.resizeHints.minWidth), int32(start.width) + dx))
        if geom.width == client.resizeHints.minWidth: geom.x = client.geometry.x
      if geom.width == client.geometry.width and geom.height == client.geometry.height and geom.x == client.geometry.x and geom.y == client.geometry.y: return
      client.geometry = geom
      result.effects = client.geometryEffects(true, true, input.geometryBounds,
          state.focusedId.isSome and state.focusedId.get == client.id)
      if result.effects.len >= 2:
        swap(result.effects[0], result.effects[1])
    of poNone: return
    discard state.replaceClient(client)
    result.client = client
    result.hasClient = true
  of wiButtonRelease:
    if state.pointerInteraction.operation != poNone:
      state.pointerInteraction = PointerInteraction()
      result.effects.add(WmEffect(kind: weUngrabPointer, pointerTime: input.pointerTime))
      result.effects.add(WmEffect(kind: weAllowPointer, pointerAllowMode: pamSyncPointer,
          pointerTime: input.pointerTime))
  of wiManageRequested:
    if state.contains(input.window):
      let current = state.lookup(input.window).get
      result.client = current
      result.hasClient = true
      if current.runtimeManaged:
        result.effects.add(effect(weMapClient, input.window))
        if current.decoration.isSome:
          result.effects.add(effect(weMapDecoration, input.window, current.decoration.get))
        result.effects.add(effect(wePublishWmStateNormal, input.window))
        result.effects.add(WmEffect(kind: weCenterPointerOnClient,
            window: input.window, width: uint16(min(current.geometry.width, uint32(high(uint16)))),
            height: uint16(min(current.geometry.height, uint32(high(uint16))))))
        result.effects.add(statusEffect(current))
        result.effects.add(effect(wePublishClientLists, input.window))
      return
    let added = state.addRuntimeClient(epoch, input.window, input.decoration,
        input.initialGroup, input.x, input.y, input.width, input.height,
        input.setByUser, input.hints)
    result.client = added.state
    result.hasClient = true
    result.created = added.created
    if not added.created: return
    var managed = added.state
    if input.centerOnPointer:
      managed.geometry.x = int32(cast[int16](int32(input.pointerX) -
          int32(managed.geometry.width div 2)))
      managed.geometry.y = int32(cast[int16](int32(input.pointerY) -
          int32(managed.geometry.height div 2)))
      discard state.replaceClient(managed)
      result.client = managed
    managed.layer = input.layer
    discard state.replaceClient(managed)
    result.client = managed
    result.effects.add(effect(weSelectClientEvents, input.window))
    result.effects.add(effect(weAddToSaveSet, input.window))
    if input.centerOnPointer:
      result.effects.add(WmEffect(kind: weMoveClient, window: input.window,
          geometry: managed.geometry))
    result.effects.add(effect(wePublishDesktop, input.window, group = NullGroup))
    result.effects.add(effect(wePublishDesktop, input.window, group = input.initialGroup))
    result.effects.add(groupEffect(state, input.window))
    result.effects.add(statusEffect(managed))
    result.effects.add(effect(weMapClient, input.window))
    if input.geometryBounds.width > 0 and input.geometryBounds.height > 0:
      let fitted = geometryMath.fitConfigure(managed.geometry,
          managed.resizeHints, input.geometryBounds)
      if fitted != managed.geometry:
        let moved = fitted.x != managed.geometry.x or fitted.y != managed.geometry.y
        let resized = fitted.width != managed.geometry.width or
            fitted.height != managed.geometry.height
        managed.geometry = fitted
        discard state.replaceClient(managed)
        result.client = managed
        if moved:
          result.effects.add(WmEffect(kind: weMoveClient, window: input.window,
              geometry: fitted))
        if resized:
          result.effects.add(WmEffect(kind: weResizeClient, window: input.window,
              geometry: fitted))
    let border = DefaultOuterBorderWidth
    result.effects.add(effect(weCreateDecoration, input.window, input.decoration,
        x = int16(managed.geometry.x - border), y = int16(managed.geometry.y - border),
        width = uint16(managed.geometry.width + uint32(border * 2)),
        height = uint16(managed.geometry.height + uint32(border * 2))))
    result.effects.add(effect(weMapDecoration, input.window, input.decoration))
    result.effects.add(effect(wePublishWmStateNormal, input.window))
    result.effects.add(WmEffect(kind: weCenterPointerOnClient,
        window: input.window,
        width: uint16(min(managed.geometry.width, uint32(high(uint16)))),
        height: uint16(min(managed.geometry.height, uint32(high(uint16))))))
    result.effects.add(effect(wePublishClientLists, input.window))
    if managed.layer != wlNormal:
      result.effects.add(WmEffect(kind: weRestackLayers, window: managed.window,
          layer: managed.layer))
      result.effects.add(WmEffect(kind: wePublishLayerState, window: managed.window,
          layer: managed.layer))
  of wiMapConfirmed:
    let confirmed = state.confirmMap(input.window)
    if confirmed.known:
      result.client = state.lookup(input.window).get
      result.hasClient = true
      if confirmed.autofocus:
        result.effects.add(state.focusEffects(result.client.id, true))
      result.effects.add(statusEffect(result.client))
  of wiDecorationMapConfirmed, wiDecorationUnmapConfirmed:
    discard
  of wiUnmapConfirmed:
    let confirmed = state.confirmUnmap(input.window)
    if confirmed.known:
      result.client = state.lookup(input.window).get
      result.hasClient = true
      if state.pointerInteraction.operation != poNone and
          state.pointerInteraction.clientId == result.client.id:
        state.pointerInteraction = PointerInteraction()
        result.effects.add(WmEffect(kind: weUngrabPointer))
        result.effects.add(WmEffect(kind: weAllowPointer, pointerAllowMode: pamSyncPointer))
      if result.client.decoration.isSome:
        result.effects.add(effect(weUnmapDecoration, input.window, result.client.decoration.get))
      if confirmed.wasFocused:
        state.clearFocused()
        result.effects.add(effect(weSetInputFocus, WindowId(0)))
        result.effects.add(effect(wePublishActiveWindow, WindowId(0)))
        result.effects.add(effect(wePublishCurrentDesktop, WindowId(0), group = NullGroup))
        if not confirmed.groupPending and state.lastWindowFocus:
          let last = state.chooseLast
          if last.isSome: result.effects.add(state.focusEffects(last.get, true))
      result.effects.add(effect(wePublishClientLists, input.window))
      result.effects.add(statusEffect(result.client))
  of wiDestroyConfirmed:
    let existing = state.lookup(input.window)
    if existing.isSome:
      if state.pointerInteraction.operation != poNone and
          state.pointerInteraction.clientId == existing.get.id:
        state.pointerInteraction = PointerInteraction()
        result.effects.add(WmEffect(kind: weUngrabPointer))
        result.effects.add(WmEffect(kind: weAllowPointer, pointerAllowMode: pamSyncPointer))
      let focused = state.focusedId.isSome and state.focusedId.get == existing.get.id
      if focused:
        state.clearFocused()
        result.effects.add(effect(weSetInputFocus, WindowId(0)))
        result.effects.add(effect(wePublishActiveWindow, WindowId(0)))
        result.effects.add(effect(wePublishCurrentDesktop, WindowId(0), group = NullGroup))
      result.client = existing.get
      result.hasClient = true
      result.removed = state.removeIdentity(input.window)
      if result.removed:
        if result.client.group != NullGroup and result.client.group.raw < state.groupCount:
          state.activeGroups[int(result.client.group.raw)] =
              state.groupClients(result.client.group).len > 0
        if result.client.decoration.isSome:
          result.effects.add(effect(weDestroyDecoration, input.window, result.client.decoration.get))
        if focused and state.lastWindowFocus:
          let last = state.chooseLast
          if last.isSome: result.effects.add(state.focusEffects(last.get, true))
        result.effects.add(effect(wePublishClientLists, input.window))
        result.effects.add(groupEffect(state, input.window))
  of wiManagementFailed:
    let existing = state.lookup(input.window)
    if existing.isSome:
      result.client = existing.get
      result.hasClient = true
      result.removed = state.removeIdentity(input.window)
      if result.removed:
        result.effects.add(effect(weUnmapClient, input.window))
        if result.client.decoration.isSome:
          result.effects.add(effect(weDestroyDecoration, input.window, result.client.decoration.get))
        result.effects.add(effect(weRemoveFromSaveSet, input.window))
        result.effects.add(effect(wePublishClientLists, input.window))
  of wiFocusClient, wiFocusClientNoRaise:
    let target = if input.clientId != ClientId(0): state.lookup(input.clientId) else: state.lookup(input.window)
    if target.isSome:
      result.client = target.get
      result.hasClient = true
      result.effects = state.focusEffects(result.client.id,
          input.kind == wiFocusClient)
  of wiClearFocus:
    let previous = state.focusedClient
    if previous.isSome and previous.get.mapped and not previous.get.maxed and
        previous.get.decoration.isSome:
      result.effects.add(paintEffect(previous.get, false))
    state.clearFocused()
    result.effects.add(effect(weSetInputFocus, WindowId(0)))
    result.effects.add(effect(wePublishActiveWindow, WindowId(0)))
    result.effects.add(effect(wePublishCurrentDesktop, WindowId(0), group = NullGroup))
  of wiFocusLast, wiCycle, wiReverseCycle, wiCycleGroup, wiReverseCycleGroup:
    let target = if input.kind == wiFocusLast: state.chooseLast else:
        state.cycleTarget(input.kind in {wiReverseCycle, wiReverseCycleGroup},
                          input.kind in {wiCycleGroup, wiReverseCycleGroup})
    if target.isSome: result.effects = state.focusEffects(target.get, true)
  of wiStackCycle:
    let observed = stacking.StackObservation(
        managedBottomToTop: input.physicalBottomToTop)
    let closure = state.overlapClosure(observed, input.window)
    let target = state.cycleTarget(closure, input.window)
    if target.isSome:
      result.client = target.get
      result.hasClient = true
      result.effects = state.focusEffects(target.get.id, true)
  of wiRaiseMany:
    var seen: seq[WindowId]
    var clients: seq[ClientState]
    for window in input.windows:
      let found = state.lookup(window)
      if found.isNone or not found.get.mapped or window in seen:
        return
      if window notin input.physicalBottomToTop:
        return
      if found.get.decoration.isSome and
          found.get.decoration.get notin input.physicalBottomToTop:
        return
      seen.add(window)
      clients.add(found.get)
    for client in clients:
      result.effects.add(effect(weRaiseClient, client.window,
          decoration = if client.decoration.isSome: client.decoration.get else: WindowId(0)))
  of wiSetLayer:
    let target = state.lookup(input.window)
    if target.isSome:
      var client = target.get
      client.layer = input.layer
      client.layerExplicit = true
      discard state.replaceClient(client)
      result.client = client
      result.hasClient = true
      result.effects.add(WmEffect(kind: weRestackLayers, window: client.window,
          layer: client.layer, previousLayer: target.get.layer,
          previousLayerExplicit: target.get.layerExplicit,
          restoreLayerOnFailure: true))
      result.effects.add(WmEffect(kind: wePublishLayerState, window: client.window,
          layer: client.layer))
  of wiLayerRestackFailed:
    let target = state.lookup(input.window)
    if target.isSome:
      var client = target.get
      client.layer = input.layer
      client.layerExplicit = input.enabled
      discard state.replaceClient(client)
      result.client = client
      result.hasClient = true
      result.effects.add(WmEffect(kind: weRestackLayers, window: client.window,
          layer: client.layer))
  of wiLayerPublicationFailed:
    let target = state.lookup(input.window)
    if target.isSome:
      var client = target.get
      client.layer = input.layer
      client.layerExplicit = input.enabled
      discard state.replaceClient(client)
      result.client = client
      result.hasClient = true
      result.effects.add(WmEffect(kind: weRestackLayers, window: client.window,
          layer: client.layer))
      result.effects.add(WmEffect(kind: wePublishLayerState,
          window: client.window, layer: client.layer, ignoreFailure: true))
  of wiFocusReconcile:
    if input.actualFocus == input.rootWindow or input.actualFocus == WindowId(0):
      if state.focusedId.isSome:
        let previous = state.focusedClient
        if previous.isSome and previous.get.mapped and not previous.get.maxed and
            previous.get.decoration.isSome:
          result.effects.add(paintEffect(previous.get, false))
        state.clearFocused()
        result.effects.add(effect(weSetInputFocus, input.rootWindow))
        result.effects.add(effect(wePublishActiveWindow, WindowId(0)))
        result.effects.add(effect(wePublishCurrentDesktop, WindowId(0), group = NullGroup))
    else:
      let target = state.lookup(input.actualFocus)
      if target.isSome and (state.focusedId.isNone or state.focusedId.get != target.get.id):
        result.client = target.get
        result.hasClient = true
        result.effects = state.focusEffects(target.get.id, false)
  of wiAssignGroup, wiRemoveGroup:
    let target = if input.clientId != ClientId(0): state.lookup(input.clientId)
                 else: state.lookup(input.window)
    if target.isSome:
      let targetId = target.get.id
      let oldGroup = target.get.group
      let group = if input.kind == wiRemoveGroup: NullGroup else: input.group
      if state.setClientGroup(targetId, group):
        if oldGroup != NullGroup and oldGroup.raw < state.groupCount:
          state.activeGroups[int(oldGroup.raw)] = state.groupClients(oldGroup).len > 0
        result.client = state.lookup(targetId).get
        result.hasClient = true
        result.effects.add(effect(wePublishDesktop, result.client.window, group = group))
        result.effects.add(statusEffect(result.client))
        result.effects.add(groupEffect(state, result.client.window))
        if state.focusedId.isSome and state.focusedId.get == targetId:
          result.effects.add(effect(wePublishCurrentDesktop, result.client.window, group = group))
  of wiActivateGroup:
    if input.group.raw < state.groupCount and not state.activeGroups[int(input.group.raw)]:
      let members = state.groupClients(input.group)
      if members.len > 0:
        for client in members:
          if not client.mapped:
            state.setGroupMapPending(client.window, true)
            if client.decoration.isSome:
              result.effects.add(effect(weMapDecoration, client.window, client.decoration.get))
            result.effects.add(effect(weMapClient, client.window))
        state.activeGroups[int(input.group.raw)] = true
        result.effects.add(groupEffect(state, WindowId(0)))
  of wiDeactivateGroup:
    if input.group.raw < state.groupCount and state.activeGroups[int(input.group.raw)]:
      let focused = state.focusedClient
      if focused.isSome and focused.get.group == input.group:
        if focused.get.mapped and not focused.get.maxed and focused.get.decoration.isSome:
          result.effects.add(paintEffect(focused.get, false))
        state.clearFocused()
        result.effects.add(effect(weSetInputFocus, WindowId(0)))
        result.effects.add(effect(wePublishActiveWindow, WindowId(0)))
        result.effects.add(effect(wePublishCurrentDesktop, WindowId(0), group = NullGroup))
      for client in state.groupClients(input.group):
        if client.mapped:
          state.setGroupUnmapPending(client.window, true)
          if client.decoration.isSome:
            result.effects.add(effect(weUnmapDecoration, client.window, client.decoration.get))
          result.effects.add(effect(weUnmapClient, client.window))
      state.activeGroups[int(input.group.raw)] = false
      result.effects.add(groupEffect(state, WindowId(0)))
  of wiSetLastWindowFocus:
    state.lastWindowFocus = input.enabled
  of wiStartupFocus:
    let target = state.lookup(input.actualFocus)
    if target.isSome and target.get.mapped:
      state.setFocused(target.get.id)
      result.client = target.get
      result.hasClient = true
      if target.get.decoration.isSome:
        result.effects.add(paintEffect(target.get, true))
      result.effects.add(effect(wePublishActiveWindow, target.get.window))
      result.effects.add(effect(wePublishCurrentDesktop, target.get.window, group = target.get.group))
      if state.pointerModifier != 0:
        result.effects.add(WmEffect(kind: weInstallButtonGrabs,
            window: target.get.window, pointerModifier: state.pointerModifier,
            pointerLockMasks: state.pointerLockMasks))
  of wiCompleteStartupClient:
    let completed = state.completeStartupClient(input.window, input.decoration,
        input.x, input.y, input.width, input.height, input.setByUser)
    if completed.isSome:
      result.client = completed.get
      result.hasClient = true
      result.effects.add(effect(weSelectClientEvents, input.window))
      result.effects.add(effect(weAddToSaveSet, input.window))
      result.effects.add(effect(wePublishDesktop, input.window, group = completed.get.group))
      let border = DefaultOuterBorderWidth
      result.effects.add(effect(weCreateDecoration, input.window, input.decoration,
          x = int16(int32(input.x) - border), y = int16(int32(input.y) - border),
          width = uint16(uint32(input.width) + uint32(border * 2)),
          height = uint16(uint32(input.height) + uint32(border * 2))))
      result.effects.add(statusEffect(completed.get))
      if completed.get.mapped:
        result.effects.add(effect(weMapDecoration, input.window, input.decoration))
        result.effects.add(paintEffect(completed.get, false))
        result.effects.add(effect(wePlaceClientAboveDecoration, input.window,
            input.decoration))
      if state.pointerModifier != 0:
        result.effects.add(WmEffect(kind: weInstallButtonGrabs,
            window: input.window, pointerModifier: state.pointerModifier,
            pointerLockMasks: state.pointerLockMasks))
  of wiMoveBy, wiMoveTo, wiResizeRelative, wiResizeAbsolute,
      wiConfigureRequest, wiMaximizeHorizontal, wiMaximizeVertical,
      wiMaximizeFull, wiMonocle, wiResetGeometry:
    let found = state.lookup(input.window)
    if found.isNone:
      if input.kind == wiConfigureRequest:
        # C forwards only X/Y/WIDTH/HEIGHT/SIBLING/STACK_MODE for unmanaged
        # root children. Border width is deliberately omitted.
        let forwardedMask = input.configureValueMask and 0x006f'u16
        if forwardedMask != 0:
          result.effects.add(WmEffect(kind: weConfigureRequest,
              window: input.window, configureValueMask: forwardedMask,
              configureSibling: input.configureSibling,
              configureStackMode: input.configureStackMode,
              x: input.x, y: input.y, width: input.width,
              height: input.height))
      return
    var client = found.get
    let wasSpecial = client.maxed or client.hmaxed or client.vmaxed or client.monocled
    var moved = false
    var resized = false
    var configurePromotedToMaximize = false
    var configureStackEffect = none(WmEffect)
    case input.kind
    of wiMoveBy:
      client.geometry.x = int32(int16(client.geometry.x + int32(input.x)))
      client.geometry.y = int32(int16(client.geometry.y + int32(input.y)))
      moved = true
    of wiMoveTo:
      client.geometry.x = int32(input.x)
      client.geometry.y = int32(input.y)
      moved = true
    of wiResizeRelative:
      client.geometry = geometryMath.resizeRelative(client.geometry,
          client.resizeHints, input.deltaWidth, input.deltaHeight,
          input.resizeHintsEnabled)
      resized = true
    of wiResizeAbsolute:
      client.geometry.width = max(client.resizeHints.minWidth, uint32(input.width))
      client.geometry.height = max(client.resizeHints.minHeight, uint32(input.height))
      resized = true
    of wiConfigureRequest:
      let mask = input.configureMask
      if (input.configureValueMask and (1'u16 shl 6)) != 0:
        # Frozen C forwards only stack_mode for a managed target. In
        # particular, the incoming sibling is not used as an anchor.
        configureStackEffect = some(WmEffect(kind: weConfigureRequest,
            window: input.window, configureValueMask: 1'u16 shl 6,
            configureStackMode: input.configureStackMode))
      if mask.x and not (client.maxed or client.monocled or client.hmaxed):
        client.geometry.x = int32(input.x)
      if mask.y and not (client.maxed or client.monocled or client.vmaxed):
        client.geometry.y = int32(input.y)
      if mask.width and not (client.maxed or client.monocled or client.hmaxed):
        client.geometry.width = uint32(input.width)
      if mask.height and not (client.maxed or client.monocled or client.vmaxed):
        client.geometry.height = uint32(input.height)
      if not client.maxed:
        # fit_on_screen clears only the independent horizontal/vertical
        # maximize flags; full maximize remains special until reset.
        client.hmaxed = false
        client.vmaxed = false
        if client.geometry.width == uint32(input.geometryBounds.width) and
            client.geometry.height == uint32(input.geometryBounds.height):
          # Frozen C's fit_on_screen treats an exact monitor-sized rectangle
          # as a request to enter full maximize. This can promote a monocle
          # ConfigureRequest to full maximize even when it only carried
          # STACK_MODE. Preserve C's saved geometry, which is the rectangle
          # observed immediately before that promotion.
          let savedGeometry = client.geometry
          if client.monocled:
            state.resetGeometry(client)
          client.maxed = true
          client.geometry = Geometry(x: input.geometryBounds.x,
              y: input.geometryBounds.y,
              width: uint32(input.geometryBounds.width),
              height: uint32(input.geometryBounds.height))
          client.origGeometry = savedGeometry
          configurePromotedToMaximize = true
        else:
          client.geometry = geometryMath.fitConfigure(client.geometry,
              client.resizeHints, input.geometryBounds)
      moved = true
      resized = true
    of wiMaximizeHorizontal, wiMaximizeVertical, wiMaximizeFull, wiMonocle:
      if state.applySpecialGeometry(client, input.kind, input.geometryBounds):
        moved = true
        resized = true
    of wiResetGeometry:
      if client.maxed or client.hmaxed or client.vmaxed or client.monocled:
        state.resetGeometry(client)
        moved = true
        resized = true
    else:
      discard
    if moved or resized:
      discard state.replaceClient(client)
      result.client = client
      result.hasClient = true
      result.effects = client.geometryEffects(moved, resized,
          input.geometryBounds, state.focusedId.isSome and state.focusedId.get == client.id)
      if configureStackEffect.isSome:
        result.effects.insert(configureStackEffect.get, 0)
      if configurePromotedToMaximize:
        result.effects.add(state.focusEffects(client.id, false))
        result.effects.add(WmEffect(kind: weRestackLayers,
            window: client.window))
      if input.kind in {wiMaximizeHorizontal, wiMaximizeVertical}:
        # C's maximize command runs set_focused after changing either axis.
        result.effects.add(state.focusEffects(client.id, true))
      elif input.kind in {wiMaximizeFull, wiMonocle}:
        # C enforces effective layer order after entering transient zoom.
        # Full maximize and monocle focus without an ordinary raise.
        result.effects.add(state.focusEffects(client.id, false))
        result.effects.add(WmEffect(kind: weRestackLayers, window: client.window))
      elif input.kind == wiResetGeometry and wasSpecial:
        # reset_window enforces layers, then its IPC caller focuses and raises.
        result.effects.add(WmEffect(kind: weRestackLayers, window: client.window))
        result.effects.add(state.focusEffects(client.id, true))
