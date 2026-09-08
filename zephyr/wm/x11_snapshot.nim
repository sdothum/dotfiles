import std/posix
import std/strutils

{.emit: "#include <xcb/xcb.h>".}

type
  XcbConnection {.importc: "xcb_connection_t", incompleteStruct.} = object
  XcbSetup {.importc: "xcb_setup_t", incompleteStruct.} = object
  XcbGenericError {.importc: "xcb_generic_error_t", incompleteStruct.} = object
  XcbWindow = uint32
  XcbAtom = uint32

  XcbScreen = object
    root: XcbWindow

  XcbScreenIterator {.importc: "xcb_screen_iterator_t".} = object
    data: ptr XcbScreen
    rem: cint
    index: cint

  XcbInternAtomCookie {.importc: "xcb_intern_atom_cookie_t".} = object
    sequence: cuint

  XcbInternAtomReply {.importc: "xcb_intern_atom_reply_t".} = object
    responseType {.importc: "response_type".}: uint8
    pad0: uint8
    sequence: uint16
    length: uint32
    atom: XcbAtom

  XcbVoidCookie {.importc: "xcb_void_cookie_t".} = object
    sequence: cuint

  XcbClientMessageEvent {.importc: "xcb_client_message_event_t".} = object
    responseType {.importc: "response_type".}: uint8
    format: uint8
    sequence: uint16
    window: XcbWindow
    kind {.importc: "type".}: XcbAtom
    data {.importc: "data.data32".}: array[5, uint32]

  XcbGenericEvent {.importc: "xcb_generic_event_t".} = object
    responseType {.importc: "response_type".}: uint8
    pad0: uint8
    sequence: uint16
    pad: array[7, uint32]
    fullSequence: uint32

  XcbPropertyNotifyEvent {.importc: "xcb_property_notify_event_t".} = object
    responseType {.importc: "response_type".}: uint8
    pad0: uint8
    sequence: uint16
    window: XcbWindow
    atom: XcbAtom
    time: uint32
    state: uint8
    pad: array[3, uint8]

  XcbGetPropertyCookie {.importc: "xcb_get_property_cookie_t".} = object
    sequence: cuint

  XcbGetPropertyReply {.importc: "xcb_get_property_reply_t".} = object
    responseType: uint8
    format: uint8
    sequence: uint16
    length: uint32
    propertyType {.importc: "type".}: XcbAtom
    bytesAfter {.importc: "bytes_after".}: uint32
    valueLen {.importc: "value_len".}: uint32

  XcbGetGeometryCookie {.importc: "xcb_get_geometry_cookie_t".} = object
    sequence: cuint

  XcbGetGeometryReply {.importc: "xcb_get_geometry_reply_t".} = object
    responseType: uint8
    depth: uint8
    sequence: uint16
    length: uint32
    root: XcbWindow
    x: int16
    y: int16
    width: uint16
    height: uint16

const
  XcbCopyFromParent = 0'u8
  XcbInputOnly = 2'u8
  XcbAtomString = 31'u32
  XcbPropertyNotify = 28'u8
  XcbPropertyChangeMask = 1'u32 shl 22
  XcbCwEventMask = 1'u32 shl 11
  XcbEventMaskSubstructureRedirect = 1'u32 shl 20
  IpcWindowSnapshot = 31'u32
  IpcScopeAll = 1'u32
  IpcSelectorNone = 0'u32
  QueryTimeoutMs = 2000
  XcbAtomAny = 0'u32

{.passL: "-lxcb".}

proc xcb_connect(displayName: cstring, screen: ptr cint): ptr XcbConnection
  {.importc, cdecl, header: "xcb/xcb.h".}
proc xcb_connection_has_error(connection: ptr XcbConnection): cint
  {.importc, cdecl, header: "xcb/xcb.h".}
proc xcb_disconnect(connection: ptr XcbConnection)
  {.importc, cdecl, header: "xcb/xcb.h".}
proc xcb_get_setup(connection: ptr XcbConnection): ptr XcbSetup
  {.importc, cdecl, header: "xcb/xcb.h".}
proc xcb_setup_roots_iterator(setup: ptr XcbSetup): XcbScreenIterator
  {.importc, cdecl, header: "xcb/xcb.h".}
proc xcb_intern_atom(connection: ptr XcbConnection, onlyIfExists: uint8,
  nameLength: uint16, name: cstring): XcbInternAtomCookie
  {.importc, cdecl, header: "xcb/xcb.h".}
proc xcb_intern_atom_reply(connection: ptr XcbConnection,
  cookie: XcbInternAtomCookie, error: ptr ptr XcbGenericError): ptr XcbInternAtomReply
  {.importc, cdecl, header: "xcb/xcb.h".}
proc xcb_create_window_checked(connection: ptr XcbConnection,
  depth: uint8, window: XcbWindow, parent: XcbWindow, x, y: int16,
  width, height, borderWidth: uint16, class, visual: uint32,
  valueMask: uint32, values: ptr uint32): XcbVoidCookie
  {.importc, cdecl, header: "xcb/xcb.h".}
proc xcb_destroy_window_checked(connection: ptr XcbConnection,
  window: XcbWindow): XcbVoidCookie
  {.importc, cdecl, header: "xcb/xcb.h".}
proc xcb_send_event_checked(connection: ptr XcbConnection, propagate: uint8,
  destination: XcbWindow, eventMask: uint32, event: cstring): XcbVoidCookie
  {.importc, cdecl, header: "xcb/xcb.h".}
proc xcb_request_check(connection: ptr XcbConnection,
  cookie: XcbVoidCookie): ptr XcbGenericError
  {.importc, cdecl, header: "xcb/xcb.h".}
proc xcb_flush(connection: ptr XcbConnection): cint
  {.importc, cdecl, header: "xcb/xcb.h".}
proc xcb_generate_id(connection: ptr XcbConnection): uint32
  {.importc, cdecl, header: "xcb/xcb.h".}
proc xcb_get_file_descriptor(connection: ptr XcbConnection): cint
  {.importc, cdecl, header: "xcb/xcb.h".}
proc xcb_poll_for_event(connection: ptr XcbConnection): ptr XcbGenericEvent
  {.importc, cdecl, header: "xcb/xcb.h".}
proc xcb_get_property(connection: ptr XcbConnection, delete: uint8,
  window: XcbWindow, property, typ: XcbAtom, longOffset, longLength: uint32): XcbGetPropertyCookie
  {.importc, cdecl, header: "xcb/xcb.h".}
proc xcb_get_property_reply(connection: ptr XcbConnection,
  cookie: XcbGetPropertyCookie, error: ptr ptr XcbGenericError): ptr XcbGetPropertyReply
  {.importc, cdecl, header: "xcb/xcb.h".}
proc xcb_get_property_value_length(reply: ptr XcbGetPropertyReply): cint
  {.importc, cdecl, header: "xcb/xcb.h".}
proc xcb_get_property_value(reply: ptr XcbGetPropertyReply): pointer
  {.importc, cdecl, header: "xcb/xcb.h".}
proc xcb_get_geometry(connection: ptr XcbConnection,
  drawable: XcbWindow): XcbGetGeometryCookie
  {.importc, cdecl, header: "xcb/xcb.h".}
proc xcb_get_geometry_reply(connection: ptr XcbConnection,
  cookie: XcbGetGeometryCookie, error: ptr ptr XcbGenericError): ptr XcbGetGeometryReply
  {.importc, cdecl, header: "xcb/xcb.h".}
proc xcb_change_property(connection: ptr XcbConnection, mode: uint8,
  window, property, typ: XcbAtom, format: uint8, dataLength: uint32,
  data: pointer): XcbVoidCookie
  {.importc, cdecl, header: "xcb/xcb.h".}
proc c_free(value: pointer) {.importc: "free", cdecl, header: "stdlib.h".}

type X11SnapshotQuery* = object
  connection: pointer
  root: XcbWindow
  commandAtom: XcbAtom
  responseAtom: XcbAtom
  requestAtom: XcbAtom
  lastFailure*: string
  lastResponse*: string

proc isOpen*(query: X11SnapshotQuery): bool =
  query.connection != nil and
    xcb_connection_has_error(cast[ptr XcbConnection](query.connection)) == 0

proc tryRootGeometry*(query: var X11SnapshotQuery,
    width, height: var int): bool =
  if not query.isOpen():
    query.lastFailure = "CONNECT"
    return false
  var error: ptr XcbGenericError
  let reply = xcb_get_geometry_reply(
    cast[ptr XcbConnection](query.connection),
    xcb_get_geometry(cast[ptr XcbConnection](query.connection), query.root),
    addr error)
  if error != nil:
    c_free(error)
  if reply == nil:
    query.lastFailure = "ROOT_GEOMETRY"
    return false
  width = int(reply.width)
  height = int(reply.height)
  c_free(reply)
  true

proc parseWmClassProperty*(value: string, instanceName, className: var string): bool =
  ## WM_CLASS is two NUL-terminated strings, with no trailing payload.
  let firstEnd = value.find('\0')
  if firstEnd < 0:
    return false
  let secondEnd = value.find('\0', firstEnd + 1)
  if secondEnd < 0 or secondEnd != value.len - 1:
    return false
  instanceName = value[0 ..< firstEnd]
  className = value[firstEnd + 1 ..< secondEnd]
  true

proc tryWmClass*(query: var X11SnapshotQuery, winid: uint32,
    instanceName, className: var string): bool =
  if not query.isOpen():
    query.lastFailure = "CONNECT"
    return false
  let connection = cast[ptr XcbConnection](query.connection)
  let atomCookie = xcb_intern_atom(connection, 0, 8, "WM_CLASS")
  let atomReply = xcb_intern_atom_reply(connection, atomCookie, nil)
  if atomReply == nil:
    query.lastFailure = "INTERN_WM_CLASS"
    return false
  let wmClassAtom = atomReply.atom
  c_free(atomReply)
  var error: ptr XcbGenericError
  let reply = xcb_get_property_reply(connection,
    xcb_get_property(connection, 0, winid, wmClassAtom, XcbAtomAny, 0, 1024),
    addr error)
  if error != nil:
    c_free(error)
  if reply == nil or reply.format != 8'u8 or reply.propertyType != XcbAtomString or
      reply.valueLen == 0:
    if reply != nil: c_free(reply)
    query.lastFailure = "WM_CLASS_UNAVAILABLE"
    return false
  let length = int(reply.valueLen)
  var value = newString(length)
  copyMem(addr value[0], xcb_get_property_value(reply), length)
  if not parseWmClassProperty(value, instanceName, className):
    c_free(reply)
    query.lastFailure = "WM_CLASS_MALFORMED"
    return false
  c_free(reply)
  true

proc intern(connection: ptr XcbConnection, name: string, atom: var XcbAtom): bool

proc tryWmTitle*(query: var X11SnapshotQuery, winid: uint32,
    title: var string): bool =
  if not query.isOpen():
    query.lastFailure = "CONNECT"
    return false
  let connection = cast[ptr XcbConnection](query.connection)
  var netNameAtom, wmNameAtom, utf8Atom: XcbAtom
  if not intern(connection, "_NET_WM_NAME", netNameAtom) or
      not intern(connection, "WM_NAME", wmNameAtom) or
      not intern(connection, "UTF8_STRING", utf8Atom):
    query.lastFailure = "INTERN_WM_NAME"
    return false
  var error: ptr XcbGenericError
  var reply = xcb_get_property_reply(connection,
    xcb_get_property(connection, 0, winid, netNameAtom, utf8Atom, 0, 1024),
    addr error)
  if error != nil:
    c_free(error)
  if reply != nil and reply.format == 8'u8 and reply.propertyType == utf8Atom and
      reply.valueLen > 0:
    let length = int(reply.valueLen)
    title = newString(length)
    copyMem(addr title[0], xcb_get_property_value(reply), length)
    c_free(reply)
    return true
  if reply != nil: c_free(reply)
  error = nil
  reply = xcb_get_property_reply(connection,
    xcb_get_property(connection, 0, winid, wmNameAtom, XcbAtomString, 0, 1024),
    addr error)
  if error != nil:
    c_free(error)
  if reply == nil or reply.format != 8'u8 or reply.propertyType != XcbAtomString or
      reply.valueLen == 0:
    if reply != nil: c_free(reply)
    query.lastFailure = "WM_NAME_UNAVAILABLE"
    return false
  let length = int(reply.valueLen)
  title = newString(length)
  copyMem(addr title[0], xcb_get_property_value(reply), length)
  c_free(reply)
  true

proc failed(query: var X11SnapshotQuery, stage: string): bool =
  query.lastFailure = stage
  false

proc close*(query: var X11SnapshotQuery) =
  if query.connection != nil:
    xcb_disconnect(cast[ptr XcbConnection](query.connection))
    query.connection = nil
    query.root = 0
    query.commandAtom = 0
    query.responseAtom = 0
    query.requestAtom = 0

proc intern(connection: ptr XcbConnection, name: string, atom: var XcbAtom): bool =
  let cookie = xcb_intern_atom(connection, 0, name.len.uint16, name.cstring)
  let reply = xcb_intern_atom_reply(connection, cookie, nil)
  if reply == nil:
    return false
  atom = reply.atom
  c_free(reply)
  true

proc open*(query: var X11SnapshotQuery): bool =
  query.close()
  query.lastFailure = ""
  var screenNumber: cint
  let connection = xcb_connect(nil, addr screenNumber)
  if connection == nil or xcb_connection_has_error(connection) != 0:
    if connection != nil:
      xcb_disconnect(connection)
    return query.failed("CONNECT")
  let screen = xcb_setup_roots_iterator(xcb_get_setup(connection))
  if screen.data == nil or
      not intern(connection, "__WM_IPC_COMMAND", query.commandAtom) or
      not intern(connection, "__WM_IPC_RESPONSE", query.responseAtom) or
      not intern(connection, "__WM_IPC_REQUEST", query.requestAtom):
    xcb_disconnect(connection)
    return query.failed("INTERN_ATOMS")
  query.connection = cast[pointer](connection)
  query.root = screen.data.root
  true

proc destroyReplyWindow(query: X11SnapshotQuery, window: XcbWindow) =
  if query.connection != nil:
    let connection = cast[ptr XcbConnection](query.connection)
    let error = xcb_request_check(connection,
      xcb_destroy_window_checked(connection, window))
    if error != nil:
      c_free(error)

proc snapshotBody*(response: string, body: var string): bool =
  if not (response.startsWith("OK\nSNAPSHOT 1\n") or
      response.startsWith("OK\nSNAPSHOT 2\n")):
    return false
  # shvStatus() strips child output before the existing parser sees it.
  body = response[3 .. ^1].strip()
  true

proc okBody*(response: string, body: var string): bool =
  if response == "OK":
    body = ""
    return true
  if response.startsWith("OK\n"):
    body = response[3 .. ^1]
    return true
  false

proc tryRequest*(query: var X11SnapshotQuery, command, data2, data3, data4: uint32,
    requestBody: string, output: var string): bool =
  output = ""
  query.lastResponse = ""
  if query.connection == nil or
      xcb_connection_has_error(cast[ptr XcbConnection](query.connection)) != 0:
    return query.failed("CONNECT")

  let connection = cast[ptr XcbConnection](query.connection)
  let replyWindow = cast[XcbWindow](xcb_generate_id(connection))
  var eventMask = XcbPropertyChangeMask
  let createError = xcb_request_check(connection,
    xcb_create_window_checked(connection, XcbCopyFromParent, replyWindow,
      query.root, 0, 0, 1, 1, 0, XcbInputOnly, XcbCopyFromParent,
      XcbCwEventMask, addr eventMask))
  if createError != nil:
    c_free(createError)
    return query.failed("CREATE_REPLY_WINDOW")

  var message = XcbClientMessageEvent()
  message.responseType = 33'u8
  message.format = 32'u8
  message.window = query.root
  message.kind = query.commandAtom
  message.data[0] = command
  message.data[1] = replyWindow
  message.data[2] = data2
  message.data[3] = data3
  message.data[4] = data4

  if requestBody.len > 0:
    discard xcb_change_property(connection, 0, replyWindow, query.requestAtom,
      XcbAtomString, 8, requestBody.len.uint32, cast[pointer](requestBody.cstring))

  let sendError = xcb_request_check(connection,
    xcb_send_event_checked(connection, 0, query.root,
      XcbEventMaskSubstructureRedirect, cast[cstring](addr message)))
  if sendError != nil:
    c_free(sendError)
    query.destroyReplyWindow(replyWindow)
    return query.failed("SEND_REQUEST")
  if xcb_flush(connection) < 0:
    query.destroyReplyWindow(replyWindow)
    return query.failed("FLUSH")

  var descriptor = TPollfd(fd: xcb_get_file_descriptor(connection),
    events: POLLIN, revents: 0)
  if posix.poll(addr descriptor, Tnfds(1), QueryTimeoutMs.cint) <= 0:
    query.destroyReplyWindow(replyWindow)
    return query.failed("WAIT_RESPONSE_EVENT")

  var matched = false
  while true:
    let event = xcb_poll_for_event(connection)
    if event == nil:
      break
    if (event.responseType and 0x7f'u8) == XcbPropertyNotify:
      let property = cast[ptr XcbPropertyNotifyEvent](event)
      if property.window == replyWindow and property.atom == query.responseAtom:
        matched = true
    c_free(event)
    if matched:
      break
  if not matched:
    query.destroyReplyWindow(replyWindow)
    return query.failed("WAIT_RESPONSE_EVENT")

  var propertyError: ptr XcbGenericError
  let reply = xcb_get_property_reply(connection,
    xcb_get_property(connection, 0, replyWindow, query.responseAtom,
      XcbAtomString, 0, high(uint32)), addr propertyError)
  if propertyError != nil:
    c_free(propertyError)
  if reply == nil:
    query.destroyReplyWindow(replyWindow)
    return query.failed("READ_PROPERTY")
  let length = xcb_get_property_value_length(reply)
  if length <= 0:
    c_free(reply)
    query.destroyReplyWindow(replyWindow)
    return query.failed("READ_PROPERTY")
  let bytes = cast[ptr UncheckedArray[char]](xcb_get_property_value(reply))
  output = newString(length)
  copyMem(addr output[0], bytes, length)
  c_free(reply)
  query.destroyReplyWindow(replyWindow)
  query.lastResponse = output
  true

const
  IpcWindowGeometry = 16'u32
  IpcWindowStackGeometries = 32'u32
  IpcActionWindowApplyGeometries = 33'u32
  IpcActionWindowApplyGeometriesChecked = 35'u32

proc tryGeometry*(query: var X11SnapshotQuery, winid: uint32, explicit: bool,
    output: var string): bool =
  var response: string
  if not query.tryRequest(IpcWindowGeometry,
      (if explicit: 1'u32 else: 0'u32), winid, 0, "", response):
    return false
  if not okBody(response, output):
    return query.failed("RESPONSE_ENVELOPE " & response)
  output = output.strip()
  true

proc tryStackGeometries*(query: var X11SnapshotQuery, winid: uint32,
    explicit: bool, output: var string): bool =
  var response: string
  if not query.tryRequest(IpcWindowStackGeometries,
      (if explicit: 1'u32 else: 0'u32), winid, 0'u32, "", response):
    return false
  if not okBody(response, output):
    return query.failed("RESPONSE_ENVELOPE " & response)
  true

proc tryApplyGeometries*(query: var X11SnapshotQuery, body: string): bool =
  var response: string
  if not query.tryRequest(IpcActionWindowApplyGeometries,
      0, 0, 0, body, response):
    return false
  var ignored: string
  if not okBody(response, ignored):
    return query.failed("APPLY_RESPONSE " & response)
  true

proc tryApplyGeometriesChecked*(query: var X11SnapshotQuery, body: string): bool =
  var response: string
  if not query.tryRequest(IpcActionWindowApplyGeometriesChecked,
      0, 0, 0, body, response):
    return false
  var ignored: string
  if not okBody(response, ignored):
    return query.failed("APPLY_CHECKED_RESPONSE " & response)
  true

proc trySnapshotWithTimeout*(query: var X11SnapshotQuery, output: var string,
    timeoutMs = QueryTimeoutMs): bool =
  output = ""
  if query.connection == nil or
      xcb_connection_has_error(cast[ptr XcbConnection](query.connection)) != 0:
    return query.failed("CONNECT")

  let connection = cast[ptr XcbConnection](query.connection)

  let replyWindow = cast[XcbWindow](xcb_generate_id(connection))
  var eventMask = XcbPropertyChangeMask
  let createError = xcb_request_check(connection,
    xcb_create_window_checked(connection, XcbCopyFromParent, replyWindow,
      query.root, 0, 0, 1, 1, 0, XcbInputOnly, XcbCopyFromParent,
      XcbCwEventMask, addr eventMask))
  if createError != nil:
    c_free(createError)
    return query.failed("CREATE_REPLY_WINDOW")

  var message = XcbClientMessageEvent()
  message.responseType = 33'u8
  message.format = 32'u8
  message.window = query.root
  message.kind = query.commandAtom
  message.data[0] = IpcWindowSnapshot
  message.data[1] = replyWindow
  message.data[2] = 0
  message.data[3] = IpcScopeAll
  message.data[4] = IpcSelectorNone

  let sendError = xcb_request_check(connection,
    xcb_send_event_checked(connection, 0, query.root,
      XcbEventMaskSubstructureRedirect, cast[cstring](addr message)))
  if sendError != nil:
    c_free(sendError)
    query.destroyReplyWindow(replyWindow)
    return query.failed("SEND_REQUEST")
  if xcb_flush(connection) < 0:
    query.destroyReplyWindow(replyWindow)
    return query.failed("FLUSH")

  var descriptor = TPollfd(fd: xcb_get_file_descriptor(connection),
    events: POLLIN, revents: 0)
  if posix.poll(addr descriptor, Tnfds(1), timeoutMs.cint) <= 0:
    query.destroyReplyWindow(replyWindow)
    return query.failed("WAIT_RESPONSE_EVENT")

  var matched = false
  while true:
    let event = xcb_poll_for_event(connection)
    if event == nil:
      break
    if (event.responseType and 0x7f'u8) == XcbPropertyNotify:
      let property = cast[ptr XcbPropertyNotifyEvent](event)
      if property.window == replyWindow and property.atom == query.responseAtom:
        matched = true
    c_free(event)
    if matched:
      break
  if not matched:
    query.destroyReplyWindow(replyWindow)
    return query.failed("WAIT_RESPONSE_EVENT")

  var propertyError: ptr XcbGenericError
  let reply = xcb_get_property_reply(connection,
    xcb_get_property(connection, 0, replyWindow, query.responseAtom,
      XcbAtomString, 0, high(uint32)), addr propertyError)
  if propertyError != nil:
    c_free(propertyError)
  if reply == nil:
    query.destroyReplyWindow(replyWindow)
    return query.failed("READ_PROPERTY")
  let length = xcb_get_property_value_length(reply)
  if length <= 0:
    c_free(reply)
    query.destroyReplyWindow(replyWindow)
    return query.failed("READ_PROPERTY")
  let bytes = cast[ptr UncheckedArray[char]](xcb_get_property_value(reply))
  output = newString(length)
  copyMem(addr output[0], bytes, length)
  c_free(reply)
  query.destroyReplyWindow(replyWindow)

  var body: string
  if not snapshotBody(output, body):
    output = ""
    return query.failed("RESPONSE_ENVELOPE")
  output = body
  true

proc trySnapshot*(query: var X11SnapshotQuery, output: var string,
    reconnect: bool): bool =
  if query.trySnapshotWithTimeout(output):
    return true
  if reconnect:
    if query.open():
      return query.trySnapshotWithTimeout(output)
  false
