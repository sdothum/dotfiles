## X-free lifecycle, focus and group transitions. X requests are ordered effects.

import std/[options, strutils, sequtils]
import ./[types, state, pointer]
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
  PrivateCommandDisposition* = enum
    pcdTransportRejected, pcdSemanticRejected, pcdSemanticAccepted,
    pcdDeferred, pcdBlocked
  PrivateReplyIntent* = object
    required*: bool
    payload*: string
    afterEffects*: bool
  PrivateTerminationIntent* = object
    requested*: bool
    exitStatus*: int32
  PrivateSnapshotClient* = object
    window*: WindowId
    group*: RawGroup
    mapped*: bool
    token*: ClientToken
  PrivateSnapshotIntent* = object
    focused*: Option[WindowId]
    currentGroup*: RawGroup
    clients*: seq[PrivateSnapshotClient]
  DecorationAllocation* = object
    ## Fresh XIDs supplied as an owned runtime observation. The model remains X-free.
    client*: WindowId
    decoration*: WindowId
  PrivateEffectKind* = enum
    pfeSendWmDelete, pfeKillClient, pfeRefreshBorders,
    pfeUngrabButtons, pfeGrabButtons
  PrivateEffect* = object
    kind*: PrivateEffectKind
    window*: WindowId
    buttonGrabs*: seq[ButtonGrabSpec]
  QueryObservationStatus* = enum
    qosUnavailable, qosAvailable, qosPartial, qosError, qosInvalidPattern
  QueryPropertyStatus* = enum
    qpsMatched, qpsNoMatch, qpsMissing, qpsEmpty, qpsWrongFormat,
    qpsMalformed, qpsReadError
  QueryMatchFact* = object
    clientId*: ClientId
    token*: ClientToken
    window*: WindowId
    requestSequence*: uint32
    propertyStatus*: QueryPropertyStatus
  QuerySelectionObservation* = object
    status*: QueryObservationStatus
    requestSequence*: uint32
    facts*: seq[QueryMatchFact]
  PrivateSemanticInput* = object
    ## Owned, X-free input from the Stage 7D-2 decoder. Opcode and argument
    ## words retain their unsigned 32-bit wire representation.
    opcode*: uint32
    words*: array[4, uint32]
    propertyPayload*: seq[byte]
    requestSequence*: uint32
    querySelectionObservation*: QuerySelectionObservation
    decorationAllocations*: seq[DecorationAllocation]
    observations*: WmInput
    hasObservations*: bool
    ## Runtime-derived query inputs remain owned and normalized. The adapter
    ## never performs the X11 property or tree queries that produce them.
    observedClass*: string
    hasObservedClass*: bool
    cardinalFocusTarget*: WindowId
    hasCardinalFocusTarget*: bool
    wmDeleteSupported*: bool
    hasWmProtocolsObservation*: bool
  PrivateCommandResult* = object
    disposition*: PrivateCommandDisposition
    transition*: TransitionResult
    reply*: PrivateReplyIntent
    replyDestination*: WindowId
    snapshot*: PrivateSnapshotIntent
    hasSnapshot*: bool
    invalidationRequired*: bool
    invalidationRequirementKnown*: bool
    ## Inert source-site metadata for the later publication slice. It never
    ## emits an X11 request or increments the root counter.
    invalidationSites*: seq[string]
    ## Process intent is metadata only in this slice. The pure adapter never
    ## terminates or respawns the WM.
    termination*: PrivateTerminationIntent
    privateEffects*: seq[PrivateEffect]
    detail*: string
  PrivateGeometryRecord = object
    window: WindowId
    x, y: int32
    width, height: uint16

proc effect(kind: WmEffectKind; window: WindowId;
            decoration = WindowId(0); group = NullGroup;
            x = 0'i16; y = 0'i16; width = 0'u16; height = 0'u16): WmEffect =
  WmEffect(kind: kind, window: window, decoration: decoration, group: group,
           x: x, y: y, width: width, height: height)

proc groupEffect(state: WmState; window: WindowId): WmEffect =
  result = WmEffect(kind: wePublishActiveGroups, window: window)
  result.groups = state.activeGroupIds

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
                     bounds: geometryMath.GeometryBounds; focused: bool;
                     frameExtent: int32): seq[WmEffect] =
  if moveClient:
    result.add(WmEffect(kind: weMoveClient, window: client.window,
        geometry: client.geometry))
  if resizeClient:
    result.add(WmEffect(kind: weResizeClient, window: client.window,
        geometry: client.geometry))
  if client.decoration.isSome and client.mapped:
    let derived = geometryMath.decorationGeometry(client.geometry,
        frameExtent)
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
                         focused: bool; frameExtent: int32;
                         zeroBorder = false): seq[WmEffect] =
  var geometry = WmEffect(kind: weApplyEwmhGeometry,
      window: client.window, geometry: client.geometry, maxed: zeroBorder)
  if client.decoration.isSome and client.mapped:
    let derived = geometryMath.decorationGeometry(client.geometry,
        frameExtent)
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
      state.focusedId.isSome and state.focusedId.get == client.id,
      state.config.outerBorderWidth + state.config.innerBorderWidth):
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
      state.config.outerBorderWidth + state.config.innerBorderWidth,
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
      state.focusedId.isSome and state.focusedId.get == client.id,
      state.config.outerBorderWidth + state.config.innerBorderWidth):
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
          state.focusedId.isSome and state.focusedId.get == client.id,
          state.config.outerBorderWidth + state.config.innerBorderWidth)
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
    let border = state.config.outerBorderWidth + state.config.innerBorderWidth
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
          state.setGroupActive(result.client.group,
              state.groupClients(result.client.group).len > 0)
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
          state.setGroupActive(oldGroup, state.groupClients(oldGroup).len > 0)
        result.client = state.lookup(targetId).get
        result.hasClient = true
        result.effects.add(effect(wePublishDesktop, result.client.window, group = group))
        result.effects.add(statusEffect(result.client))
        result.effects.add(groupEffect(state, result.client.window))
        if state.focusedId.isSome and state.focusedId.get == targetId:
          result.effects.add(effect(wePublishCurrentDesktop, result.client.window, group = group))
  of wiActivateGroup:
    if input.group.raw < state.groupCount and not state.groupIsActive(input.group):
      let members = state.groupClients(input.group)
      if members.len > 0:
        for client in members:
          if not client.mapped:
            state.setGroupMapPending(client.window, true)
            if client.decoration.isSome:
              result.effects.add(effect(weMapDecoration, client.window, client.decoration.get))
            result.effects.add(effect(weMapClient, client.window))
        state.setGroupActive(input.group, true)
        result.effects.add(groupEffect(state, WindowId(0)))
  of wiDeactivateGroup:
    if input.group.raw < state.groupCount and state.groupIsActive(input.group):
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
      state.setGroupActive(input.group, false)
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
      let border = state.config.outerBorderWidth + state.config.innerBorderWidth
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
          input.resizeHintsEnabled or state.config.resizeHints)
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
          input.geometryBounds, state.focusedId.isSome and state.focusedId.get == client.id,
          state.config.outerBorderWidth + state.config.innerBorderWidth)
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

proc privateSignedWord(value: uint32): int16 {.inline.} =
  ## The C transport casts through int32_t and then int16_t for these fields.
  cast[int16](cast[int32](value))

proc privateTarget(state: WmState; xid: uint32): Option[ClientState] =
  if xid == 0: return state.focusedClient
  state.lookup(WindowId(xid))

proc decodePrivateGeometry(payload: seq[byte]; state: WmState;
                           records: var seq[PrivateGeometryRecord]): bool =
  const MaxRequestBytes = 65536
  if payload.len == 0 or payload.len > MaxRequestBytes: return false
  var text = newString(payload.len)
  for index, value in payload:
    if value == 0: return false
    text[index] = char(value)
  var lines = text.split('\n')
  if lines.len > 0 and lines[^1].len == 0: lines.setLen(lines.len - 1)
  if lines.len == 0 or lines.len > MaxRequestBytes div 2: return false
  var seen: seq[WindowId]
  for line in lines:
    if line.len == 0 or line[0] == ' ' or line[^1] == ' ' or "  " in line:
      return false
    let fields = line.split(' ')
    if fields.len != 5 or fields[0].len != 10 or
        not fields[0].startsWith("0x"):
      return false
    var rawXid: int
    var x, y, width, height: int
    try:
      rawXid = parseHexInt(fields[0][2..^1])
      x = parseInt(fields[1])
      y = parseInt(fields[2])
      width = parseInt(fields[3])
      height = parseInt(fields[4])
    except ValueError:
      return false
    if rawXid < 0 or uint64(rawXid) > uint64(high(uint32)) or
        x < int(low(int32)) or x > int(high(int32)) or
        y < int(low(int32)) or y > int(high(int32)) or
        width < 0 or width > int(high(uint16)) or
        height < 0 or height > int(high(uint16)):
      return false
    let window = WindowId(uint32(rawXid))
    if state.lookup(window).isNone or window in seen: return false
    seen.add(window)
    records.add(PrivateGeometryRecord(window: window, x: int32(x),
        y: int32(y), width: uint16(width), height: uint16(height)))
  true

proc privateXid(window: WindowId): string =
  "0x" & toHex(window.raw, 8).toLowerAscii

proc privateReply(payload: string): PrivateReplyIntent =
  PrivateReplyIntent(required: true, payload: payload, afterEffects: true)

proc privateSnapshot(state: WmState): PrivateSnapshotIntent =
  let focused = state.focusedClient
  result.currentGroup = if focused.isNone or focused.get.group == NullGroup:
      NullGroup else: focused.get.group
  if focused.isSome: result.focused = some(focused.get.window)
  for client in state.clientsInManagedOrder():
    result.clients.add(PrivateSnapshotClient(window: client.window,
        group: client.group, mapped: client.mapped, token: client.token))

proc privateQueryTarget(state: WmState; input: PrivateSemanticInput):
    Option[ClientState] =
  if input.words[1] != 0:
    state.lookup(WindowId(input.words[2]))
  else:
    state.focusedClient

proc privateQueryError(input: PrivateSemanticInput): string =
  if input.words[1] != 0: "ERROR unknown or unmanaged window"
  else: "ERROR no focused managed window"

proc decodeRaiseMany(payload: seq[byte]; state: WmState;
                     input: WmInput): tuple[valid: bool, windows: seq[WindowId]] =
  const MaxRequestBytes = 65536
  if payload.len == 0 or payload.len > MaxRequestBytes: return
  var text = newString(payload.len)
  for index, value in payload:
    if value == 0: return
    text[index] = char(value)
  var lines = text.split('\n')
  if lines.len > 0 and lines[^1].len == 0: lines.setLen(lines.len - 1)
  if lines.len == 0 or lines.len > MaxRequestBytes div 3: return
  var seen: seq[WindowId]
  for line in lines:
    if line.len != 10 or not line.startsWith("0x"): return
    var raw: int
    try:
      raw = parseHexInt(line[2..^1])
    except ValueError:
      return
    if raw < 0 or uint64(raw) > uint64(high(uint32)): return
    let window = WindowId(uint32(raw))
    let client = state.lookup(window)
    if client.isNone or not client.get.mapped or window in seen or
        window notin input.physicalBottomToTop:
      return
    if client.get.decoration.isSome and
        client.get.decoration.get notin input.physicalBottomToTop:
      return
    seen.add(window)
  result.valid = true
  result.windows = seen

proc queryFilterGroup(payload: seq[byte]; groupCount: uint32):
    tuple[valid: bool, enabled: bool, group: RawGroup] =
  result.valid = true
  if payload.len == 0: return
  if payload.len != sizeof(uint32):
    result.valid = false
    return
  var publicGroup: uint32
  copyMem(addr publicGroup, unsafeAddr payload[0], sizeof(publicGroup))
  if publicGroup == 0 or publicGroup >= groupCount:
    result.valid = false
    return
  result.enabled = true
  result.group = RawGroup(publicGroup)

proc privateQueryCandidates*(state: WmState; input: PrivateSemanticInput):
    tuple[valid: bool, candidates: seq[ClientState]] =
  let groupFilter = queryFilterGroup(input.propertyPayload, state.groupCount)
  result.valid = groupFilter.valid
  if not result.valid: return
  let scopeAll = input.words[2] == 1'u32
  for client in state.clientsInManagedOrder():
    if not scopeAll and not client.mapped: continue
    if groupFilter.enabled and client.group != groupFilter.group: continue
    result.candidates.add(client)

proc decodePrivateCheckedGeometry(payload: seq[byte]; state: WmState;
    records: var seq[PrivateGeometryRecord]): bool =
  const MaxRequestBytes = 65536
  if payload.len == 0 or payload.len > MaxRequestBytes: return false
  var text = newString(payload.len)
  for index, value in payload:
    if value == 0: return false
    text[index] = char(value)
  var lines = text.split('\n')
  if lines.len > 0 and lines[^1].len == 0: lines.setLen(lines.len - 1)
  if lines.len == 0 or lines.len > MaxRequestBytes div 3: return false
  var seen: seq[WindowId]
  for line in lines:
    if line.len == 0 or line[0] == ' ' or line[^1] == ' ' or "  " in line:
      return false
    let fields = line.split(' ')
    if fields.len != 6 or fields[0].len != 10 or
        not fields[0].startsWith("0x") or fields[1].len != 49 or
        fields[1][32] != ':': return false
    for index, ch in fields[1]:
      if index == 32: continue
      if not (ch in {'0'..'9'} or ch in {'a'..'f'}): return false
    if fields[1][33..^1] == repeat('0', 16): return false
    var rawXid: int
    var x, y, width, height: int
    try:
      rawXid = parseHexInt(fields[0][2..^1])
      x = parseInt(fields[2])
      y = parseInt(fields[3])
      width = parseInt(fields[4])
      height = parseInt(fields[5])
    except ValueError:
      return false
    if rawXid < 0 or uint64(rawXid) > uint64(high(uint32)) or
        x < int(low(int32)) or x > int(high(int32)) or
        y < int(low(int32)) or y > int(high(int32)) or
        width < 0 or width > int(high(uint16)) or
        height < 0 or height > int(high(uint16)):
      return false
    let window = WindowId(uint32(rawXid))
    let client = state.lookup(window)
    if client.isNone or window in seen: return false
    let token = toHex(client.get.token.epoch.hi, 16).toLowerAscii &
        toHex(client.get.token.epoch.lo, 16).toLowerAscii & ":" &
        toHex(client.get.token.generation.raw, 16).toLowerAscii
    if fields[1] != token: return false
    seen.add(window)
    records.add(PrivateGeometryRecord(window: window, x: int32(x),
        y: int32(y), width: uint16(width), height: uint16(height)))
  true

proc appendPrivateButtonRegrab(result: var PrivateCommandResult;
                                state: WmState) =
  let clients = state.clientsInManagedOrder()
  # Frozen C completes every ungrab before beginning the first regrab.
  for client in clients:
    result.privateEffects.add(PrivateEffect(kind: pfeUngrabButtons,
        window: client.window))
  for client in clients:
    result.privateEffects.add(PrivateEffect(kind: pfeGrabButtons,
        window: client.window,
        buttonGrabs: sourceButtonGrabPlan(state.config.clickToFocus,
            state.config.pointerActions, state.pointerModifier,
            state.pointerLockMasks)))

proc borderFrameGeometry(client: Geometry; config: WmConfiguration): Geometry =
  let border = config.outerBorderWidth
  let gap = config.innerBorderWidth
  case config.borderStyle
  of 1'u32:
    result = Geometry(x: client.x - border - gap, y: client.y,
        width: cast[uint32](border + gap), height: client.height)
  of 2'u32:
    result = Geometry(x: client.x, y: client.y - border - gap,
        width: client.width, height: cast[uint32](border + gap))
  of 3'u32:
    result = Geometry(x: client.x, y: client.y + int32(client.height),
        width: client.width, height: cast[uint32](border + gap))
  of 4'u32:
    result = Geometry(x: client.x + int32(client.width), y: client.y,
        width: cast[uint32](border + gap), height: client.height)
  else:
    let extent = border + gap
    result = Geometry(x: client.x - extent, y: client.y - extent,
        width: cast[uint32](int64(client.width) + int64(2 * extent)),
        height: cast[uint32](int64(client.height) + int64(2 * extent)))

proc refreshBorderEffects(state: var WmState; input: PrivateSemanticInput;
                          output: var PrivateCommandResult) =
  if not state.config.borders:
    for client in state.clientsInManagedOrder():
      if client.decoration.isSome:
        output.transition.effects.add(effect(weDestroyDecoration,
            client.window, client.decoration.get))
        var updated = client
        updated.decoration = none(WindowId)
        discard state.replaceClient(updated)
    return
  for clientValue in state.clientsInManagedOrder():
    if not clientValue.mapped: continue
    var client = clientValue
    var created = false
    if client.decoration.isNone:
      for allocation in input.decorationAllocations:
        if allocation.client == client.window:
          client.decoration = some(allocation.decoration)
          created = true
          discard state.replaceClient(client)
          break
    if client.decoration.isNone: continue
    let rawFrame = borderFrameGeometry(client.geometry, state.config)
    let fitted = geometryMath.fitDecoration(rawFrame,
        input.observations.geometryBounds)
    if created:
      output.transition.effects.add(WmEffect(kind: weCreateDecoration,
          window: client.window, decoration: client.decoration.get,
          x: int16(rawFrame.x), y: int16(rawFrame.y),
          width: uint16(rawFrame.width), height: uint16(rawFrame.height)))
      output.transition.effects.add(WmEffect(kind: weMapDecoration,
          window: client.window, decoration: client.decoration.get))
    output.transition.effects.add(WmEffect(kind: weConfigureDecoration,
        window: client.window, decoration: client.decoration.get,
        geometry: fitted))
    output.transition.effects.add(WmEffect(kind: weConfigureDecoration,
        window: client.window, decoration: client.decoration.get,
        geometry: fitted))
    let focused = state.focusedClient
    output.transition.effects.add(WmEffect(kind: wePaintDecoration,
        window: client.window, decoration: client.decoration.get,
        geometry: client.geometry,
        outerColor: if focused.isSome and focused.get.id == client.id:
            state.config.outerColorFocused else: state.config.outerColorUnfocused))
    # C update_frame_geometry maps through map_window_stacking, which
    # re-enforces the owner layer after frame creation or refresh.
    output.transition.effects.add(WmEffect(kind: weRestackLayers,
        window: client.window))

proc applyPrivateCommand*(state: var WmState; epoch: ProcessEpoch;
                          input: PrivateSemanticInput): PrivateCommandResult =
  ## Pure semantic adapter for the Stage 7D-3 command subset. It only prepares
  ## future reply metadata; it never publishes a private reply or performs an
  ## XCB operation. Required server observations arrive in the owned normalized
  ## `observations` value.
  var request: WmInput
  if input.opcode in [0'u32, 1'u32, 12'u32, 13'u32, 14'u32, 15'u32,
      16'u32, 22'u32, 23'u32, 24'u32, 27'u32, 28'u32, 29'u32, 30'u32,
      31'u32, 32'u32, 33'u32, 34'u32, 35'u32, 36'u32, 38'u32]:
    result.reply.required = true
    result.reply.afterEffects = true
    result.replyDestination = WindowId(input.words[0])
  template run(kindValue: WmInputKind) =
    request.kind = kindValue
    result.transition = state.transition(epoch, request)
    result.disposition = pcdSemanticAccepted

  template acceptedReply() =
    result.reply = PrivateReplyIntent(required: true, payload: "OK",
                                      afterEffects: true)

  case input.opcode
  of 0'u32, 1'u32:
    result.invalidationRequirementKnown = true
    let previousFocus = state.focusedId
    result.reply.required = true
    if input.words[1] >= state.groupCount:
      result.disposition = pcdSemanticRejected
      result.reply.payload = "ERROR invalid group"
      result.detail = "group index outside configured group count"
      return
    request = input.observations
    request.group = RawGroup(input.words[1])
    run(if input.opcode == 0: wiActivateGroup else: wiDeactivateGroup)
    acceptedReply()
    result.invalidationRequirementKnown = true
    for emitted in result.transition.effects:
      if emitted.kind == weMapClient:
        result.invalidationSites.add("events.c:event_map_notify")
      elif emitted.kind == weUnmapClient:
        result.invalidationSites.add("events.c:event_unmap_notify")
    if previousFocus != state.focusedId:
      result.invalidationSites.add("focus.c:clear_focused")
    result.invalidationRequired = result.invalidationSites.len > 0
  of 2'u32:
    result.invalidationRequirementKnown = true
    let previousFocus = state.focusedId
    let group = RawGroup(input.words[0])
    result.disposition = pcdSemanticAccepted
    if group.raw >= state.groupCount:
      result.detail = "frozen-C silently ignores out-of-range group"
      return
    let members = state.groupClients(group)
    result.invalidationRequirementKnown = true
    for member in members:
      request = input.observations
      request.kind = wiRemoveGroup
      request.clientId = member.id
      let part = state.transition(epoch, request)
      result.transition.effects.add(part.effects)
      result.transition.client = part.client
      result.transition.hasClient = result.transition.hasClient or part.hasClient
    result.invalidationRequired = members.len > 0
    if result.invalidationRequired:
      result.invalidationSites.add("groups.c:group_remove_window")
    if previousFocus != state.focusedId:
      result.invalidationRequired = true
      result.invalidationSites.add("focus.c:clear_focused")
  of 3'u32:
    if not input.hasCardinalFocusTarget:
      result.disposition = pcdDeferred
      result.detail = "cardinal candidate requires normalized source-algorithm observation"
      return
    let target = state.lookup(input.cardinalFocusTarget)
    let previousFocus = state.focusedId
    result.disposition = pcdSemanticAccepted
    if target.isSome and target.get.mapped and target.get.window !=
        (if state.focusedClient.isSome: state.focusedClient.get.window else: WindowId(0)):
      request = input.observations
      request.window = target.get.window
      run(wiFocusClient)
      result.detail = "focus candidate selected by normalized frozen-C cardinal geometry observation"
    else:
      result.detail = "source cardinal-focus selection has no usable candidate"
    result.invalidationRequirementKnown = true
    result.invalidationRequired = previousFocus != state.focusedId
    if result.invalidationRequired:
      result.invalidationSites.add("focus.c:set_focused_no_raise")
  of 4'u32, 5'u32, 8'u32, 9'u32:
    let previousFocus = state.focusedId
    request = input.observations
    let kind = case input.opcode
      of 4'u32: wiCycle
      of 5'u32: wiCycleGroup
      of 8'u32: wiReverseCycle
      else: wiReverseCycleGroup
    run(kind)
    result.invalidationRequirementKnown = true
    result.invalidationRequired = previousFocus != state.focusedId
    if result.invalidationRequired:
      result.invalidationSites.add("focus.c:set_focused_no_raise")
  of 6'u32:
    # C resolves this raw XID against the managed list at handler dispatch.
    # Nim likewise retains the record until its DestroyNotify input is
    # processed, so a ClientMessage dequeued before that cleanup sees the
    # same record without retaining a pointer to a dead X resource.
    let target = state.lookup(WindowId(input.words[0]))
    let previousFocus = state.focusedId
    result.invalidationRequirementKnown = true
    if target.isSome:
      request = input.observations
      request.window = target.get.window
      run(wiFocusClient)
      result.detail = "raw-XID lookup resolved the currently retained managed record"
      result.invalidationRequirementKnown = true
      if previousFocus != state.focusedId:
        result.invalidationRequired = true
        result.invalidationSites.add("focus.c:set_focused_no_raise")
    else:
      result.disposition = pcdSemanticAccepted
      result.detail = "source-compatible focus lookup is a no-op for an unknown XID"
      result.invalidationRequirementKnown = true
  of 7'u32:
    let previousFocus = state.focusedId
    request = input.observations
    run(wiFocusLast)
    result.invalidationRequirementKnown = true
    result.invalidationRequired = previousFocus != state.focusedId
    if result.invalidationRequired:
      result.invalidationSites.add("focus.c:set_focused_no_raise")
  of 12'u32:
    let focused = state.focusedClient
    result.disposition = pcdSemanticAccepted
    result.reply = privateReply(if focused.isSome:
        "OK " & privateXid(focused.get.window)
      else: "ERROR no focused managed window")
    result.detail = "query derives from authoritative logical focus state"
    result.invalidationRequirementKnown = true
  of 13'u32, 14'u32:
    let selector = input.words[3]
    let candidateSet = state.privateQueryCandidates(input)
    if not candidateSet.valid:
      result.disposition = pcdSemanticRejected
      result.reply = privateReply("ERROR unable to prepare selector query")
      result.detail = "optional group request property is not a valid one-based CARDINAL"
      return
    if selector > 2'u32:
      result.disposition = pcdSemanticRejected
      result.reply = privateReply("ERROR unable to prepare selector query")
      result.detail = "selector value is outside the frozen-C enum"
      return
    var selected: seq[ClientState]
    if selector == 0'u32:
      selected = candidateSet.candidates
    else:
      let observation = input.querySelectionObservation
      if observation.status == qosInvalidPattern:
        result.disposition = pcdSemanticRejected
        result.reply = privateReply("ERROR invalid title regex")
        result.detail = "POSIX ERE compilation failed before client traversal"
        return
      if observation.status == qosError:
        result.disposition = pcdSemanticRejected
        result.reply = privateReply("ERROR unable to prepare selector query")
        result.detail = "selector request observation failed"
        return
      if observation.status != qosAvailable:
        result.disposition = pcdDeferred
        result.detail = "selector observation is unavailable or incomplete"
        return
      if observation.requestSequence != input.requestSequence:
        result.disposition = pcdDeferred
        result.detail = "selector observation belongs to a different request"
        return
      for fact in observation.facts:
        if fact.requestSequence != input.requestSequence:
          result.disposition = pcdDeferred
          result.detail = "selector fact belongs to a different request"
          return
        let observedClient = state.lookup(fact.clientId)
        if observedClient.isNone or observedClient.get.window != fact.window or
            observedClient.get.token.epoch.hi != fact.token.epoch.hi or
            observedClient.get.token.epoch.lo != fact.token.epoch.lo or
            observedClient.get.token.generation != fact.token.generation:
          result.disposition = pcdDeferred
          result.detail = "selector fact has stale client identity"
          return
        if not candidateSet.candidates.anyIt(it.id == fact.clientId):
          result.disposition = pcdDeferred
          result.detail = "selector fact is outside the request scope"
          return
      for client in candidateSet.candidates:
        var factCount = 0
        var matched = false
        for fact in observation.facts:
          if fact.clientId == client.id:
            inc factCount
            matched = fact.propertyStatus == qpsMatched
        if factCount != 1:
          result.disposition = pcdDeferred
          result.detail = "selector observation is missing or duplicates a managed identity"
          return
        if matched: selected.add(client)
    result.disposition = pcdSemanticAccepted
    if input.opcode == 14'u32:
      result.reply = privateReply("OK " & $selected.len)
    else:
      var response = "OK"
      for client in selected:
        response.add("\n" & privateXid(client.window))
      result.reply = privateReply(response)
    result.detail = if selector == 0'u32:
        "query uses logical management order, confirmed mapping, and optional group filter"
      else: "selector result supplied as an owned normalized runtime observation"
    result.invalidationRequirementKnown = true
  of 15'u32:
    let focused = state.focusedClient
    if focused.isNone:
      result.disposition = pcdSemanticAccepted
      result.reply = privateReply("OK")
      result.invalidationRequirementKnown = true
      return
    if not input.hasObservedClass:
      result.disposition = pcdDeferred
      result.detail = "WM_CLASS class component requires a normalized X11 observation"
      return
    result.disposition = pcdSemanticAccepted
    result.reply = privateReply(if input.observedClass.len == 0:
        "OK" else: "OK " & input.observedClass)
    result.detail = "reply uses an owned class-name observation"
    result.invalidationRequirementKnown = true
  of 16'u32:
    let target = privateQueryTarget(state, input)
    result.disposition = pcdSemanticAccepted
    if target.isNone:
      result.reply = privateReply(privateQueryError(input))
    else:
      let g = target.get.geometry
      result.reply = privateReply("OK\nX=" & $g.x & "\nY=" & $g.y &
          "\nWIDTH=" & $g.width & "\nHEIGHT=" & $g.height & "\n")
      result.detail = "uses logical WM geometry; it does not query physical X geometry"
    result.invalidationRequirementKnown = true
  of 23'u32:
    let target = privateQueryTarget(state, input)
    let previousFocus = state.focusedId
    result.disposition = pcdSemanticAccepted
    result.reply = privateReply(if target.isNone:
        privateQueryError(input) else: "OK")
    if target.isSome:
      request = input.observations
      request.window = target.get.window
      run(wiResetGeometry)
      result.reply = privateReply("OK")
    result.detail = "reset transitions restore saved logical geometry, then focus/raise via the existing transition"
    result.invalidationRequirementKnown = true
    result.invalidationRequired = previousFocus != state.focusedId
    if result.invalidationRequired:
      result.invalidationSites.add("focus.c:set_focused_no_raise")
  of 24'u32:
    let target = privateQueryTarget(state, input)
    result.reply.required = true
    if target.isNone:
      result.disposition = pcdSemanticRejected
      result.reply.payload = privateQueryError(input)
      return
    if not target.get.mapped:
      result.disposition = pcdSemanticRejected
      result.reply.payload = "ERROR reference window is not mapped"
      return
    if not input.hasObservations or input.observations.physicalBottomToTop.len == 0:
      result.disposition = pcdDeferred
      result.detail = "stack-cycle requires a fresh physical QueryTree observation"
      return
    let previousFocus = state.focusedId
    request = input.observations
    request.window = target.get.window
    let closure = state.overlapClosure(stacking.StackObservation(
        managedBottomToTop: request.physicalBottomToTop), request.window)
    if closure.len == 0 or request.window notin request.physicalBottomToTop:
      result.disposition = pcdSemanticRejected
      result.reply.payload = "ERROR reference window missing from stacking order"
      return
    run(wiStackCycle)
    result.reply = privateReply("OK")
    result.detail = "effect plan uses normalized physical order; no physical parity claimed"
    result.invalidationRequirementKnown = true
    result.invalidationRequired = previousFocus != state.focusedId
    if result.invalidationRequired:
      result.invalidationSites.add("focus.c:set_focused_no_raise")
  of 27'u32, 32'u32:
    let target = privateQueryTarget(state, input)
    if target.isNone:
      result.disposition = pcdSemanticRejected
      result.reply = privateReply(privateQueryError(input))
      return
    if not target.get.mapped:
      result.disposition = pcdSemanticRejected
      result.reply = privateReply("ERROR reference window is not mapped")
      return
    if not input.hasObservations or input.observations.physicalBottomToTop.len == 0:
      result.disposition = pcdDeferred
      result.detail = "stack query requires a fresh physical QueryTree observation"
      return
    let order = input.observations.physicalBottomToTop
    let closure = state.overlapClosure(stacking.StackObservation(
        managedBottomToTop: order), target.get.window)
    if closure.len == 0 or target.get.window notin order:
      result.disposition = pcdSemanticRejected
      result.reply = privateReply("ERROR reference window missing from stacking order")
      return
    var response = if input.opcode == 27'u32: "OK" else: "OK\n"
    for client in closure:
      if input.opcode == 27'u32:
        response.add("\n" & privateXid(client.window))
      else:
        let g = client.geometry
        response.add(privateXid(client.window) & " " & $g.x & " " & $g.y &
            " " & $g.width & " " & $g.height & "\n")
    result.disposition = pcdSemanticAccepted
    result.reply = privateReply(response)
    result.detail = "stack order is source input from normalized physical observation; geometry is logical model state"
    result.invalidationRequirementKnown = true
  of 28'u32:
    result.disposition = pcdSemanticAccepted
    let group = if state.focusedClient.isSome:
        state.focusedClient.get.group.raw else: NullGroup.raw
    result.reply = privateReply("OK " & $group)
    result.detail = "current group is authoritative logical focus state"
    result.invalidationRequirementKnown = true
  of 29'u32:
    let target = state.lookup(WindowId(input.words[2]))
    result.disposition = pcdSemanticAccepted
    result.reply = privateReply(if target.isSome:
        "OK " & $target.get.group.raw else: "ERROR unknown or unmanaged window")
    result.invalidationRequirementKnown = true
  of 30'u32:
    let clients = state.clientsInManagedOrder()
    var response = if clients.len == 0: "OK" else: "OK\n"
    for index, client in clients:
      if index > 0: response.add("\n")
      response.add(privateXid(client.window) & " " & $client.group.raw)
    if clients.len > 0: response.add("\n")
    result.disposition = pcdSemanticAccepted
    result.reply = privateReply(response)
    result.detail = "uses logical managed insertion order and raw group IDs"
    result.invalidationRequirementKnown = true
  of 36'u32:
    result.disposition = pcdSemanticAccepted
    result.reply = privateReply("OK " & $state.groupCount)
    result.invalidationRequirementKnown = true
  of 17'u32, 18'u32:
    result.invalidationRequirementKnown = true
    let target = if input.words[3] == 0: state.focusedClient
                 else: state.lookup(WindowId(input.words[3]))
    if target.isNone:
      result.disposition = pcdSemanticAccepted
      result.detail = "source-compatible action_client lookup is a no-op"
      return
    request = input.observations
    request.window = target.get.window
    let absolute = input.words[0] != 0
    request.x = privateSignedWord(input.words[1])
    request.y = privateSignedWord(input.words[2])
    if input.opcode == 17:
      run(if absolute: wiMoveTo else: wiMoveBy)
    elif absolute:
      request.width = uint16(input.words[1] and 0xffff'u32)
      request.height = uint16(input.words[2] and 0xffff'u32)
      run(wiResizeAbsolute)
    else:
      request.deltaWidth = cast[int32](input.words[1])
      request.deltaHeight = cast[int32](input.words[2])
      run(wiResizeRelative)
    result.invalidationRequirementKnown = true
  of 19'u32, 20'u32:
    if not input.hasObservations:
      result.disposition = pcdDeferred
      result.detail = "monitor bounds must be supplied as a normalized runtime observation"
      return
    result.invalidationRequirementKnown = true
    let targetWord = if input.opcode == 19: input.words[1] else: input.words[0]
    let target = privateTarget(state, targetWord)
    if target.isNone:
      result.disposition = pcdSemanticAccepted
      result.detail = "source-compatible action_client lookup is a no-op"
      return
    let previousFocus = state.focusedId
    request = input.observations
    request.window = target.get.window
    request.geometryBounds.gapLeft = state.config.gapLeft
    request.geometryBounds.gapRight = state.config.gapRight
    request.geometryBounds.gapTop = state.config.gapUp
    request.geometryBounds.gapBottom = state.config.gapDown
    if input.opcode == 19:
      case input.words[0]
      of 0: run(wiMaximizeFull)
      of 1: run(wiMaximizeHorizontal)
      of 2: run(wiMaximizeVertical)
      else:
        result.disposition = pcdSemanticAccepted
        result.detail = "frozen-C ignores unsupported maximize axis"
        return
    else:
      run(wiMonocle)
    # Frozen C's maximize/monocle handlers update the client's EWMH state and
    # status after geometry, focus, and layer enforcement. Keep those effects
    # in the private command's ordered result; the normal runtime remains
    # private-command-disabled and the diagnostic executor realizes them only
    # under its explicit compile-time/runtime gates.
    let updatedTarget = state.lookup(target.get.window)
    if updatedTarget.isSome:
      result.transition.effects.add(ewmhStatePropertyEffect(updatedTarget.get))
      result.transition.effects.add(statusEffect(updatedTarget.get))
      # The frozen-C IPC action calls set_focused after maximize_window or
      # monocle_window returns. Those helpers already focus without raising;
      # the outer call repeats focus publication and raises frame then client.
      # Keep that command-level phase in the pure private adapter so XCB
      # realization remains policy-free.
      if input.opcode in [19'u32, 20'u32]:
        result.transition.effects.add(
            state.focusEffects(updatedTarget.get.id, true))
    result.reply.required = false
    result.invalidationRequirementKnown = true
    result.invalidationRequired = previousFocus != state.focusedId
    if result.invalidationRequired:
      result.invalidationSites.add("focus.c:set_focused_no_raise")
  of 21'u32:
    let target = privateTarget(state, input.words[0])
    result.disposition = pcdSemanticAccepted
    result.reply.required = false
    result.invalidationRequirementKnown = true
    if target.isNone:
      result.detail = "source action_client lookup is a no-op for unknown XID"
      return
    if not input.hasWmProtocolsObservation:
      result.disposition = pcdDeferred
      result.detail = "close target requires normalized WM_PROTOCOLS/WM_DELETE_WINDOW observation"
      return
    let previousFocus = state.focusedId
    if previousFocus.isSome and previousFocus.get == target.get.id:
      if state.lastWindowFocus:
        let focusLast = state.transition(epoch, WmInput(kind: wiFocusLast))
        result.transition.effects.add(focusLast.effects)
      if state.focusedId.isSome and state.focusedId.get == target.get.id:
        let clear = state.transition(epoch, WmInput(kind: wiClearFocus))
        result.transition.effects.add(clear.effects)
    result.privateEffects.add(PrivateEffect(
        kind: if input.wmDeleteSupported: pfeSendWmDelete else: pfeKillClient,
        window: target.get.window))
    result.invalidationRequired = previousFocus != state.focusedId
    if result.invalidationRequired:
      result.invalidationSites.add("focus.c:set_focused_no_raise")
    result.detail = "focus fallback and close delivery are ordered intent; no XCB operation is executed"
  of 22'u32:
    let target = privateQueryTarget(state, input)
    result.reply.required = true
    if target.isNone:
      result.disposition = pcdSemanticRejected
      result.reply.payload = privateQueryError(input)
      return
    if not target.get.mapped:
      result.disposition = pcdSemanticRejected
      result.reply.payload = "ERROR window is already hidden"
      return
    result.disposition = pcdSemanticAccepted
    if target.get.decoration.isSome:
      result.transition.effects.add(effect(weUnmapDecoration,
          target.get.window, target.get.decoration.get))
    result.transition.effects.add(effect(weUnmapClient, target.get.window))
    result.reply = privateReply("OK")
    result.invalidationRequirementKnown = true
    result.detail = "unmap effects are prepared; mapping changes only on UnmapNotify"
  of 25'u32, 26'u32:
    result.invalidationRequirementKnown = true
    let targetWord = if input.opcode == 25: input.words[1] else: input.words[0]
    let target = privateTarget(state, targetWord)
    if target.isNone:
      result.disposition = pcdSemanticAccepted
      result.detail = "source-compatible action_client lookup is a no-op"
      return
    request = input.observations
    request.window = target.get.window
    if input.opcode == 25:
      let previousGroup = target.get.group
      request.group = RawGroup(input.words[0])
      if request.group.raw >= state.groupCount:
        result.disposition = pcdSemanticAccepted
        result.detail = "frozen-C group add validation is a no-op"
        return
      run(wiAssignGroup)
      result.invalidationRequirementKnown = true
      result.invalidationRequired = previousGroup != result.transition.client.group
      if result.invalidationRequired:
        result.invalidationSites.add("groups.c:group_add_window")
    else:
      let previousGroup = target.get.group
      run(wiRemoveGroup)
      result.invalidationRequirementKnown = true
      result.invalidationRequired = previousGroup != NullGroup
      if result.invalidationRequired:
        result.invalidationSites.add("groups.c:group_remove_window")
  of 38'u32:
    result.invalidationRequirementKnown = true
    result.reply.required = true
    let target = if input.words[1] != 0: state.lookup(WindowId(input.words[2]))
                 else: state.focusedClient
    if input.words[3] > uint32(ord(high(WindowLayer))):
      result.disposition = pcdSemanticRejected
      result.reply.payload = "ERROR invalid window layer"
      result.detail = "layer outside Normal/Above/Overlay"
      return
    if target.isNone:
      result.disposition = pcdSemanticRejected
      result.reply.payload = "ERROR unknown or unmanaged window"
      result.detail = "managed-client lookup failed"
      return
    request = input.observations
    request.window = target.get.window
    request.layer = WindowLayer(input.words[3])
    run(wiSetLayer)
    acceptedReply()
    result.invalidationRequirementKnown = true
  of 11'u32, 37'u32:
    result.disposition = pcdSemanticAccepted
    result.termination = PrivateTerminationIntent(requested: true,
        exitStatus: cast[int32](input.words[0]))
    result.reply.required = false
    result.detail = "inert process-exit intent; no termination or respawn is performed"
    result.invalidationRequirementKnown = true
  of 31'u32:
    result.disposition = pcdSemanticAccepted
    result.reply.required = true
    result.snapshot = privateSnapshot(state)
    result.hasSnapshot = true
    result.detail = "owned structured SNAPSHOT2 result prepared; serialization/publication remain assigned to Stage 7D-5"
  of 33'u32:
    result.invalidationRequirementKnown = true
    result.reply.required = true
    var records: seq[PrivateGeometryRecord]
    if not decodePrivateGeometry(input.propertyPayload, state, records):
      result.disposition = pcdSemanticRejected
      result.reply.payload = "ERROR invalid geometry request"
      result.detail = "property body failed source-compatible batch validation"
      return
    result.disposition = pcdSemanticAccepted
    result.reply = PrivateReplyIntent(required: true, payload: "OK",
                                      afterEffects: true)
    result.invalidationRequirementKnown = true
    for record in records:
      request = input.observations
      request.window = record.window
      request.x = cast[int16](record.x)
      request.y = cast[int16](record.y)
      let moved = state.transition(epoch, WmInput(kind: wiMoveTo,
          window: request.window, x: request.x, y: request.y,
          geometryBounds: request.geometryBounds))
      result.transition.effects.add(moved.effects)
      request.width = record.width
      request.height = record.height
      let resized = state.transition(epoch, WmInput(kind: wiResizeAbsolute,
          window: request.window, width: request.width, height: request.height,
          geometryBounds: request.geometryBounds))
      result.transition.effects.add(resized.effects)
      result.transition.client = resized.client
      result.transition.hasClient = true
    result.detail = "effects are ordered move then resize per validated record; no rollback"
  of 10'u32:
    result.invalidationRequirementKnown = true
    result.disposition = pcdSemanticAccepted
    result.reply.required = false
    let key = input.words[0]
    let values = [input.words[1], input.words[2], input.words[3]]
    var recognized = true
    case key
    of 0'u32: state.config.applySettings = values[0] != 0
    of 1'u32:
      state.config.borderStyle = values[0]
      if state.config.applySettings: result.privateEffects.add(PrivateEffect(kind: pfeRefreshBorders))
    of 2'u32:
      state.config.outerBorderWidth = cast[int32](values[0])
      if state.config.applySettings: result.privateEffects.add(PrivateEffect(kind: pfeRefreshBorders))
    of 3'u32:
      state.config.clickToFocus = cast[int8](values[0])
      appendPrivateButtonRegrab(result, state)
    of 4'u32:
      state.config.outerColorFocused = values[0]
      if state.config.applySettings: result.privateEffects.add(PrivateEffect(kind: pfeRefreshBorders))
    of 5'u32:
      state.config.outerColorUnfocused = values[0]
      if state.config.applySettings: result.privateEffects.add(PrivateEffect(kind: pfeRefreshBorders))
    of 6'u32:
      state.config.cornerMask = values[0]
      if state.config.applySettings: result.privateEffects.add(PrivateEffect(kind: pfeRefreshBorders))
    of 7'u32:
      state.config.cornerPercent = min(values[0], 100'u32)
      if state.config.applySettings: result.privateEffects.add(PrivateEffect(kind: pfeRefreshBorders))
    of 8'u32: state.config.cursorPosition = values[0]
    of 9'u32:
      state.config.borders = values[0] != 0
      if not state.config.borders:
        # Frozen C destroys each frame and clears the retained frame identity.
        # Keep this in the pure transition so later commands cannot target a
        # decoration that the ordered XCB effect has destroyed.
        for client in state.clientsInManagedOrder():
          if client.decoration.isSome:
            result.transition.effects.add(effect(weDestroyDecoration,
                client.window, client.decoration.get))
            var updated = client
            updated.decoration = none(WindowId)
            discard state.replaceClient(updated)
      else:
        result.privateEffects.add(PrivateEffect(kind: pfeRefreshBorders))
    of 10'u32: state.lastWindowFocus = values[0] != 0
    of 11'u32: state.config.resizeHints = values[0] != 0
    of 12'u32: state.sloppyFocus = values[0] != 0
    of 13'u32:
      case values[0]
      of 0'u32: state.config.gapUp = cast[int32](values[1])
      of 1'u32: state.config.gapDown = cast[int32](values[1])
      of 2'u32: state.config.gapLeft = cast[int32](values[1])
      of 3'u32: state.config.gapRight = cast[int32](values[1])
      of 9'u32:
        state.config.gapLeft = cast[int32](values[1])
        state.config.gapDown = cast[int32](values[1])
        state.config.gapUp = cast[int32](values[1])
        state.config.gapRight = cast[int32](values[1])
      else: discard # frozen C silently ignores an unrecognized position
    of 14'u32:
      # Frozen C activates each to-be-removed group while the old group count
      # still applies, then clears its clients before installing the new count.
      if values[0] < state.groupCount:
        for client in state.clientsInManagedOrder():
          if client.group != NullGroup and client.group.raw >= values[0] and
              client.group.raw < state.groupCount and
              not state.groupIsActive(client.group):
            let activated = state.transition(epoch, WmInput(kind: wiActivateGroup,
                group: client.group))
            result.transition.effects.add(activated.effects)
      let resized = state.setConfiguredGroupCount(values[0])
      for client in resized.changedClients:
        result.transition.effects.add(WmEffect(kind: wePublishDesktop,
            window: client.window, group: NullGroup))
      if resized.changedClients.len > 0:
        result.invalidationRequired = true
        result.invalidationSites.add("groups.c:change_nr_of_groups")
    of 15'u32: 
      state.config.innerBorderWidth = cast[int32](values[0])
      if state.config.applySettings: result.privateEffects.add(PrivateEffect(kind: pfeRefreshBorders))
    of 16'u32:
      state.config.innerColorFocused = values[0]
      if state.config.applySettings: result.privateEffects.add(PrivateEffect(kind: pfeRefreshBorders))
    of 17'u32:
      state.config.innerColorUnfocused = values[0]
      if state.config.applySettings: result.privateEffects.add(PrivateEffect(kind: pfeRefreshBorders))
    of 18'u32:
      for index in 0 .. 2: state.config.pointerActions[index] = values[index]
      appendPrivateButtonRegrab(result, state)
    of 19'u32:
      state.pointerModifier = uint16(values[0] and 0xffff'u32)
      appendPrivateButtonRegrab(result, state)
    of 20'u32: state.config.replayClickOnFocus = values[0] != 0
    of 21'u32: state.config.stickyWindows = values[0] != 0
    else: recognized = false # C logs and returns without a reply
    result.detail = if recognized:
        "source configuration value stored; XCB work remains an inert ordered effect"
      else: "frozen-C unknown configuration key is a no-reply no-op"
  of 34'u32:
    if not input.hasObservations:
      result.disposition = pcdDeferred
      result.detail = "raise-many requires a normalized physical root-child observation"
      return
    let decoded = decodeRaiseMany(input.propertyPayload, state, input.observations)
    if not decoded.valid:
      result.disposition = pcdSemanticRejected
      result.reply = privateReply("ERROR invalid raise request")
      return
    request = input.observations
    request.kind = wiRaiseMany
    request.windows = decoded.windows
    result.transition = state.transition(epoch, request)
    if result.transition.effects.len == 0:
      result.disposition = pcdSemanticRejected
      result.reply = privateReply("ERROR unable to determine stacking order")
      return
    result.disposition = pcdSemanticAccepted
    result.reply = privateReply("OK")
    result.invalidationRequirementKnown = false
    result.detail = "ordered raise effects prepared from the source payload order"
  of 35'u32:
    var records: seq[PrivateGeometryRecord]
    if not decodePrivateCheckedGeometry(input.propertyPayload, state, records):
      result.disposition = pcdSemanticRejected
      result.reply = privateReply("ERROR invalid checked geometry request")
      result.detail = "complete-batch client-token and geometry validation failed"
      return
    result.disposition = pcdSemanticAccepted
    result.reply = privateReply("OK")
    result.invalidationRequirementKnown = true
    for record in records:
      request = input.observations
      request.window = record.window
      request.x = cast[int16](record.x)
      request.y = cast[int16](record.y)
      let moved = state.transition(epoch, WmInput(kind: wiMoveTo,
          window: request.window, x: request.x, y: request.y,
          geometryBounds: request.geometryBounds))
      result.transition.effects.add(moved.effects)
      request.width = record.width
      request.height = record.height
      let resized = state.transition(epoch, WmInput(kind: wiResizeAbsolute,
          window: request.window, width: request.width, height: request.height,
          geometryBounds: request.geometryBounds))
      result.transition.effects.add(resized.effects)
      result.transition.client = resized.client
      result.transition.hasClient = true
    result.detail = "checked batch is prevalidated by epoch/generation; move then resize per record"
  else:
    result.disposition = pcdTransportRejected
    result.detail = "opcode is outside the registered 0..38 range"

  var remainingPrivateEffects: seq[PrivateEffect]
  for privateEffect in result.privateEffects:
    if privateEffect.kind == pfeRefreshBorders:
      refreshBorderEffects(state, input, result)
    else:
      remainingPrivateEffects.add(privateEffect)
  result.privateEffects = remainingPrivateEffects

  let implemented = input.opcode <= 3'u32 or input.opcode in 11'u32..24'u32 or
      input.opcode in 13'u32..16'u32 or input.opcode == 23'u32 or
      input.opcode == 24'u32 or input.opcode in 27'u32..30'u32 or
      input.opcode == 32'u32 or input.opcode == 34'u32 or
      input.opcode == 35'u32 or input.opcode == 36'u32 or
      input.opcode == 37'u32 or
      input.opcode in 4'u32..9'u32 or
      input.opcode in 17'u32..20'u32 or
      input.opcode in 25'u32..26'u32 or
      input.opcode == 33'u32 or input.opcode == 38'u32
  if implemented and result.disposition notin {pcdDeferred, pcdBlocked}:
    result.invalidationRequirementKnown = true
