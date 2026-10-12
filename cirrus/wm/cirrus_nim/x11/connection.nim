## Owns exactly one XCB connection and all X11 startup/shutdown operations.

import std/[strformat, options]
import ./bindings
import ./atoms
import ./events
import ./decoration
when defined(stage1cFocusDiagnostics):
  import ./focus_diagnostics

type
  XConnection* = object
    raw: ptr XcbConnection
    screenNo*: cint
    root*: uint32
    rootVisual*: uint32
    rootDepth*: uint8
    decorationVisual*, decorationFormat*, decorationColormap*: uint32
    screenWidth*: uint16
    screenHeight*: uint16
    atoms*: Atoms

proc close*(connection: var XConnection)

proc connect*(display: string = ""): XConnection =
  var screenNo: cint
  let displayArg = if display.len == 0: nil else: display.cstring
  result.raw = xcbConnect(displayArg, addr screenNo)
  if result.raw == nil:
    raise newException(IOError, "xcb_connect returned no connection")
  result.screenNo = screenNo
  let connectionError = xcbConnectionHasError(result.raw)
  if connectionError != 0:
    xcbDisconnect(result.raw)
    result.raw = nil
    raise newException(IOError, &"cannot connect to X server (XCB error {connectionError})")

  let setup = xcbGetSetup(result.raw)
  if setup == nil:
    xcbDisconnect(result.raw)
    result.raw = nil
    raise newException(IOError, "X server returned no setup")
  var screens = xcbSetupRootsIterator(setup)
  if screens.rem <= 0 or screens.data == nil:
    xcbDisconnect(result.raw)
    result.raw = nil
    raise newException(IOError, "X server exposes no screen")
  for index in 0 ..< screenNo:
    xcbScreenNext(addr screens)
    if screens.rem <= 0 or screens.data == nil:
      xcbDisconnect(result.raw)
      result.raw = nil
      raise newException(IOError, "XCB selected a screen outside the setup roots")
  result.root = screens.data.root
  result.rootVisual = screens.data.rootVisual
  result.rootDepth = screens.data.rootDepth
  result.screenWidth = screens.data.widthInPixels
  result.screenHeight = screens.data.heightInPixels
  decorationResources(result.raw, screens.data, addr result.decorationVisual,
      addr result.decorationFormat, addr result.decorationColormap)
  try:
    result.atoms = initializeAtoms(result.raw)
  except:
    result.close()
    raise

proc claimWindowManager*(connection: var XConnection) =
  if connection.raw == nil:
    raise newException(IOError, "cannot claim WM ownership on a closed X connection")
  var eventMask = EventMaskSubstructureNotify or EventMaskSubstructureRedirect or
      EventMaskStructureNotify or EventMaskFocusChange or EventMaskPropertyChange
  let cookie = xcbChangeWindowAttributesChecked(connection.raw, connection.root,
      CwEventMask, addr eventMask)
  let error = xcbRequestCheck(connection.raw, cookie)
  if error != nil:
    let code = error.errorCode
    cFree(error)
    if code == ErrorBadAccess:
      raise newException(IOError, "another window manager already owns this display (BadAccess)")
    raise newException(IOError, &"cannot claim X11 window-manager ownership (X error {code})")
  if xcbFlush(connection.raw) <= 0:
    raise newException(IOError, "failed to flush X11 window-manager ownership request")

proc publishIdentity*(connection: XConnection; pid: uint32) =
  ## Stage 0 uses the root as the support window and leaves identity properties
  ## behind on quit. Stage 1 intentionally does not publish _NET_SUPPORTED.
  let root = connection.root
  let support = root
  discard xcbChangeProperty(connection.raw, PropModeReplace, root,
      connection.atoms.netSupportingWmCheck, connection.atoms.window, 32, 1,
      unsafeAddr support)
  discard xcbChangeProperty(connection.raw, PropModeReplace, support,
      connection.atoms.netSupportingWmCheck, connection.atoms.window, 32, 1,
      unsafeAddr support)
  let wmName = "cirrus"
  discard xcbChangeProperty(connection.raw, PropModeReplace, root,
      connection.atoms.netWmName, connection.atoms.utf8String, 8,
      uint32(wmName.len), unsafeAddr wmName[0])
  discard xcbChangeProperty(connection.raw, PropModeReplace, root,
      connection.atoms.netWmPid, connection.atoms.cardinal, 32, 1,
      unsafeAddr pid)
  if xcbFlush(connection.raw) <= 0:
    raise newException(IOError, "failed to publish root WM identity")

proc fileDescriptor*(connection: XConnection): cint =
  if connection.raw == nil: -1 else: xcbGetFileDescriptor(connection.raw)

proc rawHandleForX11*(connection: XConnection): ptr XcbConnection = connection.raw

proc allocateWindowId*(connection: XConnection): uint32 =
  if connection.raw == nil:
    raise newException(IOError, "cannot allocate an XID on a closed connection")
  result = xcbGenerateId(connection.raw)
  if result == 0:
    raise newException(IOError, "XCB could not allocate a window ID")

proc inputFocus*(connection: XConnection; callSite = "main.startup"): uint32 =
  var error: ptr XcbGenericError
  let cookie = xcbGetInputFocus(connection.raw)
  let reply = xcbGetInputFocusReply(connection.raw, cookie, addr error)
  when defined(stage1cFocusDiagnostics):
    queryRecord(callSite, cookie.sequence,
        (if reply == nil: 0'u32 else: reply.focus),
        (if reply == nil: 0'u8 else: reply.revertTo),
        (if error != nil: "X_ERROR:" & $error.errorCode
         elif reply == nil: "NO_REPLY" else: "OK"))
  if error != nil:
    let code = error.errorCode
    cFree(error)
    if reply != nil: cFree(reply)
    raise newException(IOError, "cannot query X input focus (X error " & $code & ")")
  if reply == nil: raise newException(IOError, "cannot query X input focus")
  result = reply.focus
  cFree(reply)

proc isConnected*(connection: XConnection): bool =
  connection.raw != nil and xcbConnectionHasError(connection.raw) == 0

proc nextEvent*(connection: XConnection): Option[XEventData] =
  if connection.raw == nil: none(XEventData)
  else: readEvent(connection.raw)

proc close*(connection: var XConnection) =
  if connection.raw != nil:
    xcbDisconnect(connection.raw)
    connection.raw = nil
