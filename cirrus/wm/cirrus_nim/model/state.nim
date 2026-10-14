## Authoritative Stage 2 identities. No X11 types or operations are imported.

import std/[tables, options, hashes, algorithm]
import ./types

type
  WmConfiguration* = object
    ## Canonical frozen-C configuration values. Values retain the source
    ## protocol's uint32 representation unless the C field is narrower.
    applySettings*, borders*, replayClickOnFocus*, resizeHints*,
      stickyWindows*: bool
    borderStyle*, outerColorFocused*, outerColorUnfocused*, cornerMask*,
      cornerPercent*, cursorPosition*, innerColorFocused*, innerColorUnfocused*: uint32
    outerBorderWidth*, gapLeft*, gapDown*, gapUp*, gapRight*, innerBorderWidth*: int32
    clickToFocus*: int8
    pointerActions*: array[3, uint32]

  WmState* = object
    nextGeneration: uint64
    generationExhausted: bool
    identities: Table[ClientId, ClientState]
    byWindow: Table[WindowId, ClientId]
    managedOrder: seq[ClientId]
    focusOrder: seq[ClientId]
    focused: Option[ClientId]
    currentGroup*: RawGroup
    groupCount*: uint32
    activeGroups*: seq[bool]
    sparseActiveGroups: Table[uint32, bool]
    lastWindowFocus*: bool
    sloppyFocus*: bool
    pointerInteraction*: PointerInteraction
    pointerModifier*: uint16
    pointerLockMasks*: array[3, uint16]
    config*: WmConfiguration

  AddIdentityResult* = object
    state*: ClientState
    created*: bool

  AddRuntimeResult* = object
    state*: ClientState
    created*: bool

proc hash(id: WindowId): Hash {.borrow.}
proc hash(id: ClientId): Hash {.borrow.}

proc newWmState*(firstGeneration = 1'u64): WmState =
  if firstGeneration == 0:
    raise newException(ValueError, "client generation zero is reserved")
  result.nextGeneration = firstGeneration
  result.identities = initTable[ClientId, ClientState]()
  result.byWindow = initTable[WindowId, ClientId]()
  result.currentGroup = NullGroup
  result.groupCount = 10
  result.activeGroups = newSeq[bool](int(result.groupCount))
  result.sparseActiveGroups = initTable[uint32, bool]()
  result.lastWindowFocus = true
  result.sloppyFocus = true
  result.config = WmConfiguration(applySettings: true, borders: true,
      replayClickOnFocus: true, resizeHints: false,
      stickyWindows: false, borderStyle: 5, outerBorderWidth: 5,
      outerColorFocused: 0xff97a293'u32,
      outerColorUnfocused: 0xff393638'u32, cornerMask: 10,
      cornerPercent: 28, cursorPosition: 8, gapLeft: 0, gapDown: 0,
      gapUp: 0, gapRight: 0, innerBorderWidth: 0,
      innerColorFocused: 0xff393638'u32,
      innerColorUnfocused: 0xff97a293'u32, clickToFocus: 0,
      pointerActions: [2'u32, 4'u32, 3'u32])

proc groupIsActive*(state: WmState; group: RawGroup): bool =
  if group.raw < uint32(state.activeGroups.len):
    state.activeGroups[int(group.raw)]
  else:
    state.sparseActiveGroups.getOrDefault(group.raw)

proc setGroupActive*(state: var WmState; group: RawGroup; active: bool) =
  if group.raw < uint32(state.activeGroups.len):
    state.activeGroups[int(group.raw)] = active
  elif active:
    state.sparseActiveGroups[group.raw] = true
  elif state.sparseActiveGroups.hasKey(group.raw):
    state.sparseActiveGroups.del(group.raw)

proc activeGroupIds*(state: WmState): seq[RawGroup] =
  for index, active in state.activeGroups:
    if active: result.add(RawGroup(index))
  var sparse: seq[uint32]
  for group, active in state.sparseActiveGroups:
    if active and group < state.groupCount: sparse.add(group)
  sparse.sort()
  for group in sparse: result.add(RawGroup(group))

proc contains*(state: WmState; window: WindowId): bool =
  state.byWindow.hasKey(window)

proc lookup*(state: WmState; window: WindowId): Option[ClientState] =
  if not state.byWindow.hasKey(window): return none(ClientState)
  some(state.identities[state.byWindow[window]])

proc lookup*(state: WmState; id: ClientId): Option[ClientState] =
  if not state.identities.hasKey(id): return none(ClientState)
  some(state.identities[id])

proc replaceClient*(state: var WmState; client: ClientState): bool =
  if not state.identities.hasKey(client.id): return false
  state.identities[client.id] = client
  true

proc clientsInManagedOrder*(state: WmState): seq[ClientState] =
  result = newSeqOfCap[ClientState](state.managedOrder.len)
  for id in state.managedOrder:
    result.add(state.identities[id])

proc allocateIdentity(state: var WmState; epoch: ProcessEpoch;
                      window: WindowId; mapped: bool;
                      group: RawGroup; wmState: WmStateValue;
                      runtimeManaged = false;
                      decoration = none(WindowId);
                      x = 0'i16; y = 0'i16;
                      width = 0'u16; height = 0'u16;
                      hints = ResizeHints()): ClientState =
  if state.generationExhausted:
    raise newException(ValueError, "client identity generation exhausted")
  let generation = state.nextGeneration
  if generation == high(uint64):
    state.generationExhausted = true
  else:
    inc state.nextGeneration
  let id = ClientId(generation)
  result = ClientState(id: id, window: window,
      token: ClientToken(epoch: epoch,
                         generation: ClientGeneration(generation)),
      mapped: mapped, group: group, startupWmState: wmState,
      runtimeManaged: runtimeManaged, decoration: decoration,
      geometry: Geometry(x: int32(x), y: int32(y), width: uint32(width),
                          height: uint32(height)),
      origGeometry: Geometry(x: int32(x), y: int32(y), width: uint32(width),
                             height: uint32(height)),
      resizeHints: ResizeHints(widthIncrement: max(1'u32, hints.widthIncrement),
          heightIncrement: max(1'u32, hints.heightIncrement),
          minWidth: hints.minWidth, minHeight: hints.minHeight))

proc addAdoptedClient*(state: var WmState; epoch: ProcessEpoch;
                       window: WindowId; mapped: bool;
                       group: RawGroup; wmState: WmStateValue;
                       x = 0'i16; y = 0'i16; width = 0'u16; height = 0'u16;
                       setByUser = false; hints = ResizeHints()): AddIdentityResult =
  ## Duplicate adds are idempotent and preserve the existing token/order.
  if state.byWindow.hasKey(window):
    result.state = state.identities[state.byWindow[window]]
    result.created = false
    return
  let client = state.allocateIdentity(epoch, window, mapped, group, wmState,
      hints = hints)
  state.identities[client.id] = client
  state.byWindow[window] = client.id
  # C prepends each setup_window identity. Startup scans QueryTree bottom-to-top,
  # so this produces its resulting newest/topmost-first managed list.
  state.managedOrder.insert(client.id, 0)
  state.focusOrder.insert(client.id, 0)
  if group != NullGroup and group.raw < state.groupCount:
    state.setGroupActive(group, true)
  state.identities[client.id].geometry = Geometry(x: int32(x), y: int32(y),
      width: uint32(width), height: uint32(height))
  state.identities[client.id].origGeometry = state.identities[client.id].geometry
  state.identities[client.id].setByUser = setByUser
  result.state = client
  result.created = true

proc addRuntimeClient*(state: var WmState; epoch: ProcessEpoch;
                       window, decoration: WindowId;
                       group: RawGroup; x = 0'i16; y = 0'i16;
                       width = 0'u16; height = 0'u16; setByUser = false;
                       hints = ResizeHints()): AddRuntimeResult =
  ## Runtime identities use the same C prepend semantics as setup_window.
  ## A duplicate XID is idempotent and never receives a second token.
  if state.byWindow.hasKey(window):
    result.state = state.identities[state.byWindow[window]]
    result.created = false
    return
  var client = state.allocateIdentity(epoch, window, false, group,
      wsvAbsent, true, some(decoration), x, y, width, height, hints)
  client.setByUser = setByUser
  state.identities[client.id] = client
  state.byWindow[window] = client.id
  state.managedOrder.insert(client.id, 0)
  state.focusOrder.insert(client.id, 0)
  if group != NullGroup and group.raw < state.groupCount:
    state.setGroupActive(group, true)
  result.state = client
  result.created = true

proc lookupDecoration*(state: WmState; decoration: WindowId): Option[ClientState] =
  for id in state.managedOrder:
    let client = state.identities[id]
    if client.decoration.isSome and client.decoration.get == decoration:
      return some(client)
  none(ClientState)

proc confirmMapped*(state: var WmState; window: WindowId; mapped: bool): bool =
  if not state.byWindow.hasKey(window): return false
  let id = state.byWindow[window]
  state.identities[id].mapped = mapped
  true

proc removeIdentity*(state: var WmState; window: WindowId): bool =
  if not state.byWindow.hasKey(window): return false
  let id = state.byWindow[window]
  state.byWindow.del(window)
  state.identities.del(id)
  let index = state.managedOrder.find(id)
  if index >= 0: state.managedOrder.delete(index)
  let focusIndex = state.focusOrder.find(id)
  if focusIndex >= 0: state.focusOrder.delete(focusIndex)
  if state.focused.isSome and state.focused.get == id:
    state.focused = none(ClientId)
    state.currentGroup = NullGroup
  true

proc identityCount*(state: WmState): int = state.managedOrder.len

proc focusedClient*(state: WmState): Option[ClientState] =
  if state.focused.isNone: return none(ClientState)
  state.lookup(state.focused.get)

proc focusedId*(state: WmState): Option[ClientId] = state.focused

proc focusOrderClients*(state: WmState): seq[ClientState] =
  for id in state.focusOrder:
    if state.identities.hasKey(id): result.add(state.identities[id])

proc setFocused*(state: var WmState; id: ClientId) =
  if not state.identities.hasKey(id): return
  let index = state.focusOrder.find(id)
  if index >= 0: state.focusOrder.delete(index)
  state.focusOrder.insert(id, 0)
  state.focused = some(id)
  state.currentGroup = state.identities[id].group

proc setPointerModifiers*(state: var WmState; modifier: uint16;
                          numLock, capsLock, scrollLock: uint16) =
  state.pointerModifier = modifier
  state.pointerLockMasks = [numLock, capsLock, scrollLock]

proc setConfiguredGroupCount*(state: var WmState; count: uint32):
    tuple[represented: bool, changedClients: seq[ClientState]] =
  ## Mirrors change_nr_of_groups without allocating one model slot per
  ## configured group. High group IDs use the sparse active-state table.
  let oldCount = state.groupCount
  if count < oldCount:
    for client in state.clientsInManagedOrder():
      if client.group != NullGroup and client.group.raw >= count:
        var updated = client
        updated.group = NullGroup
        if state.replaceClient(updated): result.changedClients.add(updated)
        if state.focused.isSome and state.focused.get == client.id:
          state.currentGroup = NullGroup
  state.groupCount = count
  if count < uint32(state.activeGroups.len):
    state.activeGroups.setLen(int(count))
  var staleGroups: seq[uint32]
  for group in state.sparseActiveGroups.keys:
    if group >= count: staleGroups.add(group)
  for group in staleGroups: state.sparseActiveGroups.del(group)
  result.represented = true

proc clearFocused*(state: var WmState) =
  state.focused = none(ClientId)
  state.currentGroup = NullGroup

proc setClientGroup*(state: var WmState; id: ClientId; group: RawGroup): bool =
  if not state.identities.hasKey(id): return false
  if group != NullGroup and group.raw >= state.groupCount: return false
  state.identities[id].group = group
  if group != NullGroup and group.raw < state.groupCount:
    state.setGroupActive(group, true)
  if state.focused.isSome and state.focused.get == id:
    state.currentGroup = group
  true

proc groupClients*(state: WmState; group: RawGroup): seq[ClientState] =
  for id in state.managedOrder:
    let client = state.identities[id]
    if client.group == group: result.add(client)

proc setGroupPending*(state: var WmState; window: WindowId; mapPending,
                      unmapPending: bool) =
  if not state.byWindow.hasKey(window): return
  let id = state.byWindow[window]
  state.identities[id].groupMapPending = mapPending
  state.identities[id].groupUnmapPending = unmapPending

proc setGroupMapPending*(state: var WmState; window: WindowId; pending: bool) =
  if state.byWindow.hasKey(window):
    state.identities[state.byWindow[window]].groupMapPending = pending

proc setGroupUnmapPending*(state: var WmState; window: WindowId; pending: bool) =
  if state.byWindow.hasKey(window):
    state.identities[state.byWindow[window]].groupUnmapPending = pending

proc completeStartupClient*(state: var WmState; window, decoration: WindowId;
                             x, y: int16; width, height: uint16;
                             setByUser = false): Option[ClientState] =
  if not state.byWindow.hasKey(window): return none(ClientState)
  let id = state.byWindow[window]
  state.identities[id].decoration = some(decoration)
  state.identities[id].runtimeManaged = true
  state.identities[id].geometry = Geometry(x: int32(x), y: int32(y),
      width: uint32(width), height: uint32(height))
  state.identities[id].origGeometry = state.identities[id].geometry
  state.identities[id].setByUser = setByUser
  some(state.identities[id])

proc confirmMap*(state: var WmState; window: WindowId):
    tuple[known: bool, autofocus: bool] =
  if not state.byWindow.hasKey(window): return
  let id = state.byWindow[window]
  result.known = true
  result.autofocus = not state.identities[id].groupMapPending
  state.identities[id].mapped = true
  state.identities[id].groupMapPending = false

proc confirmUnmap*(state: var WmState; window: WindowId):
    tuple[known: bool, wasFocused: bool, groupPending: bool] =
  if not state.byWindow.hasKey(window): return
  let id = state.byWindow[window]
  result.known = true
  result.wasFocused = state.focused.isSome and state.focused.get == id
  result.groupPending = state.identities[id].groupUnmapPending
  state.identities[id].mapped = false
  state.identities[id].groupUnmapPending = false
