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
    supportWindow: uint32
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


# Opens an XCB display connection, resolves its screen and initializes rendering and atoms.
# Startup failures release the owned connection before propagating IOError.

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


# Requests root event ownership and rejects checked errors or a failed flush.

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


# Initializes RandR once, copies active monitor observations and selects screen-change events.

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


# Updates the active monitor list from a fresh snapshot and reports whether it changed.

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


# Returns the current monitor assigned to a window, or none when that output is absent.

proc monitorBounds*(connection: XConnection; window: uint32): Option[RandrMonitor] =
  let assigned = connection.monitorAssignments.getOrDefault(window)
  if assigned != 0:
    for monitor in connection.monitors:
      if monitor.output == assigned: return some(monitor)


# Assigns a containing monitor by coordinates, optionally falling back to the first monitor.

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


# Publishes the name and PID before initial desktop properties, as C does.

proc publishIdentity*(connection: XConnection; pid: uint32) =
  let root = connection.root
  discard xcbChangeProperty(connection.raw, PropModeReplace, root,
      connection.atoms.netWmPid, connection.atoms.cardinal, 32, 1,
      unsafeAddr pid)
  let wmName = "aureole"
  discard xcbChangeProperty(connection.raw, PropModeReplace, root,
      connection.atoms.netWmName, connection.atoms.utf8String, 8,
      uint32(wmName.len), unsafeAddr wmName[0])
  if xcbFlush(connection.raw) <= 0:
    raise newException(IOError, "failed to publish root WM identity")


# Observes a checked startup request and raises IOError on protocol or connection failure.

proc checkStartupRequest(connection: XConnection; cookie: XcbVoidCookie;
                         operation: string) =
  let error = xcbRequestCheck(connection.raw, cookie)
  if error != nil:
    let code = error.errorCode
    cFree(error)
    raise newException(IOError, operation & " failed (X error " & $code & ")")
  if xcbConnectionHasError(connection.raw) != 0:
    raise newException(IOError, operation & " lost the X connection")


# Removes root advertisements before destroying the support child, optionally clearing identity.

proc removeEwmhSupportingWindow(connection: var XConnection;
                                clearIdentity: bool) =
  if connection.raw == nil: return
  let raw = connection.raw
  # Remove the root advertisement before destroying the referenced resource.
  for atom in [connection.atoms.netSupportingWmCheck,
      connection.atoms.netSupported, connection.atoms.netDesktopViewport]:
    let deleteCookie = xcbDeletePropertyChecked(raw, connection.root, atom)
    let deleteError = xcbRequestCheck(raw, deleteCookie)
    if deleteError != nil: cFree(deleteError)
  if clearIdentity:
    for atom in [connection.atoms.netWmName, connection.atoms.netWmPid]:
      let deleteCookie = xcbDeletePropertyChecked(raw, connection.root, atom)
      let deleteError = xcbRequestCheck(raw, deleteCookie)
      if deleteError != nil: cFree(deleteError)
  if connection.supportWindow != 0'u32:
    let destroyCookie = xcbDestroyWindowChecked(raw, connection.supportWindow)
    let destroyError = xcbRequestCheck(raw, destroyCookie)
    if destroyError != nil: cFree(destroyError)
    connection.supportWindow = 0'u32
  discard xcbFlush(raw)


# Creates and initializes the EWMH support child, removing partial state on failure.

proc createEwmhSupportingWindow(connection: var XConnection) =
  let raw = connection.raw
  var overrideRedirect = 1'u32
  let support = xcbGenerateId(raw)
  if support == 0'u32:
    raise newException(IOError, "XCB could not allocate the EWMH supporting window ID")
  let createCookie = xcbCreateWindowChecked(raw, 0'u8, support,
      connection.root, 0'i16, 0'i16, 1'u16, 1'u16, 0'u16,
      WindowClassInputOutput, 0'u32, CwOverrideRedirect,
      addr overrideRedirect)
  connection.checkStartupRequest(createCookie, "create EWMH supporting window")
  connection.supportWindow = support

  var self = support
  var name = "aureole"
  try:
    let selfCookie = xcbChangePropertyChecked(raw, PropModeReplace, support,
        connection.atoms.netSupportingWmCheck, connection.atoms.window,
        32, 1, addr self)
    connection.checkStartupRequest(selfCookie,
        "set supporting-window self-reference")
    let nameCookie = xcbChangePropertyChecked(raw, PropModeReplace, support,
        connection.atoms.netWmName, connection.atoms.utf8String,
        8, uint32(name.len), unsafeAddr name[0])
    connection.checkStartupRequest(nameCookie,
        "set supporting-window EWMH name")
  except:
    connection.removeEwmhSupportingWindow(true)
    raise


# Advertise a distinct EWMH support child only after its own properties exist.

proc publishEwmhStartup*(connection: var XConnection) =
  let raw = connection.raw
  let root = connection.root
  # Clear stale EWMH advertisement while retaining the root identity just
  # published for this process.
  connection.removeEwmhSupportingWindow(false)

  try:
    connection.createEwmhSupportingWindow()
    var viewport = [0'u32, 0'u32]
    discard xcbChangeProperty(raw, PropModeReplace, root,
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
    discard xcbChangeProperty(raw, PropModeReplace, root,
        connection.atoms.netSupported, connection.atoms.atom,
        32, uint32(supported.len), addr supported[0])
    let support = connection.supportWindow
    let rootCookie = xcbChangePropertyChecked(raw, PropModeReplace, root,
        connection.atoms.netSupportingWmCheck, connection.atoms.window,
        32, 1, unsafeAddr support)
    connection.checkStartupRequest(rootCookie,
        "publish root EWMH supporting-window property")
    if xcbFlush(raw) <= 0:
      raise newException(IOError, "failed to flush EWMH startup properties")
  except:
    connection.removeEwmhSupportingWindow(true)
    raise


# Returns the XCB descriptor, or -1 when the connection is closed.

proc fileDescriptor*(connection: XConnection): cint =
  if connection.raw == nil: -1 else: xcbGetFileDescriptor(connection.raw)


# Borrows the raw XCB handle for use inside the X11 boundary.

proc rawHandleForX11*(connection: XConnection): ptr XcbConnection = connection.raw


# Advances the uint32 invalidation counter with explicit wrap to zero.

proc nextSnapshotInvalidation*(counter: uint32): uint32 =
  if counter == high(uint32): 0'u32 else: counter + 1'u32


# Allocates a nonzero XID on an open connection, raising IOError on failure.

proc allocateWindowId*(connection: XConnection): uint32 =
  if connection.raw == nil:
    raise newException(IOError, "cannot allocate an XID on a closed connection")
  result = xcbGenerateId(connection.raw)
  if result == 0:
    raise newException(IOError, "XCB could not allocate a window ID")


# Queries input focus and frees reply allocations, raising IOError for missing or failed replies.

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


# Reports whether an owned XCB handle exists without a connection error.

proc isConnected*(connection: XConnection): bool =
  connection.raw != nil and xcbConnectionHasError(connection.raw) == 0


# Polls and copies one event when the connection is open, otherwise returns none.

proc nextEvent*(connection: XConnection): Option[XEventData] =
  if connection.raw == nil: none(XEventData)
  else: readEvent(connection.raw)


# Collects and frees a checked shutdown error without propagating protocol failure.

proc checkShutdownRequest(connection: XConnection; cookie: XcbVoidCookie) =
  let error = xcbRequestCheck(connection.raw, cookie)
  if error != nil: cFree(error)


# Matches cleanup()'s focus reset/ungrab behavior. Restart additionally
# detaches save-set clients and preserves hidden mapped-state explicitly.

proc prepareForTermination*(connection: var XConnection;
                            clients: openArray[ClientState]; restart: bool) =
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


# Removes any supporting window, disconnects XCB and clears the owned handle.

proc close*(connection: var XConnection) =
  if connection.raw != nil:
    if connection.supportWindow != 0'u32:
      connection.removeEwmhSupportingWindow(true)
    xcbDisconnect(connection.raw)
    connection.raw = nil
