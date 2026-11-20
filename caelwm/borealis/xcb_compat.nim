## Narrow libxcb ABI declarations. All transport remains in the same libxcb as C.
{.passL: "-lxcb".}
type
  Connection* {.importc: "xcb_connection_t", header: "<xcb/xcb.h>", incompleteStruct.} = object
  Setup {.importc: "xcb_setup_t", header: "<xcb/xcb.h>", incompleteStruct.} = object
  Screen* {.importc: "xcb_screen_t", header: "<xcb/xcb.h>", bycopy.} = object
    root*: uint32
  Iterator {.importc: "xcb_screen_iterator_t", header: "<xcb/xcb.h>", bycopy.} = object
    data*: ptr Screen
  Cookie* {.importc: "xcb_void_cookie_t", header: "<xcb/xcb.h>", bycopy.} = object
    sequence*: cuint
  AtomReply {.importc: "xcb_intern_atom_reply_t", header: "<xcb/xcb.h>", bycopy.} = object
    atom*: uint32
  Error* {.importc: "xcb_generic_error_t", header: "<xcb/xcb.h>", bycopy.} = object
    error_code*: uint8
  Event* {.importc: "xcb_generic_event_t", header: "<xcb/xcb.h>", bycopy.} = object
    response_type*: uint8
  PropertyEvent* {.importc: "xcb_property_notify_event_t", header: "<xcb/xcb.h>", bycopy.} = object
    window*, atom*: uint32
  PropertyReply* {.importc: "xcb_get_property_reply_t", header: "<xcb/xcb.h>", bycopy.} = object
  MessageData {.importc: "xcb_client_message_data_t", header: "<xcb/xcb.h>", union, bycopy.} = object
    data32*: array[5, uint32]
  Message* {.importc: "xcb_client_message_event_t", header: "<xcb/xcb.h>", bycopy.} = object
    response_type*, format*: uint8
    sequence*: uint16
    window*, `type`*: uint32
    data*: MessageData
proc connect*(name: cstring, screen: ptr cint): ptr Connection {.importc: "xcb_connect", header: "<xcb/xcb.h>".}
proc hasError*(c: ptr Connection): cint {.importc: "xcb_connection_has_error", header: "<xcb/xcb.h>".}
proc disconnect*(c: ptr Connection) {.importc: "xcb_disconnect", header: "<xcb/xcb.h>".}
proc setup(c: ptr Connection): ptr Setup {.importc: "xcb_get_setup", header: "<xcb/xcb.h>".}
proc roots(s: ptr Setup): Iterator {.importc: "xcb_setup_roots_iterator", header: "<xcb/xcb.h>".}
# Cookie typedefs have identical representation but C distinguishes their types.
proc atomReply(c: ptr Connection, cookie: Cookie, error: ptr ptr Error): ptr AtomReply {.importc: "sirocco_atom_reply", nodecl.}
{.emit: """
static xcb_intern_atom_reply_t *sirocco_atom_reply(xcb_connection_t *c, xcb_void_cookie_t k, xcb_generic_error_t **e) {
  xcb_intern_atom_cookie_t a = { k.sequence }; return xcb_intern_atom_reply(c,a,e);
}
""".}
# Intern also needs a typedef adapter; this contains no client behavior.
proc internCompat(c: ptr Connection, only: uint8, size: uint16, name: cstring): Cookie {.importc: "sirocco_intern", nodecl.}
{.emit: """
static xcb_void_cookie_t sirocco_intern(xcb_connection_t *c, uint8_t o, uint16_t n, const char *s) {
  xcb_intern_atom_cookie_t a = xcb_intern_atom(c,o,n,s); xcb_void_cookie_t k = {a.sequence}; return k;
}
""".}
proc freeMem*(p: pointer) {.importc: "free", header: "<stdlib.h>".}
proc firstScreen*(c: ptr Connection): ptr Screen = roots(setup(c)).data
proc atom*(c: ptr Connection, name: string): uint32 =
  let r = atomReply(c, internCompat(c, 0, uint16(name.len and 65535), name.cstring), nil)
  if r == nil: return 31
  # C intentionally retains the intern reply; preserve connection/allocation lifetime.
  r.atom
proc send*(c: ptr Connection, propagate: uint8, root: uint32, mask: uint32, event: cstring): Cookie {.importc: "xcb_send_event_checked", header: "<xcb/xcb.h>".}
proc check*(c: ptr Connection, k: Cookie): ptr Error {.importc: "xcb_request_check", header: "<xcb/xcb.h>".}
proc flush*(c: ptr Connection): cint {.importc: "xcb_flush", header: "<xcb/xcb.h>", discardable.}
proc generateId*(c: ptr Connection): uint32 {.importc: "xcb_generate_id", header: "<xcb/xcb.h>".}
proc create*(c: ptr Connection, depth: uint8, id, parent: uint32, x,y: int16, w,h,border,kind: uint16, visual,mask: uint32, values: pointer): Cookie {.importc: "xcb_create_window_checked", header: "<xcb/xcb.h>".}
proc change*(c: ptr Connection, mode: uint8, window,property,kind: uint32, format: uint8, size: uint32, value: pointer): Cookie {.importc: "xcb_change_property", header: "<xcb/xcb.h>", discardable.}
proc changeChecked*(c: ptr Connection, mode: uint8, window,property,kind: uint32, format: uint8, size: uint32, value: pointer): Cookie {.importc: "xcb_change_property_checked", header: "<xcb/xcb.h>".}
proc destroy*(c: ptr Connection, window: uint32): Cookie {.importc: "xcb_destroy_window", header: "<xcb/xcb.h>", discardable.}
proc fd*(c: ptr Connection): cint {.importc: "xcb_get_file_descriptor", header: "<xcb/xcb.h>".}
proc event*(c: ptr Connection): ptr Event {.importc: "xcb_poll_for_event", header: "<xcb/xcb.h>".}
proc propertyRaw(c: ptr Connection, window,atom: uint32): ptr PropertyReply {.importc: "sirocco_property", nodecl.}
{.emit: """
static xcb_get_property_reply_t *sirocco_property(xcb_connection_t *c, uint32_t w, uint32_t a) {
  return xcb_get_property_reply(c,xcb_get_property(c,0,w,a,XCB_ATOM_STRING,0,UINT32_MAX),NULL);
}
""".}
proc valueLength*(r: ptr PropertyReply): cint {.importc: "xcb_get_property_value_length", header: "<xcb/xcb.h>".}
proc value*(r: ptr PropertyReply): pointer {.importc: "xcb_get_property_value", header: "<xcb/xcb.h>".}

proc property*(c: ptr Connection, window, atom: uint32): ptr PropertyReply = propertyRaw(c,window,atom)
