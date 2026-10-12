## The complete unsafe XCB ABI surface for the Stage 1 shell.
## Raw pointers and C allocation ownership stay inside x11/.

{.emit: "#include <xcb/xcb.h>\n#include <xcb/xproto.h>".}
{.passL: "-lxcb".}

type
  XcbConnection* {.importc: "xcb_connection_t", header: "xcb/xcb.h", incompleteStruct.} = object
  XcbSetup* {.importc: "xcb_setup_t", header: "xcb/xcb.h", incompleteStruct.} = object
  XcbScreen* {.importc: "xcb_screen_t", header: "xcb/xcb.h", bycopy.} = object
    root*: uint32
    defaultColormap: uint32
    whitePixel: uint32
    blackPixel: uint32
    currentInputMasks: uint32
    widthInPixels* {.importc: "width_in_pixels".}: uint16
    heightInPixels* {.importc: "height_in_pixels".}: uint16
    widthInMillimeters: uint16
    heightInMillimeters: uint16
    minInstalledMaps: uint16
    maxInstalledMaps: uint16
    rootVisual* {.importc: "root_visual".}: uint32
    backingStores: uint8
    saveUnders: uint8
    rootDepth* {.importc: "root_depth".}: uint8
    allowedDepthsLen: uint8
  XcbScreenIterator* {.importc: "xcb_screen_iterator_t", header: "xcb/xcb.h", bycopy.} = object
    data*: ptr XcbScreen
    rem*: cint
    index*: cint
  XcbGenericError* {.importc: "xcb_generic_error_t", header: "xcb/xcb.h", bycopy.} = object
    responseType*: uint8
    errorCode* {.importc: "error_code".}: uint8
    sequence*: uint16
    resourceId* {.importc: "resource_id".}: uint32
    minorCode* {.importc: "minor_code".}: uint16
    majorCode* {.importc: "major_code".}: uint8
    pad0: uint8
    pad: array[5, uint32]
    fullSequence* {.importc: "full_sequence".}: uint32
  XcbGenericEvent* {.importc: "xcb_generic_event_t", header: "xcb/xcb.h", bycopy.} = object
    responseType* {.importc: "response_type".}: uint8
    pad0: uint8
    sequence*: uint16
    pad: array[7, uint32]
    fullSequence* {.importc: "full_sequence".}: uint32
  XcbVoidCookie* {.importc: "xcb_void_cookie_t", header: "xcb/xcb.h", bycopy.} = object
    sequence*: cuint
  XcbInternAtomCookie* {.importc: "xcb_intern_atom_cookie_t", header: "xcb/xcb.h", bycopy.} = object
    sequence*: cuint
  XcbInternAtomReply* {.importc: "xcb_intern_atom_reply_t", header: "xcb/xcb.h", bycopy.} = object
    responseType: uint8
    pad0: uint8
    sequence: uint16
    length: uint32
    atom*: uint32
  XcbQueryTreeCookie* {.importc: "xcb_query_tree_cookie_t", header: "xcb/xproto.h", bycopy.} = object
    sequence*: cuint
  XcbQueryTreeReply* {.importc: "xcb_query_tree_reply_t", header: "xcb/xproto.h", bycopy.} = object
    responseType: uint8
    pad0: uint8
    sequence: uint16
    length: uint32
    root: uint32
    parent: uint32
    childrenLen* {.importc: "children_len".}: uint16
    pad1: array[14, uint8]
  XcbGetWindowAttributesCookie* {.importc: "xcb_get_window_attributes_cookie_t", header: "xcb/xproto.h", bycopy.} = object
    sequence*: cuint
  XcbGetWindowAttributesReply* {.importc: "xcb_get_window_attributes_reply_t", header: "xcb/xproto.h", bycopy.} = object
    responseType: uint8
    backingStore: uint8
    sequence: uint16
    length: uint32
    visual: uint32
    class: uint16
    bitGravity: uint8
    winGravity: uint8
    backingPlanes: uint32
    backingPixel: uint32
    saveUnder: uint8
    mapIsInstalled: uint8
    mapState* {.importc: "map_state".}: uint8
    overrideRedirect* {.importc: "override_redirect".}: uint8
    colormap: uint32
    allEventMasks: uint32
    yourEventMask: uint32
    doNotPropagateMask: uint16
    pad0: array[2, uint8]
  XcbGetPropertyCookie* {.importc: "xcb_get_property_cookie_t", header: "xcb/xproto.h", bycopy.} = object
    sequence*: cuint
  XcbGetPropertyReply* {.importc: "xcb_get_property_reply_t", header: "xcb/xproto.h", bycopy.} = object
    responseType: uint8
    format*: uint8
    sequence: uint16
    length: uint32
    typeAtom* {.importc: "type".}: uint32
    bytesAfter* {.importc: "bytes_after".}: uint32
    valueLen* {.importc: "value_len".}: uint32
    pad0: array[12, uint8]
  XcbGetGeometryCookie* {.importc: "xcb_get_geometry_cookie_t", header: "xcb/xproto.h", bycopy.} = object
    sequence*: cuint
  XcbQueryPointerCookie* {.importc: "xcb_query_pointer_cookie_t", header: "xcb/xproto.h", bycopy.} = object
    sequence*: cuint
  XcbQueryPointerReply* {.importc: "xcb_query_pointer_reply_t", header: "xcb/xproto.h", bycopy.} = object
    responseType: uint8
    sameScreen* {.importc: "same_screen".}: uint8
    sequence: uint16
    length: uint32
    root*: uint32
    child*: uint32
    rootX* {.importc: "root_x".}: int16
    rootY* {.importc: "root_y".}: int16
    winX*: int16
    winY*: int16
    mask*: uint16
    pad0: array[2, uint8]
  XcbGrabPointerReply* {.importc: "xcb_grab_pointer_reply_t", header: "xcb/xproto.h", bycopy.} = object
    responseType*: uint8
    status*: uint8
    sequence: uint16
    length: uint32
    pad0: array[24, uint8]
  XcbGrabPointerCookie* {.importc: "xcb_grab_pointer_cookie_t", header: "xcb/xproto.h", bycopy.} = object
    sequence*: cuint
  XcbGetGeometryReply* {.importc: "xcb_get_geometry_reply_t", header: "xcb/xproto.h", bycopy.} = object
    responseType: uint8
    depth*: uint8
    sequence: uint16
    length: uint32
    root*: uint32
    x*: int16
    y*: int16
    width*: uint16
    height*: uint16
    borderWidth*: uint16
    pad0: array[2, uint8]
  XcbMapRequestEvent* {.importc: "xcb_map_request_event_t", header: "xcb/xproto.h", bycopy.} = object
    responseType* {.importc: "response_type".}: uint8
    pad0: uint8
    sequence*: uint16
    parent*: uint32
    window*: uint32
  XcbMapNotifyEvent* {.importc: "xcb_map_notify_event_t", header: "xcb/xproto.h", bycopy.} = object
    responseType* {.importc: "response_type".}: uint8
    pad0: uint8
    sequence*: uint16
    event*: uint32
    window*: uint32
    overrideRedirect* {.importc: "override_redirect".}: uint8
    pad1: array[3, uint8]
  XcbUnmapNotifyEvent* {.importc: "xcb_unmap_notify_event_t", header: "xcb/xproto.h", bycopy.} = object
    responseType* {.importc: "response_type".}: uint8
    pad0: uint8
    sequence*: uint16
    event*: uint32
    window*: uint32
    fromConfigure* {.importc: "from_configure".}: uint8
    pad1: array[3, uint8]
  XcbDestroyNotifyEvent* {.importc: "xcb_destroy_notify_event_t", header: "xcb/xproto.h", bycopy.} = object
    responseType* {.importc: "response_type".}: uint8
    pad0: uint8
    sequence*: uint16
    event*: uint32
    window*: uint32
  XcbConfigureRequestEvent* {.importc: "xcb_configure_request_event_t", header: "xcb/xproto.h", bycopy.} = object
    responseType* {.importc: "response_type".}: uint8
    stackMode* {.importc: "stack_mode".}: uint8
    sequence*: uint16
    parent*: uint32
    window*: uint32
    sibling*: uint32
    x*: int16
    y*: int16
    width*: uint16
    height*: uint16
    borderWidth* {.importc: "border_width".}: uint16
    valueMask* {.importc: "value_mask".}: uint16
  XcbButtonPressEvent* {.importc: "xcb_button_press_event_t", header: "xcb/xproto.h", bycopy.} = object
    responseType* {.importc: "response_type".}: uint8
    detail*: uint8
    sequence*: uint16
    time*: uint32
    root*, event*, child*: uint32
    rootX* {.importc: "root_x".}: int16
    rootY* {.importc: "root_y".}: int16
    eventX* {.importc: "event_x".}: int16
    eventY* {.importc: "event_y".}: int16
    state*: uint16
    sameScreen* {.importc: "same_screen".}: uint8
    pad0: uint8
  XcbMotionNotifyEvent* {.importc: "xcb_motion_notify_event_t", header: "xcb/xproto.h", bycopy.} = object
    responseType* {.importc: "response_type".}: uint8
    detail*: uint8
    sequence*: uint16
    time*: uint32
    root*, event*, child*: uint32
    rootX* {.importc: "root_x".}: int16
    rootY* {.importc: "root_y".}: int16
    eventX* {.importc: "event_x".}: int16
    eventY* {.importc: "event_y".}: int16
    state*: uint16
    sameScreen* {.importc: "same_screen".}: uint8
    pad0: uint8
  XcbCirculateRequestEvent* {.importc: "xcb_circulate_request_event_t", header: "xcb/xproto.h", bycopy.} = object
    responseType* {.importc: "response_type".}: uint8
    pad0: uint8
    sequence*: uint16
    event*: uint32
    window*: uint32
    pad1: array[4, uint8]
    place*: uint8
    pad2: array[3, uint8]
  XcbConfigureNotifyEvent* {.importc: "xcb_configure_notify_event_t", header: "xcb/xproto.h", bycopy.} = object
    responseType* {.importc: "response_type".}: uint8
    pad0*: uint8
    sequence*: uint16
    event*: uint32
    window*: uint32
    aboveSibling* {.importc: "above_sibling".}: uint32
    x*: int16
    y*: int16
    width*: uint16
    height*: uint16
    borderWidth* {.importc: "border_width".}: uint16
    overrideRedirect* {.importc: "override_redirect".}: uint8
    pad1*: uint8
  XcbPropertyNotifyEvent* {.importc: "xcb_property_notify_event_t", header: "xcb/xproto.h", bycopy.} = object
    responseType* {.importc: "response_type".}: uint8
    pad0: uint8
    sequence*: uint16
    window*: uint32
    atom*: uint32
    time*: uint32
    state*: uint8
    pad1: array[3, uint8]
  XcbClientMessageData* {.union, bycopy.} = object
    data8*: array[20, uint8]
    data16*: array[10, uint16]
    data32*: array[5, uint32]
  XcbClientMessageEvent* {.importc: "xcb_client_message_event_t", header: "xcb/xproto.h", bycopy.} = object
    responseType* {.importc: "response_type".}: uint8
    format*: uint8
    sequence*: uint16
    window*: uint32
    messageType* {.importc: "type".}: uint32
    data*: XcbClientMessageData
  XcbFocusEvent* {.importc: "xcb_focus_in_event_t", header: "xcb/xproto.h", bycopy.} = object
    responseType* {.importc: "response_type".}: uint8
    detail*: uint8
    sequence*: uint16
    event*: uint32
    mode*: uint8
    pad0: array[3, uint8]
  XcbEnterNotifyEvent* {.importc: "xcb_enter_notify_event_t", header: "xcb/xproto.h", bycopy.} = object
    responseType* {.importc: "response_type".}: uint8
    detail*: uint8
    sequence*: uint16
    time*: uint32
    root*: uint32
    event*: uint32
    child*: uint32
    rootX* {.importc: "root_x".}: int16
    rootY* {.importc: "root_y".}: int16
    eventX*: int16
    eventY*: int16
    state*: uint16
    mode*: uint8
    sameScreenFocus* {.importc: "same_screen_focus".}: uint8
  XcbGetInputFocusCookie* {.importc: "xcb_get_input_focus_cookie_t", header: "xcb/xproto.h", bycopy.} = object
    sequence*: cuint
  XcbGetInputFocusReply* {.importc: "xcb_get_input_focus_reply_t", header: "xcb/xproto.h", bycopy.} = object
    responseType: uint8
    revertTo* {.importc: "revert_to".}: uint8
    sequence: uint16
    length: uint32
    focus*: uint32
  XcbConfigureWindowValueList* {.union, bycopy.} = object
    data8*: array[16, uint8]
    data16*: array[8, uint16]
    data32*: array[4, uint32]

const
  EventDestroyNotify* = 17'u8
  EventUnmapNotify* = 18'u8
  EventMapNotify* = 19'u8
  EventMapRequest* = 20'u8
  EventConfigureRequest* = 23'u8
  EventCirculateRequest* = 27'u8
  EventConfigureNotify* = 22'u8
  EventPropertyNotify* = 28'u8
  EventClientMessage* = 33'u8
  EventFocusIn* = 9'u8
  EventFocusOut* = 10'u8
  EventEnterNotify* = 7'u8
  EventButtonPress* = 4'u8
  EventButtonRelease* = 5'u8
  EventMotionNotify* = 6'u8
  EventSendEventMask* = 0x80'u8
  ErrorBadAccess* = 10'u8
  CwEventMask* = 1'u32 shl 11
  CwBackPixel* = 1'u32 shl 1
  CwOverrideRedirect* = 1'u32 shl 9
  EventMaskEnterWindow* = 1'u32 shl 4
  EventMaskExposure* = 1'u32 shl 15
  EventMaskFocusChangeClient* = 1'u32 shl 21
  EventMaskPropertyChangeClient* = 1'u32 shl 22
  EventMaskStructureNotify* = 1'u32 shl 17
  EventMaskSubstructureNotify* = 1'u32 shl 19
  EventMaskSubstructureRedirect* = 1'u32 shl 20
  EventMaskFocusChange* = 1'u32 shl 21
  EventMaskPropertyChange* = 1'u32 shl 22
  PropModeReplace* = 0'u8
  WindowClassInputOutput* = 1'u16
  SaveSetInsert* = 0'u8
  SaveSetDelete* = 1'u8
  MapStateViewable* = 2'u8
  ErrorBadWindow* = 3'u8
  EventMaskButtonPress* = 1'u32 shl 2
  EventMaskButtonRelease* = 1'u32 shl 3
  EventMaskButtonMotion* = 1'u32 shl 13
  GrabModeSync* = 0'u8
  GrabModeAsync* = 1'u8
  AllowReplayPointer* = 2'u8
  AllowSyncPointer* = 1'u8
  GrabStatusSuccess* = 0'u8
  ButtonIndexAny* = 0'u8
  ModMaskAny* = 0x8000'u16
  ModMaskLock* = 1'u16 shl 1

proc xcbConnect*(display: cstring; screen: ptr cint): ptr XcbConnection {.importc: "xcb_connect", cdecl, header: "xcb/xcb.h".}
proc xcbConnectionHasError*(connection: ptr XcbConnection): cint {.importc: "xcb_connection_has_error", cdecl, header: "xcb/xcb.h".}
proc xcbDisconnect*(connection: ptr XcbConnection) {.importc: "xcb_disconnect", cdecl, header: "xcb/xcb.h".}
proc xcbGetSetup*(connection: ptr XcbConnection): ptr XcbSetup {.importc: "xcb_get_setup", cdecl, header: "xcb/xcb.h".}
proc xcbSetupRootsIterator*(setup: ptr XcbSetup): XcbScreenIterator {.importc: "xcb_setup_roots_iterator", cdecl, header: "xcb/xcb.h".}
proc xcbScreenNext*(screenIterator: ptr XcbScreenIterator) {.importc: "xcb_screen_next", cdecl, header: "xcb/xcb.h".}
proc xcbChangeWindowAttributesChecked*(connection: ptr XcbConnection; window, mask: uint32; values: ptr uint32): XcbVoidCookie {.importc: "xcb_change_window_attributes_checked", cdecl, header: "xcb/xproto.h".}
proc xcbCreateWindowChecked*(connection: ptr XcbConnection; depth: uint8; window, parent: uint32; x, y: int16; width, height, borderWidth: uint16; windowClass: uint16; visual, valueMask: uint32; values: ptr uint32): XcbVoidCookie {.importc: "xcb_create_window_checked", cdecl, header: "xcb/xproto.h".}
proc xcbChangeSaveSetChecked*(connection: ptr XcbConnection; mode: uint8; window: uint32): XcbVoidCookie {.importc: "xcb_change_save_set_checked", cdecl, header: "xcb/xproto.h".}
proc xcbMapWindowChecked*(connection: ptr XcbConnection; window: uint32): XcbVoidCookie {.importc: "xcb_map_window_checked", cdecl, header: "xcb/xproto.h".}
proc xcbWarpPointerChecked*(connection: ptr XcbConnection; srcWindow, dstWindow: uint32; srcX, srcY: int16; srcWidth, srcHeight: uint16; dstX, dstY: int16): XcbVoidCookie {.importc: "xcb_warp_pointer_checked", cdecl, header: "xcb/xproto.h".}
proc xcbUnmapWindowChecked*(connection: ptr XcbConnection; window: uint32): XcbVoidCookie {.importc: "xcb_unmap_window_checked", cdecl, header: "xcb/xproto.h".}
proc xcbDestroyWindowChecked*(connection: ptr XcbConnection; window: uint32): XcbVoidCookie {.importc: "xcb_destroy_window_checked", cdecl, header: "xcb/xproto.h".}
proc xcbChangePropertyChecked*(connection: ptr XcbConnection; mode: uint8; window, property, kind: uint32; format: uint8; dataLength: uint32; data: pointer): XcbVoidCookie {.importc: "xcb_change_property_checked", cdecl, header: "xcb/xproto.h".}
proc xcbDeletePropertyChecked*(connection: ptr XcbConnection; window, property: uint32): XcbVoidCookie {.importc: "xcb_delete_property_checked", cdecl, header: "xcb/xproto.h".}
proc xcbGenerateId*(connection: ptr XcbConnection): uint32 {.importc: "xcb_generate_id", cdecl, header: "xcb/xcb.h".}
when defined(stage1cFocusDiagnostics):
  import std/json
  import ./focus_diagnostics
  proc rawRequestCheck(connection: ptr XcbConnection; cookie: XcbVoidCookie): ptr XcbGenericError {.importc: "xcb_request_check", cdecl, header: "xcb/xcb.h".}
  proc xcbRequestCheck*(connection: ptr XcbConnection; cookie: XcbVoidCookie): ptr XcbGenericError =
    record(%*{"check_entry": true, "dispatch_id": currentDispatch,
        "checked_cookie_sequence": cookie.sequence, "call_site": "xcb_request_check"})
    result = rawRequestCheck(connection, cookie)
    record(%*{"check_exit": true, "dispatch_id": currentDispatch,
        "checked_cookie_sequence": cookie.sequence,
        "request_status": (if result == nil: "OK" else: "X_ERROR:" & $result.errorCode)})
else:
  proc xcbRequestCheck*(connection: ptr XcbConnection; cookie: XcbVoidCookie): ptr XcbGenericError {.importc: "xcb_request_check", cdecl, header: "xcb/xcb.h".}
proc xcbInternAtom*(connection: ptr XcbConnection; onlyIfExists: uint8; nameLength: uint16; name: cstring): XcbInternAtomCookie {.importc: "xcb_intern_atom", cdecl, header: "xcb/xproto.h".}
proc xcbInternAtomReply*(connection: ptr XcbConnection; cookie: XcbInternAtomCookie; error: ptr ptr XcbGenericError): ptr XcbInternAtomReply {.importc: "xcb_intern_atom_reply", cdecl, header: "xcb/xproto.h".}
proc xcbChangeProperty*(connection: ptr XcbConnection; mode: uint8; window, property, kind: uint32; format: uint8; dataLength: uint32; data: pointer): XcbVoidCookie {.importc: "xcb_change_property", cdecl, header: "xcb/xproto.h".}
proc xcbQueryTree*(connection: ptr XcbConnection; window: uint32): XcbQueryTreeCookie {.importc: "xcb_query_tree", cdecl, header: "xcb/xproto.h".}
proc xcbQueryTreeReply*(connection: ptr XcbConnection; cookie: XcbQueryTreeCookie; error: ptr ptr XcbGenericError): ptr XcbQueryTreeReply {.importc: "xcb_query_tree_reply", cdecl, header: "xcb/xproto.h".}
proc xcbQueryTreeChildren*(reply: ptr XcbQueryTreeReply): ptr uint32 {.importc: "xcb_query_tree_children", cdecl, header: "xcb/xproto.h".}
proc xcbQueryTreeChildrenLength*(reply: ptr XcbQueryTreeReply): cint {.importc: "xcb_query_tree_children_length", cdecl, header: "xcb/xproto.h".}
proc xcbGetWindowAttributes*(connection: ptr XcbConnection; window: uint32): XcbGetWindowAttributesCookie {.importc: "xcb_get_window_attributes", cdecl, header: "xcb/xproto.h".}
proc xcbGetWindowAttributesReply*(connection: ptr XcbConnection; cookie: XcbGetWindowAttributesCookie; error: ptr ptr XcbGenericError): ptr XcbGetWindowAttributesReply {.importc: "xcb_get_window_attributes_reply", cdecl, header: "xcb/xproto.h".}
proc xcbGetGeometry*(connection: ptr XcbConnection; window: uint32): XcbGetGeometryCookie {.importc: "xcb_get_geometry", cdecl, header: "xcb/xproto.h".}
proc xcbGetGeometryReply*(connection: ptr XcbConnection; cookie: XcbGetGeometryCookie; error: ptr ptr XcbGenericError): ptr XcbGetGeometryReply {.importc: "xcb_get_geometry_reply", cdecl, header: "xcb/xproto.h".}
proc xcbQueryPointer*(connection: ptr XcbConnection; window: uint32): XcbQueryPointerCookie {.importc: "xcb_query_pointer", cdecl, header: "xcb/xproto.h".}
proc xcbQueryPointerReply*(connection: ptr XcbConnection; cookie: XcbQueryPointerCookie; error: ptr ptr XcbGenericError): ptr XcbQueryPointerReply {.importc: "xcb_query_pointer_reply", cdecl, header: "xcb/xproto.h".}
proc xcbGetProperty*(connection: ptr XcbConnection; delete: uint8; window, property, propertyType: uint32; longOffset, longLength: uint32): XcbGetPropertyCookie {.importc: "xcb_get_property", cdecl, header: "xcb/xproto.h".}
proc xcbGetPropertyReply*(connection: ptr XcbConnection; cookie: XcbGetPropertyCookie; error: ptr ptr XcbGenericError): ptr XcbGetPropertyReply {.importc: "xcb_get_property_reply", cdecl, header: "xcb/xproto.h".}
proc xcbGetPropertyValue*(reply: ptr XcbGetPropertyReply): pointer {.importc: "xcb_get_property_value", cdecl, header: "xcb/xproto.h".}
proc xcbGetPropertyValueLength*(reply: ptr XcbGetPropertyReply): cint {.importc: "xcb_get_property_value_length", cdecl, header: "xcb/xproto.h".}
proc xcbFlush*(connection: ptr XcbConnection): cint {.importc: "xcb_flush", cdecl, header: "xcb/xcb.h".}
proc xcbSetInputFocusChecked*(connection: ptr XcbConnection; revertTo: uint8; focus: uint32; time: uint32): XcbVoidCookie {.importc: "xcb_set_input_focus_checked", cdecl, header: "xcb/xproto.h".}
proc xcbGetInputFocus*(connection: ptr XcbConnection): XcbGetInputFocusCookie {.importc: "xcb_get_input_focus", cdecl, header: "xcb/xproto.h".}
proc xcbGetInputFocusReply*(connection: ptr XcbConnection; cookie: XcbGetInputFocusCookie; error: ptr ptr XcbGenericError): ptr XcbGetInputFocusReply {.importc: "xcb_get_input_focus_reply", cdecl, header: "xcb/xproto.h".}
proc xcbConfigureWindowChecked*(connection: ptr XcbConnection; window, mask: uint32; values: ptr XcbConfigureWindowValueList): XcbVoidCookie {.importc: "xcb_configure_window_checked", cdecl, header: "xcb/xproto.h".}
proc xcbConfigureWindow*(connection: ptr XcbConnection; window: uint32; mask: uint16; values: pointer): XcbVoidCookie {.importc: "xcb_configure_window", cdecl, header: "xcb/xproto.h".}
proc xcbCirculateWindow*(connection: ptr XcbConnection; direction: uint8; window: uint32): XcbVoidCookie {.importc: "xcb_circulate_window", cdecl, header: "xcb/xproto.h".}
proc xcbGrabServerChecked*(connection: ptr XcbConnection): XcbVoidCookie {.importc: "xcb_grab_server_checked", cdecl, header: "xcb/xproto.h".}
proc xcbUngrabServerChecked*(connection: ptr XcbConnection): XcbVoidCookie {.importc: "xcb_ungrab_server_checked", cdecl, header: "xcb/xproto.h".}
proc xcbGrabServer*(connection: ptr XcbConnection): XcbVoidCookie {.importc: "xcb_grab_server", cdecl, header: "xcb/xproto.h".}
proc xcbUngrabServer*(connection: ptr XcbConnection): XcbVoidCookie {.importc: "xcb_ungrab_server", cdecl, header: "xcb/xproto.h".}
proc xcbWaitForEvent*(connection: ptr XcbConnection): ptr XcbGenericEvent {.importc: "xcb_wait_for_event", cdecl, header: "xcb/xcb.h".}
proc xcbPollForEvent*(connection: ptr XcbConnection): ptr XcbGenericEvent {.importc: "xcb_poll_for_event", cdecl, header: "xcb/xcb.h".}
proc xcbGetFileDescriptor*(connection: ptr XcbConnection): cint {.importc: "xcb_get_file_descriptor", cdecl, header: "xcb/xcb.h".}
proc xcbGrabButton*(connection: ptr XcbConnection; ownerEvents: uint8; grabWindow: uint32; eventMask: uint16; pointerMode, keyboardMode: uint8; confineTo, cursor: uint32; button: uint8; modifiers: uint16): XcbVoidCookie {.importc: "xcb_grab_button", cdecl, header: "xcb/xproto.h".}
proc xcbAllowEvents*(connection: ptr XcbConnection; mode: uint8; time: uint32): XcbVoidCookie {.importc: "xcb_allow_events", cdecl, header: "xcb/xproto.h".}
proc xcbGrabPointer*(connection: ptr XcbConnection; ownerEvents: uint8; grabWindow: uint32; eventMask: uint16; pointerMode, keyboardMode: uint8; confineTo, cursor: uint32; time: uint32): XcbGrabPointerCookie {.importc: "xcb_grab_pointer", cdecl, header: "xcb/xproto.h".}
proc xcbGrabPointerReply*(connection: ptr XcbConnection; cookie: XcbGrabPointerCookie; error: ptr ptr XcbGenericError): ptr XcbGrabPointerReply {.importc: "xcb_grab_pointer_reply", cdecl, header: "xcb/xproto.h".}
proc xcbUngrabPointer*(connection: ptr XcbConnection; time: uint32): XcbVoidCookie {.importc: "xcb_ungrab_pointer", cdecl, header: "xcb/xproto.h".}
proc cFree*(memory: pointer) {.importc: "free", cdecl, header: "stdlib.h".}
