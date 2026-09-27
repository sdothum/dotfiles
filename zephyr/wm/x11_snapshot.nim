import std/posix
import std/strutils
import std/monotimes
import std/times

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
proc xcb_delete_property(connection: ptr XcbConnection, window: XcbWindow,
    property: XcbAtom): XcbVoidCookie {.importc, cdecl, header: "xcb/xcb.h".}
proc xcb_screen_next(screen: ptr XcbScreenIterator) {.importc, cdecl, header: "xcb/xcb.h".}
proc xcb_change_property_checked(connection: ptr XcbConnection, mode: uint8,
    window: XcbWindow, property, kind: XcbAtom, format: uint8,
    length: uint32, data: pointer): XcbVoidCookie {.importc, cdecl, header: "xcb/xcb.h".}

proc c_free(value: pointer) {.importc: "free", cdecl, header: "stdlib.h".}

type X11SnapshotQuery* = object
  connection: pointer
  root: XcbWindow
  commandAtom: XcbAtom
  responseAtom: XcbAtom
  requestAtom: XcbAtom
  replyWindow: XcbWindow
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
    # Disconnect destroys the reply window and frees XCB's pending event/reply queues.
    xcb_disconnect(cast[ptr XcbConnection](query.connection))
  # Also reset partially initialized sessions, which may not own a connection.
  query.connection = nil
  query.replyWindow = 0
  query.root = 0
  query.commandAtom = 0
  query.responseAtom = 0
  query.requestAtom = 0
  query.lastResponse = ""
  # lastFailure is diagnostic only; failed() sets it after cleanup.


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
  query.connection = cast[pointer](connection)
  if connection == nil or xcb_connection_has_error(connection) != 0:
    query.close()
    return query.failed("CONNECT")
  var screen = xcb_setup_roots_iterator(xcb_get_setup(connection))
  for unused in 0 ..< int(screenNumber):
    xcb_screen_next(addr screen)
  if screen.data == nil or
      not intern(connection, "__WM_IPC_COMMAND", query.commandAtom) or
      not intern(connection, "__WM_IPC_RESPONSE", query.responseAtom) or
      not intern(connection, "__WM_IPC_REQUEST", query.requestAtom):
    query.close()
    return query.failed("INTERN_ATOMS")
  query.root = screen.data.root
  true

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

# A disconnected client's XID range can immediately be reused by XCB. Keep
# ambiguous reply XIDs retired for this process, even across connections: a
# stopped WM may still hold a request addressed to one of them. This is local
# allocation bookkeeping, not a wire-level request identifier.
var retiredReplyWindows: seq[XcbWindow]

proc requestFailed(query: var X11SnapshotQuery, reason: string): bool =
  # Never reuse a reply window after an ambiguous failure: a late reply has
  # no request ID and could otherwise satisfy the next operation.
  if query.replyWindow != 0 and query.replyWindow notin retiredReplyWindows:
    retiredReplyWindows.add(query.replyWindow)
  query.close()
  query.failed(reason)

proc atom*(query: var X11SnapshotQuery, name: string, value: var uint32): bool =
  query.isOpen() and intern(cast[ptr XcbConnection](query.connection), name, value)

proc trySend*(query: var X11SnapshotQuery, command: uint32,
    arguments: array[4, uint32]): bool =
  if not query.isOpen(): return query.requestFailed("CONNECT")
  let connection = cast[ptr XcbConnection](query.connection)
  var message = XcbClientMessageEvent(responseType: 33, format: 32,
    kind: query.commandAtom)
  message.data[0] = command
  for i in 0 .. 3: message.data[i + 1] = arguments[i]
  let error = xcb_request_check(connection, xcb_send_event_checked(connection,
    0, query.root, XcbEventMaskSubstructureRedirect, cast[cstring](addr message)))
  if error != nil:
    c_free(error)
    return query.requestFailed("SEND_REQUEST")
  if xcb_flush(connection) <= 0: return query.requestFailed("FLUSH")
  true

proc tryRequest*(query: var X11SnapshotQuery, command, data2, data3, data4: uint32,
    requestBody: string, output: var string, timeoutMs = QueryTimeoutMs,
    groupNo = 0'u32): bool =
  output = ""
  query.lastResponse = ""
  query.lastFailure = ""
  if not query.isOpen(): return query.requestFailed("CONNECT")
  let connection = cast[ptr XcbConnection](query.connection)
  if query.replyWindow == 0:
    while true:
      query.replyWindow = xcb_generate_id(connection)
      if query.replyWindow == high(uint32):
        query.replyWindow = 0
        return query.requestFailed("ALLOCATE_REPLY_WINDOW")
      if query.replyWindow notin retiredReplyWindows:
        break
    var eventMask = XcbPropertyChangeMask
    let error = xcb_request_check(connection, xcb_create_window_checked(connection,
      XcbCopyFromParent, query.replyWindow, query.root, 0, 0, 1, 1, 0,
      XcbInputOnly, XcbCopyFromParent, XcbCwEventMask, addr eventMask))
    if error != nil:
      c_free(error)
      return query.requestFailed("CREATE_REPLY_WINDOW")
  let replyWindow = query.replyWindow
  # Reuse one reply window. Clear request payloads so filters cannot leak.
  discard xcb_delete_property(connection, replyWindow, query.requestAtom)
  if requestBody.len > 0:
    discard xcb_change_property(connection, 0, replyWindow, query.requestAtom,
      XcbAtomString, 8, requestBody.len.uint32, cast[pointer](requestBody.cstring))
  elif groupNo > 0:
    var group = groupNo
    let error = xcb_request_check(connection, xcb_change_property_checked(connection,
      0, replyWindow, query.requestAtom, 6, 32, 1, addr group))
    if error != nil:
      c_free(error)
      return query.requestFailed("WRITE_GROUP")
  if not query.trySend(command, [replyWindow, data2, data3, data4]): return false
  let deadline = getMonoTime() + initDuration(milliseconds = timeoutMs)
  while true:
    while true:
      let event = xcb_poll_for_event(connection)
      if event == nil: break
      var matched = false
      if (event.responseType and 0x7f'u8) == XcbPropertyNotify:
        let property = cast[ptr XcbPropertyNotifyEvent](event)
        matched = property.window == replyWindow and property.atom == query.responseAtom and property.state == 0
      c_free(event)
      if not matched: continue
      var error: ptr XcbGenericError
      let reply = xcb_get_property_reply(connection,
        xcb_get_property(connection, 1, replyWindow, query.responseAtom,
          XcbAtomString, 0, high(uint32)), addr error)
      if error != nil: c_free(error)
      if reply == nil: return query.requestFailed("READ_PROPERTY")
      let length = xcb_get_property_value_length(reply)
      if reply.format != 8 or reply.propertyType != XcbAtomString or length <= 0:
        c_free(reply)
        return query.requestFailed("INVALID_RESPONSE")
      output = newString(length)
      copyMem(addr output[0], xcb_get_property_value(reply), length)
      c_free(reply)
      query.lastResponse = output
      return true
    if xcb_connection_has_error(connection) != 0:
      return query.requestFailed("CONNECTION_LOST")
    let remaining = (deadline - getMonoTime()).inMilliseconds
    if remaining <= 0: return query.requestFailed("TIMEOUT (completion unknown)")
    var descriptor = TPollfd(fd: xcb_get_file_descriptor(connection), events: POLLIN)
    let ready = posix.poll(addr descriptor, Tnfds(1), remaining.cint)
    if ready < 0 and errno == EINTR: continue
    if ready < 0 or (descriptor.revents and (POLLERR or POLLHUP or POLLNVAL)) != 0:
      return query.requestFailed("CONNECTION_LOST")


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
  var response: string
  if not query.tryRequest(IpcWindowSnapshot, 0, IpcScopeAll, IpcSelectorNone,
      "", response, timeoutMs): return false
  if not snapshotBody(response, output):
    return query.failed("RESPONSE_ENVELOPE " & response)
  true

proc trySnapshot*(query: var X11SnapshotQuery, output: var string,
    reconnect: bool): bool =
  if query.trySnapshotWithTimeout(output):
    return true
  if reconnect:
    if query.open():
      return query.trySnapshotWithTimeout(output)
  false
