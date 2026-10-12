## Copies the fields Stage 1 needs out of XCB's allocated event record, then
## frees that record before returning. This data type contains no XCB pointers.

import std/options
import ./bindings

type
  XEventData* = object
    responseType*: uint8
    fullSequence*: uint32
    errorCode*, errorMajorCode*: uint8
    errorMinorCode*: uint16
    errorResourceId*: uint32
    eventWindow*, window*, parent*: uint32
    atom*: uint32
    propertyState*: uint8
    overrideRedirect*: bool
    fromConfigure*: bool
    detail*, mode*: uint8
    rootX*, rootY*: int16
    eventX*, eventY*: int16
    child*, root*: uint32
    state*, time*: uint32
    valueMask*: uint16
    sibling*: uint32
    stackMode*: uint8
    circulatePlace*: uint8
    aboveSibling*: uint32
    x*, y*: int16
    width*, height*, borderWidth*: uint16
    messageType*: uint32
    format*: uint8
    data32*: array[5, uint32]

proc readEvent*(connection: ptr XcbConnection): Option[XEventData] =
  let raw = xcbPollForEvent(connection)
  if raw == nil:
    return none(XEventData)
  defer: cFree(raw)
  var data = XEventData(responseType: raw.responseType,
      fullSequence: cast[ptr XcbGenericEvent](raw).fullSequence)
  let eventKind = raw.responseType and 0x7f'u8
  if eventKind == 0:
    let error = cast[ptr XcbGenericError](raw)
    data.errorCode = error.errorCode
    data.errorMajorCode = error.majorCode
    data.errorMinorCode = error.minorCode
    data.errorResourceId = error.resourceId
  case eventKind
  of EventMapRequest:
    let event = cast[ptr XcbMapRequestEvent](raw)
    data.parent = event.parent
    data.window = event.window
    data.eventWindow = event.parent
  of EventMapNotify:
    let event = cast[ptr XcbMapNotifyEvent](raw)
    data.eventWindow = event.event
    data.window = event.window
    data.overrideRedirect = event.overrideRedirect != 0
  of EventUnmapNotify:
    let event = cast[ptr XcbUnmapNotifyEvent](raw)
    data.eventWindow = event.event
    data.window = event.window
    data.fromConfigure = event.fromConfigure != 0
  of EventDestroyNotify:
    let event = cast[ptr XcbDestroyNotifyEvent](raw)
    data.eventWindow = event.event
    data.window = event.window
  of EventConfigureRequest:
    let event = cast[ptr XcbConfigureRequestEvent](raw)
    data.parent = event.parent
    data.eventWindow = event.parent
    data.window = event.window
    data.sibling = event.sibling
    data.stackMode = event.stackMode
    data.x = event.x
    data.y = event.y
    data.width = event.width
    data.height = event.height
    data.borderWidth = event.borderWidth
    data.valueMask = event.valueMask
  of EventCirculateRequest:
    let event = cast[ptr XcbCirculateRequestEvent](raw)
    data.eventWindow = event.event
    data.window = event.window
    data.circulatePlace = event.place
  of EventConfigureNotify:
    let event = cast[ptr XcbConfigureNotifyEvent](raw)
    data.eventWindow = event.event
    data.window = event.window
    data.aboveSibling = event.aboveSibling
    data.x = event.x
    data.y = event.y
    data.width = event.width
    data.height = event.height
    data.borderWidth = event.borderWidth
  of EventPropertyNotify:
    let event = cast[ptr XcbPropertyNotifyEvent](raw)
    data.eventWindow = event.window
    data.window = event.window
    data.atom = event.atom
    data.propertyState = event.state
  of EventClientMessage:
    let event = cast[ptr XcbClientMessageEvent](raw)
    data.eventWindow = event.window
    data.window = event.window
    data.messageType = event.messageType
    data.format = event.format
    # C's managed state handler reads the data32 union regardless of format.
    # Keep the same wire bytes available for format-8/16 ClientMessages.
    data.data32 = event.data.data32
  of EventFocusIn, EventFocusOut:
    let event = cast[ptr XcbFocusEvent](raw)
    data.eventWindow = event.event
    data.window = event.event
    data.detail = event.detail
    data.mode = event.mode
  of EventEnterNotify:
    let event = cast[ptr XcbEnterNotifyEvent](raw)
    data.eventWindow = event.event
    data.window = event.event
    data.detail = event.detail
    data.mode = event.mode
    data.rootX = event.rootX
    data.rootY = event.rootY
  of EventButtonPress, EventButtonRelease:
    let event = cast[ptr XcbButtonPressEvent](raw)
    data.eventWindow = event.event
    data.window = event.event
    data.child = event.child
    data.root = event.root
    data.detail = event.detail
    data.time = event.time
    data.state = event.state
    data.rootX = event.rootX
    data.rootY = event.rootY
    data.eventX = event.eventX
    data.eventY = event.eventY
  of EventMotionNotify:
    let event = cast[ptr XcbMotionNotifyEvent](raw)
    data.eventWindow = event.event
    data.window = event.event
    data.child = event.child
    data.root = event.root
    data.detail = event.detail
    data.time = event.time
    data.state = event.state
    data.rootX = event.rootX
    data.rootY = event.rootY
    data.eventX = event.eventX
    data.eventY = event.eventY
  else:
    discard
  some(data)
