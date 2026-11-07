## Owns exactly one XCB connection and all X11 startup/shutdown operations.

import std/[strformat, options, tables]
import ./bindings
import ./atoms
import ./events
import ./decoration
import ./randr_runtime
import ../model/types
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
    snapshotInvalidation*: uint32
    randrEventBase*: int
    randrInitialized*: bool
    monitors*: seq[RandrMonitor]
    monitorAssignments*: Table[uint32, uint32]

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
  result.randrEventBase = -1
  result.monitorAssignments = initTable[uint32, uint32]()
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

proc initializeRandr*(connection: var XConnection) =
  if connection.randrInitialized: return
  connection.randrInitialized = true
  let base = randr_runtime.initializeRandr(connection.raw)
  connection.randrEventBase = int(base)
  if base < 0: return
  var available = false
  let observed = queryRandrMonitors(connection.raw, connection.root, available)
  for monitor in observed:
    if monitor.active: connection.monitors.insert(monitor, 0)
  selectRandrEvents(connection.raw, connection.root)

proc refreshRandr*(connection: var XConnection): bool =
  if connection.randrEventBase < 0: return false
  var available = false
  let observed = queryRandrMonitors(connection.raw, connection.root, available)
  if not available: return false
  let previous = connection.monitors
  for monitor in observed:
    var found = -1
    for index, existing in connection.monitors:
      if existing.output == monitor.output:
        found = index
        break
    if not monitor.active:
      if found >= 0: connection.monitors.delete(found)
    elif found >= 0:
      connection.monitors[found] = monitor
    else:
      connection.monitors.insert(monitor, 0)
  result = previous != connection.monitors

proc monitorBounds*(connection: XConnection; window: uint32): Option[RandrMonitor] =
  let assigned = connection.monitorAssignments.getOrDefault(window)
  if assigned != 0:
    for monitor in connection.monitors:
      if monitor.output == assigned: return some(monitor)

proc assignMonitor*(connection: var XConnection; window: uint32;
                    x, y: int32; fallback = false) =
  var selected = 0'u32
  for monitor in connection.monitors:
    if x >= int32(monitor.x) and x <= int32(monitor.x) + int32(monitor.width) and
        y >= int32(monitor.y) and y <= int32(monitor.y) + int32(monitor.height):
      selected = monitor.output
  if selected == 0 and fallback and connection.monitors.len > 0:
    selected = connection.monitors[0].output
  if selected == 0:
    connection.monitorAssignments.del(window)
  else:
    connection.monitorAssignments[window] = selected

proc publishIdentity*(connection: XConnection; pid: uint32) =
  ## Publish the name and PID before initial desktop properties, as C does.
  let root = connection.root
  discard xcbChangeProperty(connection.raw, PropModeReplace, root,
      connection.atoms.netWmPid, connection.atoms.cardinal, 32, 1,
      unsafeAddr pid)
  let wmName = "cirrus"
  discard xcbChangeProperty(connection.raw, PropModeReplace, root,
      connection.atoms.netWmName, connection.atoms.utf8String, 8,
      uint32(wmName.len), unsafeAddr wmName[0])
  if xcbFlush(connection.raw) <= 0:
    raise newException(IOError, "failed to publish root WM identity")

proc publishEwmhStartup*(connection: XConnection) =
  ## Preserve setup.c's viewport, supported-atoms, then support-check order.
  let root = connection.root
  var viewport = [0'u32, 0'u32]
  discard xcbChangeProperty(connection.raw, PropModeReplace, root,
      connection.atoms.netDesktopViewport, connection.atoms.cardinal, 32, 2,
      addr viewport[0])
  var supported = [connection.atoms.netSupported,
      connection.atoms.netWmDesktop, connection.atoms.netNumberOfDesktops,
      connection.atoms.netCurrentDesktop, connection.atoms.netActiveWindow,
      connection.atoms.netWmState, connection.atoms.netWmStateAbove,
      connection.atoms.netWmStateFullscreen,
      connection.atoms.netWmStateMaximizedVert,
      connection.atoms.netWmStateMaximizedHorz, connection.atoms.netWmName,
      connection.atoms.netWmIconName, connection.atoms.netWmWindowType,
      connection.atoms.netWmWindowTypeDock, connection.atoms.netWmPid,
      connection.atoms.netWmWindowTypeToolbar,
      connection.atoms.netWmWindowTypeDesktop,
      connection.atoms.netSupportingWmCheck,
      connection.atoms.netDesktopViewport]
  discard xcbChangeProperty(connection.raw, PropModeReplace, root,
      connection.atoms.netSupported, connection.atoms.atom,
      32, uint32(supported.len), addr supported[0])
  var support = root
  discard xcbChangeProperty(connection.raw, PropModeReplace, root,
      connection.atoms.netSupportingWmCheck, connection.atoms.window, 32, 1,
      addr support)
  discard xcbChangeProperty(connection.raw, PropModeReplace, support,
      connection.atoms.netSupportingWmCheck, connection.atoms.window, 32, 1,
      addr support)
  # setup.c ignores this flush result after queuing the EWMH properties.
  discard xcbFlush(connection.raw)

proc fileDescriptor*(connection: XConnection): cint =
  if connection.raw == nil: -1 else: xcbGetFileDescriptor(connection.raw)

proc rawHandleForX11*(connection: XConnection): ptr XcbConnection = connection.raw

proc nextSnapshotInvalidation*(counter: uint32): uint32 =
  if counter == high(uint32): 0'u32 else: counter + 1'u32

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

proc checkShutdownRequest(connection: XConnection; cookie: XcbVoidCookie) =
  let error = xcbRequestCheck(connection.raw, cookie)
  if error != nil: cFree(error)

proc prepareForTermination*(connection: var XConnection;
                            clients: openArray[ClientState]; restart: bool) =
  ## Match cleanup()'s focus reset/ungrab behavior. Restart additionally
  ## detaches save-set clients and preserves hidden mapped-state explicitly.
  if connection.raw == nil: return
  let raw = connection.raw
  # Preserve cleanup()'s exact legacy arguments: revert-to NONE, focus XID
  # numerically equal to XCB_INPUT_FOCUS_POINTER_ROOT (1), CurrentTime.
  discard xcbSetInputFocus(raw, 0'u8, 1'u32, 0'u32)
  if restart:
    for client in clients:
      var treeError: ptr XcbGenericError
      let tree = xcbQueryTreeReply(raw, xcbQueryTree(raw, client.window.raw),
          addr treeError)
      let parent = if tree == nil: 0'u32 else: tree.parent
      if treeError != nil: cFree(treeError)
      if tree != nil: cFree(tree)
      if parent != 0'u32 and parent != connection.root:
        connection.checkShutdownRequest(xcbReparentWindowChecked(raw,
            client.window.raw, connection.root,
            cast[int16](client.geometry.x), cast[int16](client.geometry.y)))
      connection.checkShutdownRequest(xcbChangeSaveSetChecked(raw, SaveSetDelete,
          client.window.raw))
      if not client.mapped:
        connection.checkShutdownRequest(xcbUnmapWindowChecked(raw,
            client.window.raw))
    discard xcbFlush(raw)
  for client in clients:
    discard xcbUngrabButton(raw, ButtonIndexAny, client.window.raw, ModMaskAny)

proc close*(connection: var XConnection) =
  if connection.raw != nil:
    xcbDisconnect(connection.raw)
    connection.raw = nil
