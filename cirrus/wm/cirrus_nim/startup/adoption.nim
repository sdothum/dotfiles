## Frozen C startup eligibility translated from pointer-free X11 observations.

import std/options
import ../model/[types, state]
import ../x11/[connection, queries, atoms]

const
  MapStateViewable = 2'u8
  WmStateWithdrawn = 0'u32
  WmStateNormal = 1'u32
  WmStateIconic = 3'u32

type
  AdoptionDecision* = object
    adopted*: bool
    mapped*: bool
    group*: RawGroup
    wmState*: WmStateValue

proc decodeWmState(observation: StartupWindowObservation): WmStateValue =
  let value = observation.wmState.propertyValue()
  if value.isNone or observation.wmState.format != 32 or
      observation.wmState.typeAtom == 0:
    return wsvAbsent
  case value.get
  of WmStateNormal: wsvNormal
  of WmStateIconic: wsvIconic
  of WmStateWithdrawn: wsvWithdrawn
  else: wsvOther

proc desktopGroup(observation: StartupWindowObservation;
                  groupCount: uint32): Option[RawGroup] =
  let desktop = observation.desktop.propertyValue()
  if desktop.isSome and observation.desktop.format == 32 and
      observation.desktop.typeAtom != 0 and desktop.get < groupCount:
    some(RawGroup(desktop.get))
  else:
    none(RawGroup)

proc isSpecial(observation: StartupWindowObservation;
               atoms: Atoms): bool =
  for atom in observation.windowTypes.values:
    if atom == atoms.netWmWindowTypeDock or
        atom == atoms.netWmWindowTypeToolbar or
        atom == atoms.netWmWindowTypeDesktop:
      return true

proc parseResizeHints*(property: Property32): ResizeHints =
  let values = property.values
  result.widthIncrement = 1
  result.heightIncrement = 1
  if not property.present or property.format != 32 or values.len < 11:
    return
  if (values[0] and (1'u32 shl 4)) != 0:
    result.minWidth = values[5]
    result.minHeight = values[6]
  if (values[0] and (1'u32 shl 6)) != 0:
    result.widthIncrement = max(1'u32, values[9])
    result.heightIncrement = max(1'u32, values[10])

proc decideAdoption*(observation: StartupWindowObservation;
                     atoms: Atoms; groupCount: uint32): AdoptionDecision =
  result.mapped = observation.mapState == MapStateViewable
  result.wmState = decodeWmState(observation)
  result.group = if groupCount > 1: RawGroup(1) else: NullGroup

  if observation.overrideRedirect or observation.isSpecial(atoms):
    return

  if result.mapped:
    result.adopted = true
    let group = observation.desktopGroup(groupCount)
    if group.isSome: result.group = group.get
    return

  # The current C implementation recognizes a pre-existing hidden client only
  # from the exact Normal + valid CARDINAL desktop combination.
  if result.wmState == wsvNormal:
    let group = observation.desktopGroup(groupCount)
    if group.isSome:
      result.adopted = true
      result.group = group.get
      result.mapped = false

proc adoptStartup*(connection: XConnection; state: var WmState;
                   epoch: ProcessEpoch; groupCount: uint32 = 10) =
  for observation in connection.queryStartupWindows():
    let decision = observation.decideAdoption(connection.atoms, groupCount)
    if decision.adopted:
      let hints = parseResizeHints(observation.normalHints)
      discard state.addAdoptedClient(epoch, WindowId(observation.window),
          decision.mapped, decision.group, decision.wmState,
          observation.x, observation.y, observation.width, observation.height,
          observation.normalHints.values.len > 0 and
          (observation.normalHints.values[0] and 1'u32) != 0, hints)
      let adopted = state.lookup(WindowId(observation.window))
      if adopted.isSome:
        var client = adopted.get
        for atom in observation.netWmState.values:
          if atom == connection.atoms.netWmStateAbove:
            client.layer = wlAbove
        discard state.replaceClient(client)
