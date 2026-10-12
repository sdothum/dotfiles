## Pointer-free startup observations. XCB reply ownership ends in this module.

import std/options
import ./[bindings, connection]

type
  Property32* = object
    present*: bool
    typeAtom*: uint32
    format*: uint8
    values*: seq[uint32]

  StartupWindowObservation* = object
    window*: uint32
    mapState*: uint8
    overrideRedirect*: bool
    wmState*: Property32
    desktop*: Property32
    windowTypes*: Property32
    netWmState*: Property32
    x*, y*: int16
    width*, height*: uint16
    normalHints*: Property32

  PointerPosition* = object
    x*, y*: int16

  StackingEnterGuard* = object
    active*: bool
    rootX*, rootY*: int16
    lowerSequence*: uint32
    focusWindow*: uint32

  StackingEnterSuppression* = object
    rootX*, rootY*: int16
    lowerSequence*, upperSequence*: uint32
    focusWindow*: uint32

proc readProperty(connection: XConnection; window, property,
                  expectedType: uint32): Property32 =
  let raw = connection.rawHandleForX11()
  var offset = 0'u32
  while true:
    var error: ptr XcbGenericError
    let cookie = xcbGetProperty(raw, 0, window, property, expectedType,
                                offset, 64)
    let reply = xcbGetPropertyReply(raw, cookie, addr error)
    if error != nil: cFree(error)
    if reply == nil: break
    if offset == 0:
      result.present = reply.typeAtom != 0
      result.typeAtom = reply.typeAtom
      result.format = reply.format
    if reply.typeAtom == 0 or reply.format != 32:
      cFree(reply)
      break
    let count = min(int(reply.valueLen), xcbGetPropertyValueLength(reply) div 4)
    let values = cast[ptr UncheckedArray[uint32]](xcbGetPropertyValue(reply))
    for index in 0 ..< count:
      result.values.add(values[index])
    let moreBytes = reply.bytesAfter
    cFree(reply)
    if moreBytes == 0: break
    if count == 0:
      raise newException(IOError, "X property query made no progress")
    offset += uint32(count)

proc readRuntimeProperty*(connection: XConnection; window, property,
                          expectedType: uint32): Property32 =
  readProperty(connection, window, property, expectedType)

proc hasDefaultAbovePriority*(connection: XConnection; window: uint32): bool =
  ## C's unmanaged-root-child tier is Above for DOCK or _NET_WM_STATE_ABOVE.
  let types = connection.readRuntimeProperty(window,
      connection.atoms.netWmWindowType, connection.atoms.atom)
  let states = connection.readRuntimeProperty(window,
      connection.atoms.netWmState, connection.atoms.atom)
  for atom in types.values:
    if atom == connection.atoms.netWmWindowTypeDock: return true
  for atom in states.values:
    if atom == connection.atoms.netWmStateAbove: return true
  false

proc queryRootPointer*(connection: XConnection): PointerPosition =
  let raw = connection.rawHandleForX11()
  var error: ptr XcbGenericError
  let reply = xcbQueryPointerReply(raw,
      xcbQueryPointer(raw, connection.root), addr error)
  if error != nil:
    let code = error.errorCode
    cFree(error)
    raise newException(IOError, "XQueryPointer failed (X error " & $code & ")")
  if reply == nil:
    raise newException(IOError, "XQueryPointer returned no reply")
  result = PointerPosition(x: reply.rootX, y: reply.rootY)
  cFree(reply)

proc beginStackingEnterGuard*(connection: XConnection): StackingEnterGuard =
  ## Capture C's explicit-stacking guard boundary. The sequence interval lets
  ## the runtime distinguish restack-generated crossings from later motion.
  let raw = connection.rawHandleForX11()
  let cookie = xcbQueryPointer(raw, connection.root)
  var error: ptr XcbGenericError
  let reply = xcbQueryPointerReply(raw, cookie, addr error)
  if error != nil:
    cFree(error)
    if reply != nil: cFree(reply)
    return
  if reply != nil:
    result.active = reply.sameScreen != 0
    result.rootX = reply.rootX
    result.rootY = reply.rootY
    result.lowerSequence = uint32(cookie.sequence)
    cFree(reply)

proc finishStackingEnterGuard*(connection: XConnection;
    guard: StackingEnterGuard; focusUnchanged: bool): Option[StackingEnterSuppression] =
  if not guard.active or not focusUnchanged: return none(StackingEnterSuppression)
  let raw = connection.rawHandleForX11()
  let cookie = xcbQueryPointer(raw, connection.root)
  var error: ptr XcbGenericError
  let reply = xcbQueryPointerReply(raw, cookie, addr error)
  if error != nil:
    cFree(error)
    if reply != nil: cFree(reply)
    return none(StackingEnterSuppression)
  if reply == nil: return none(StackingEnterSuppression)
  let unchanged = reply.sameScreen != 0 and reply.rootX == guard.rootX and
      reply.rootY == guard.rootY
  cFree(reply)
  if unchanged:
    return some(StackingEnterSuppression(rootX: guard.rootX, rootY: guard.rootY,
        lowerSequence: guard.lowerSequence, upperSequence: uint32(cookie.sequence),
        focusWindow: guard.focusWindow))
  none(StackingEnterSuppression)

proc queryStartupWindows*(connection: XConnection): seq[StartupWindowObservation] =
  let raw = connection.rawHandleForX11()
  var error: ptr XcbGenericError
  let tree = xcbQueryTreeReply(raw, xcbQueryTree(raw, connection.root), addr error)
  if error != nil:
    let code = error.errorCode
    cFree(error)
    raise newException(IOError, "XQueryTree failed (X error " & $code & ")")
  if tree == nil:
    raise newException(IOError, "XQueryTree returned no reply")
  let childCount = xcbQueryTreeChildrenLength(tree)
  let children = xcbQueryTreeChildren(tree)
  let childIds = cast[ptr UncheckedArray[uint32]](children)
  try:
    for index in 0 ..< childCount:
      let window = childIds[index]
      var attrError: ptr XcbGenericError
      let attrReply = xcbGetWindowAttributesReply(raw,
          xcbGetWindowAttributes(raw, window), addr attrError)
      if attrError != nil: cFree(attrError)
      if attrReply == nil: continue
      var observation = StartupWindowObservation(
          window: window,
          mapState: attrReply.mapState,
          overrideRedirect: attrReply.overrideRedirect != 0)
      cFree(attrReply)
      var geometryError: ptr XcbGenericError
      let geometry = xcbGetGeometryReply(raw,
          xcbGetGeometry(raw, window), addr geometryError)
      if geometryError != nil: cFree(geometryError)
      if geometry == nil: continue
      observation.x = geometry.x
      observation.y = geometry.y
      observation.width = geometry.width
      observation.height = geometry.height
      cFree(geometry)
      observation.normalHints = readProperty(connection, window,
          connection.atoms.wmNormalHints, connection.atoms.wmSizeHints)
      observation.wmState = readProperty(connection, window,
          connection.atoms.wmState, connection.atoms.wmState)
      observation.desktop = readProperty(connection, window,
          connection.atoms.netWmDesktop, connection.atoms.cardinal)
      observation.windowTypes = readProperty(connection, window,
          connection.atoms.netWmWindowType, connection.atoms.atom)
      observation.netWmState = readProperty(connection, window,
          connection.atoms.netWmState, connection.atoms.atom)
      result.add(observation)
  finally:
    cFree(tree)

proc propertyValue*(property: Property32): Option[uint32] =
  if property.present and property.format == 32 and property.values.len > 0:
    some(property.values[0])
  else:
    none(uint32)
