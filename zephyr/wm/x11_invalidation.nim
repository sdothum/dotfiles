type
  XcbConnection {.importc: "xcb_connection_t", incompleteStruct.} = object
  XcbSetup {.importc: "xcb_setup_t", incompleteStruct.} = object
  XcbGenericError {.importc: "xcb_generic_error_t", incompleteStruct.} = object

  XcbWindow = uint32
  XcbAtom = uint32

  XcbGenericEvent {.importc: "xcb_generic_event_t".} = object
    responseType {.importc: "response_type".}: uint8
    pad0 {.importc: "pad0".}: uint8
    sequence: uint16
    pad: array[7, uint32]
    fullSequence {.importc: "full_sequence".}: uint32

  XcbPropertyNotifyEvent {.importc: "xcb_property_notify_event_t".} = object
    responseType {.importc: "response_type".}: uint8
    pad0 {.importc: "pad0".}: uint8
    sequence: uint16
    window {.importc: "window".}: XcbWindow
    atom {.importc: "atom".}: XcbAtom
    time {.importc: "time".}: uint32
    state: uint8
    pad: array[3, uint8]

  XcbScreen = object
    root: XcbWindow

  XcbScreenIterator {.importc: "xcb_screen_iterator_t".} = object
    data: ptr XcbScreen
    rem: cint
    index: cint

  XcbInternAtomCookie {.importc: "xcb_intern_atom_cookie_t".} = object
    sequence: cuint

  XcbInternAtomReply {.importc: "xcb_intern_atom_reply_t".} = object
    responseType: uint8
    pad0: uint8
    sequence: uint16
    length: uint32
    atom: XcbAtom

  XcbVoidCookie {.importc: "xcb_void_cookie_t".} = object
    sequence: cuint

const
  XcbPropertyNotify = 28'u8
  XcbPropertyChangeMask = 1'u32 shl 22
  XcbCWEventMask = 1'u32 shl 11

{.passL: "-lxcb".}

proc xcb_connect(displayName: cstring, screen: ptr cint): ptr XcbConnection
  {.importc, cdecl, header: "xcb/xcb.h".}
proc xcb_connection_has_error(connection: ptr XcbConnection): cint
  {.importc, cdecl, header: "xcb/xcb.h".}
proc xcb_get_file_descriptor(connection: ptr XcbConnection): cint
  {.importc, cdecl, header: "xcb/xcb.h".}
proc xcb_disconnect(connection: ptr XcbConnection)
  {.importc, cdecl, header: "xcb/xcb.h".}
proc xcb_get_setup(connection: ptr XcbConnection): ptr XcbSetup
  {.importc, cdecl, header: "xcb/xcb.h".}
proc xcb_setup_roots_iterator(setup: ptr XcbSetup): XcbScreenIterator
  {.importc, cdecl, header: "xcb/xcb.h".}
proc xcb_intern_atom(
  connection: ptr XcbConnection,
  onlyIfExists: uint8,
  nameLength: uint16,
  name: cstring
): XcbInternAtomCookie {.importc, cdecl, header: "xcb/xcb.h".}
proc xcb_intern_atom_reply(
  connection: ptr XcbConnection,
  cookie: XcbInternAtomCookie,
  error: ptr ptr XcbGenericError
): ptr XcbInternAtomReply {.importc, cdecl, header: "xcb/xcb.h".}
proc xcb_change_window_attributes(
  connection: ptr XcbConnection,
  window: XcbWindow,
  valueMask: uint32,
  values: ptr uint32
): XcbVoidCookie {.importc, cdecl, header: "xcb/xcb.h".}
proc xcb_flush(connection: ptr XcbConnection): cint
  {.importc, cdecl, header: "xcb/xcb.h".}
proc xcb_wait_for_event(connection: ptr XcbConnection): ptr XcbGenericEvent
  {.importc, cdecl, header: "xcb/xcb.h".}
proc xcb_poll_for_event(connection: ptr XcbConnection): ptr XcbGenericEvent
  {.importc, cdecl, header: "xcb/xcb.h".}
proc c_free(value: pointer) {.importc: "free", cdecl, header: "stdlib.h".}

type X11Invalidation* = object
  connection: pointer
  root: XcbWindow
  atom: XcbAtom
  titleAtoms: array[2, XcbAtom]

proc close*(event: var X11Invalidation) =
  if event.connection != nil:
    xcb_disconnect(cast[ptr XcbConnection](event.connection))
    event.connection = nil

proc descriptor*(event: X11Invalidation): cint =
  if event.connection == nil:
    return -1
  xcb_get_file_descriptor(cast[ptr XcbConnection](event.connection))

proc healthy*(event: X11Invalidation): bool =
  event.connection != nil and
    xcb_connection_has_error(cast[ptr XcbConnection](event.connection)) == 0

proc open*(event: var X11Invalidation): bool =
  event.close()
  var screenNumber: cint
  let connection = xcb_connect(nil, addr screenNumber)
  if connection == nil or xcb_connection_has_error(connection) != 0:
    if connection != nil:
      xcb_disconnect(connection)
    return false

  let screenIterator = xcb_setup_roots_iterator(xcb_get_setup(connection))
  if screenIterator.data == nil:
    xcb_disconnect(connection)
    return false

  let name = "_CIRRUS_STATE_INVALIDATE"
  let cookie = xcb_intern_atom(connection, 0, name.len.uint16, name.cstring)
  let reply = xcb_intern_atom_reply(connection, cookie, nil)
  if reply == nil:
    xcb_disconnect(connection)
    return false

  event.connection = cast[pointer](connection)
  event.root = screenIterator.data.root
  event.atom = reply.atom
  c_free(reply)
  for index, atomName in ["_NET_WM_NAME", "WM_NAME"]:
    let titleCookie = xcb_intern_atom(connection, 0, atomName.len.uint16,
      atomName.cstring)
    let titleReply = xcb_intern_atom_reply(connection, titleCookie, nil)
    if titleReply == nil:
      event.close()
      return false
    event.titleAtoms[index] = titleReply.atom
    c_free(titleReply)

  var mask = XcbPropertyChangeMask
  discard xcb_change_window_attributes(
    connection, event.root, XcbCWEventMask, addr mask
  )
  if xcb_flush(connection) < 0:
    event.close()
    return false
  true

proc watchClients*(event: var X11Invalidation, clients: seq[uint32]) =
  if event.connection == nil:
    return
  let connection = cast[ptr XcbConnection](event.connection)
  var mask = XcbPropertyChangeMask
  for client in clients:
    discard xcb_change_window_attributes(connection, client, XcbCWEventMask,
      addr mask)
  discard xcb_flush(connection)

proc isInvalidation(event: X11Invalidation, value: ptr XcbGenericEvent): bool =
  if value == nil or (value.responseType and 0x7f'u8) != XcbPropertyNotify:
    return false
  let property = cast[ptr XcbPropertyNotifyEvent](value)
  property.window == event.root and property.atom == event.atom

proc isTitleChange(event: X11Invalidation, value: ptr XcbGenericEvent): bool =
  if value == nil or (value.responseType and 0x7f'u8) != XcbPropertyNotify:
    return false
  let property = cast[ptr XcbPropertyNotifyEvent](value)
  property.window != event.root and
    (property.atom == event.titleAtoms[0] or property.atom == event.titleAtoms[1])

proc drain*(event: X11Invalidation): bool =
  var found = false
  while true:
    let value = xcb_poll_for_event(cast[ptr XcbConnection](event.connection))
    if value == nil:
      break
    if event.isInvalidation(value) or event.isTitleChange(value):
      found = true
    c_free(value)
  found

proc wait*(event: X11Invalidation): bool =
  while true:
    let value = xcb_wait_for_event(cast[ptr XcbConnection](event.connection))
    if value == nil:
      return false
    let matched = event.isInvalidation(value) or event.isTitleChange(value)
    c_free(value)
    if matched:
      return true
