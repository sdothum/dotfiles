## X-free stacking selection and priority rules. Physical order is supplied as
## a fresh, normalized bottom-to-top observation by the runtime.

import std/[options, sets]
import ./[types, state]

type
  StackObservation* = object
    ## Managed client windows only, in root QueryTree bottom-to-top order.
    ## Decorations and unmanaged root children are intentionally absent here.
    managedBottomToTop*: seq[WindowId]
    rootChildrenBottomToTop*: seq[WindowId]
    unmanagedAbove*: seq[WindowId]

proc overlaps*(a, b: Geometry): bool =
  if a.width == 0 or a.height == 0 or b.width == 0 or b.height == 0:
    return false
  let ax2 = int64(a.x) + int64(a.width)
  let ay2 = int64(a.y) + int64(a.height)
  let bx2 = int64(b.x) + int64(b.width)
  let by2 = int64(b.y) + int64(b.height)
  int64(a.x) < bx2 and ax2 > int64(b.x) and
    int64(a.y) < by2 and ay2 > int64(b.y)

proc effectivePriority*(client: ClientState): StackPriority =
  case client.layer
  of wlOverlay: spOverlay
  of wlAbove:
    if client.maxed or client.monocled: spZoomed else: spAbove
  of wlNormal:
    if client.maxed or client.monocled: spZoomed else: spNormal

proc orderedMappedClients(state: WmState; observed: StackObservation): seq[ClientState] =
  var seen = initHashSet[WindowId]()
  for window in observed.managedBottomToTop:
    if window in seen: continue
    seen.incl(window)
    let found = state.lookup(window)
    if found.isSome and found.get.mapped:
      result.add(found.get)

proc overlapClosure*(state: WmState; observed: StackObservation;
                     anchor: WindowId): seq[ClientState] =
  let candidates = state.orderedMappedClients(observed)
  var included = newSeq[bool](candidates.len)
  var anchorIndex = -1
  for index, client in candidates:
    if client.window == anchor:
      anchorIndex = index
      break
  if anchorIndex < 0: return
  included[anchorIndex] = true
  var changed = true
  while changed:
    changed = false
    for i, candidate in candidates:
      if included[i]: continue
      for j, member in candidates:
        if included[j] and overlaps(candidate.geometry, member.geometry):
          included[i] = true
          changed = true
          break
  for index, client in candidates:
    if included[index]: result.add(client)

proc cycleTarget*(state: WmState; closure: openArray[ClientState];
                  anchor: WindowId): Option[ClientState] =
  if closure.len <= 1: return none(ClientState)
  var referenceIndex = -1
  for index, client in closure:
    if client.window == anchor:
      referenceIndex = index
      break
  if referenceIndex < 0: return none(ClientState)
  let reference = closure[referenceIndex]
  var mixed = false
  for client in closure:
    if effectivePriority(client) != effectivePriority(reference):
      mixed = true
      break
  if not mixed:
    # C returns the reference until it is physically topmost, then wraps to
    # the bottom member. The caller performs the ordinary focus/raise path.
    if referenceIndex == closure.len - 1:
      return some(closure[0])
    return some(reference)
  # focusOrderClients is newest-to-oldest. C overwrites the candidate as it
  # traverses, so the final eligible overlap member is the least recent one.
  for client in state.focusOrderClients:
    if client.window == anchor: continue
    for member in closure:
      if client.id == member.id:
        result = some(member)
        break

proc normalizedManagedOrder*(state: WmState; physicalBottomToTop: openArray[WindowId]):
    seq[WindowId] =
  ## Filter a root order observation to mapped managed clients; never infer it
  ## from managed identity order or _NET_CLIENT_LIST_STACKING.
  var seen = initHashSet[WindowId]()
  for window in physicalBottomToTop:
    if window in seen: continue
    seen.incl(window)
    let found = state.lookup(window)
    if found.isSome and found.get.mapped: result.add(window)

proc priorityForWindow(state: WmState; observation: StackObservation;
                       window: WindowId;
                       snapshot: openArray[StackingLayerSnapshot]): int =
  for client in snapshot:
    if client.window == window or client.decoration == window:
      if client.layer == wlOverlay: return int(spOverlay)
      if client.maxed or client.monocled: return int(spZoomed)
      if client.layer == wlAbove: return int(spAbove)
      return int(spNormal)
  let client = state.lookup(window)
  if client.isSome: return int(effectivePriority(client.get))
  let owner = state.lookupDecoration(window)
  if owner.isSome: return int(effectivePriority(owner.get))
  if window in observation.unmanagedAbove: return int(spAbove)
  -1

proc restackedRootOrder*(state: WmState; observation: StackObservation;
                         snapshot: openArray[StackingLayerSnapshot]):
    seq[WindowId] =
  ## Mirrors C restack_layers: stable ordering within each tier, while
  ## unmanaged non-Above root children retain their physical slots.
  let original = observation.rootChildrenBottomToTop
  result = original
  var slot = 0
  for priority in int(spNormal) .. int(spOverlay):
    for window in original:
      if state.priorityForWindow(observation, window, snapshot) != priority: continue
      while slot < result.len and
          state.priorityForWindow(observation, result[slot], snapshot) < 0:
        inc slot
      if slot < result.len:
        result[slot] = window
        inc slot

proc restackedRootOrder*(state: WmState; observation: StackObservation):
    seq[WindowId] =
  state.restackedRootOrder(observation, newSeq[StackingLayerSnapshot]())
