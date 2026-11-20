## Pointer-free observations used to decide whether a runtime MapRequest can be
## adopted. All XCB replies and property buffers are freed here.

import std/options
import ./[bindings, connection, queries]

type
  RuntimeWindowObservation* = object
    window*: uint32
    mapped*: bool
    overrideRedirect*: bool
    x*, y*: int16
    width*, height*: uint16
    desktop*: Property32
    windowTypes*: Property32
    netWmState*: Property32
    normalHints*: Property32
    setByUser*: bool

proc queryRuntimeWindow*(connection: XConnection;
                         window: uint32): Option[RuntimeWindowObservation] =
  let raw = connection.rawHandleForX11()
  var error: ptr XcbGenericError
  let attributes = xcbGetWindowAttributesReply(raw,
      xcbGetWindowAttributes(raw, window), addr error)
  if error != nil: cFree(error)
  if attributes == nil: return none(RuntimeWindowObservation)
  var observation = RuntimeWindowObservation(window: window,
      mapped: attributes.mapState == MapStateViewable,
      overrideRedirect: attributes.overrideRedirect != 0)
  cFree(attributes)

  error = nil
  let geometry = xcbGetGeometryReply(raw, xcbGetGeometry(raw, window), addr error)
  if error != nil: cFree(error)
  if geometry == nil: return none(RuntimeWindowObservation)
  observation.x = geometry.x
  observation.y = geometry.y
  observation.width = geometry.width
  observation.height = geometry.height
  cFree(geometry)
  observation.desktop = readRuntimeProperty(connection, window,
      connection.atoms.netWmDesktop, connection.atoms.cardinal)
  observation.windowTypes = readRuntimeProperty(connection, window,
      connection.atoms.netWmWindowType, connection.atoms.atom)
  observation.netWmState = readRuntimeProperty(connection, window,
      connection.atoms.netWmState, connection.atoms.atom)
  let hints = readRuntimeProperty(connection, window,
      connection.atoms.wmNormalHints, connection.atoms.wmSizeHints)
  observation.normalHints = hints
  observation.setByUser = hints.values.len > 0 and (hints.values[0] and 1'u32) != 0
  some(observation)

proc runtimeWindowExists*(connection: XConnection; window: uint32): bool =
  ## Observation used only after the model has resolved a managed target.
  ## Frozen C's Above layer setter performs this attributes round trip before
  ## committing its logical layer, which rejects a destroyed stale record but
  ## still permits a replacement resource with the same XID.
  let raw = connection.rawHandleForX11()
  var error: ptr XcbGenericError
  let reply = xcbGetWindowAttributesReply(raw,
      xcbGetWindowAttributes(raw, window), addr error)
  if error != nil: cFree(error)
  if reply == nil: return false
  cFree(reply)
  true

proc selectPropertyChanges*(connection: XConnection; window: uint32) =
  ## C layer enforcement subscribes to property changes on unmanaged root
  ## children so later DOCK/ABOVE changes can trigger another refresh.
  let raw = connection.rawHandleForX11()
  var error: ptr XcbGenericError
  let reply = xcbGetWindowAttributesReply(raw,
      xcbGetWindowAttributes(raw, window), addr error)
  if error != nil: cFree(error)
  if reply == nil: return
  let existing = reply.yourEventMask
  cFree(reply)
  if (existing and EventMaskPropertyChange) != 0: return
  var mask = existing or EventMaskPropertyChange
  discard xcbChangeWindowAttributes(raw, window, CwEventMask, addr mask)

proc queryWmDeleteSupported*(connection: XConnection;
                             window: uint32): Option[bool] =
  ## Fresh WM_PROTOCOLS observation. `some(false)` is a valid absent or
  ## unsupported capability; `none` means the property could not be trusted.
  let raw = connection.rawHandleForX11()
  var error: ptr XcbGenericError
  let reply = xcbGetPropertyReply(raw,
      xcbGetProperty(raw, 0, window, connection.atoms.wmProtocols,
          connection.atoms.atom, 0, 4096), addr error)
  if error != nil:
    cFree(error)
    if reply != nil: cFree(reply)
    return none(bool)
  if reply == nil: return none(bool)
  if reply.typeAtom == 0:
    cFree(reply)
    return some(false)
  if reply.typeAtom != connection.atoms.atom or reply.format != 32 or
      reply.bytesAfter != 0 or
      xcbGetPropertyValueLength(reply) < 0:
    cFree(reply)
    return none(bool)
  let count = min(int(reply.valueLen),
      xcbGetPropertyValueLength(reply) div 4)
  let values = cast[ptr UncheckedArray[uint32]](xcbGetPropertyValue(reply))
  for index in 0 ..< count:
    if values[index] == connection.atoms.wmDeleteWindow:
      cFree(reply)
      return some(true)
  cFree(reply)
  some(false)

proc isSpecialRuntimeType*(observation: RuntimeWindowObservation;
                           connection: XConnection): bool =
  for atom in observation.windowTypes.values:
    if atom == connection.atoms.netWmWindowTypeDock or
        atom == connection.atoms.netWmWindowTypeToolbar or
        atom == connection.atoms.netWmWindowTypeDesktop:
      return true
