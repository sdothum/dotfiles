## Atoms required by the Stage 1 root identity contract.

import ./bindings

type
  Atoms* = object
    netSupportingWmCheck*: uint32
    netWmName*: uint32
    netWmPid*: uint32
    utf8String*: uint32
    window*: uint32
    cardinal*: uint32
    atom*: uint32
    wmState*: uint32
    netWmDesktop*: uint32
    netWmWindowType*: uint32
    netWmWindowTypeDock*: uint32
    netWmWindowTypeToolbar*: uint32
    netWmWindowTypeDesktop*: uint32
    netClientList*: uint32
    netClientListStacking*: uint32
    netActiveWindow*: uint32
    netCurrentDesktop*: uint32
    cirrusActiveGroups*: uint32
    integer*: uint32
    stage4TestCommand*: uint32
    stage5TestCommand*: uint32
    stage6TestCommand*: uint32
    cirrusStatus*: uint32
    ipcCommand*: uint32
    ipcResponse*: uint32
    ipcRequest*: uint32
    string*: uint32
    wmNormalHints*: uint32
    wmSizeHints*: uint32
    netWmState*: uint32
    netWmStateAbove*: uint32
    netWmStateBelow*, netWmStateFullscreen*: uint32
    netWmStateMaximizedVert*, netWmStateMaximizedHorz*: uint32

proc internAtom(connection: ptr XcbConnection; name: string): uint32 =
  let cookie = xcbInternAtom(connection, 0, uint16(name.len), name.cstring)
  var error: ptr XcbGenericError
  let reply = xcbInternAtomReply(connection, cookie, addr error)
  if error != nil:
    let code = error.errorCode
    cFree(error)
    if reply != nil: cFree(reply)
    raise newException(IOError, "cannot intern atom " & name & " (X error " & $code & ")")
  if reply == nil:
    raise newException(IOError, "cannot intern atom " & name & ": no reply")
  result = reply.atom
  cFree(reply)

proc initializeAtoms*(connection: ptr XcbConnection): Atoms =
  result.netSupportingWmCheck = internAtom(connection, "_NET_SUPPORTING_WM_CHECK")
  result.netWmName = internAtom(connection, "_NET_WM_NAME")
  result.netWmPid = internAtom(connection, "_NET_WM_PID")
  result.utf8String = internAtom(connection, "UTF8_STRING")
  result.window = internAtom(connection, "WINDOW")
  result.cardinal = internAtom(connection, "CARDINAL")
  result.atom = internAtom(connection, "ATOM")
  result.wmState = internAtom(connection, "WM_STATE")
  result.netWmDesktop = internAtom(connection, "_NET_WM_DESKTOP")
  result.netWmWindowType = internAtom(connection, "_NET_WM_WINDOW_TYPE")
  result.netWmWindowTypeDock = internAtom(connection, "_NET_WM_WINDOW_TYPE_DOCK")
  result.netWmWindowTypeToolbar = internAtom(connection, "_NET_WM_WINDOW_TYPE_TOOLBAR")
  result.netWmWindowTypeDesktop = internAtom(connection, "_NET_WM_WINDOW_TYPE_DESKTOP")
  result.netClientList = internAtom(connection, "_NET_CLIENT_LIST")
  result.netClientListStacking = internAtom(connection, "_NET_CLIENT_LIST_STACKING")
  result.netActiveWindow = internAtom(connection, "_NET_ACTIVE_WINDOW")
  result.netCurrentDesktop = internAtom(connection, "_NET_CURRENT_DESKTOP")
  result.cirrusActiveGroups = internAtom(connection, "CIRRUS_ACTIVE_GROUPS")
  result.integer = internAtom(connection, "INTEGER")
  result.stage4TestCommand = internAtom(connection, "_CIRRUS_NIM_STAGE4_TEST")
  result.stage5TestCommand = internAtom(connection, "_CIRRUS_NIM_STAGE5_TEST")
  result.stage6TestCommand = internAtom(connection, "_CIRRUS_NIM_STAGE6_TEST")
  result.cirrusStatus = internAtom(connection, "CIRRUS_STATUS")
  result.ipcCommand = internAtom(connection, "__WM_IPC_COMMAND")
  result.ipcResponse = internAtom(connection, "__WM_IPC_RESPONSE")
  result.ipcRequest = internAtom(connection, "__WM_IPC_REQUEST")
  result.string = internAtom(connection, "STRING")
  result.wmNormalHints = internAtom(connection, "WM_NORMAL_HINTS")
  result.wmSizeHints = internAtom(connection, "WM_SIZE_HINTS")
  result.netWmState = internAtom(connection, "_NET_WM_STATE")
  result.netWmStateAbove = internAtom(connection, "_NET_WM_STATE_ABOVE")
  result.netWmStateBelow = internAtom(connection, "_NET_WM_STATE_BELOW")
  result.netWmStateFullscreen = internAtom(connection, "_NET_WM_STATE_FULLSCREEN")
  result.netWmStateMaximizedVert = internAtom(connection, "_NET_WM_STATE_MAXIMIZED_VERT")
  result.netWmStateMaximizedHorz = internAtom(connection, "_NET_WM_STATE_MAXIMIZED_HORZ")
