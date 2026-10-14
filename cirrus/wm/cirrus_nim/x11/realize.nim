## XCB realization for the ordered, X-free lifecycle effects.

import std/[os, sets, strformat, strutils]
import ./[bindings, connection, configure_values, queries, decoration]
import ../model/lifecycle
import ../model/types
import ../model/pointer

when defined(stage6FailureInjection):
  var stage6RestackCall = 0
  var stage6RaiseEffectCall = 0

  proc stage6RaiseFailureSubrequest*(): int =
    ## Diagnostic-only arm file contains `raise-effect-index subrequest-index`.
    let armPath = getEnv("CIRRUS_STAGE6_FAIL_RAISE_ARM_FILE")
    if armPath.len == 0 or not fileExists(armPath): return -1
    inc stage6RaiseEffectCall
    let fields = readFile(armPath).splitWhitespace()
    if fields.len != 2 or parseInt(fields[0]) != stage6RaiseEffectCall:
      return -1
    removeFile(armPath)
    parseInt(fields[1])

  proc stage6FailureRequestIndex*(): int =
    ## Diagnostic builds only: the arm file contains `call-index request-index`.
    ## The real checked ConfigureWindow request still reaches the X server.
    let armPath = getEnv("CIRRUS_STAGE6_FAIL_ARM_FILE")
    if armPath.len == 0 or not fileExists(armPath): return -1
    inc stage6RestackCall
    let fields = readFile(armPath).splitWhitespace()
    if fields.len != 2: return -1
    let wantedCall = parseInt(fields[0])
    let wantedRequest = parseInt(fields[1])
    if stage6RestackCall != wantedCall: return -1
    removeFile(armPath)
    wantedRequest

  proc stage6FailureTrace*(line: string) =
    let tracePath = getEnv("CIRRUS_STAGE6_FAIL_TRACE")
    if tracePath.len != 0:
      var stream = open(tracePath, fmAppend)
      stream.writeLine(line)
      stream.close()

proc checked(connection: XConnection; cookie: XcbVoidCookie;
             operation: string; missingIsOk = false) =
  let raw = connection.rawHandleForX11()
  let error = xcbRequestCheck(raw, cookie)
  if error != nil:
    let code = error.errorCode
    let resource = error.resourceId
    when defined(stage6FailureInjection):
      stage6FailureTrace("CHECK sequence=" & $cookie.sequence &
          " operation=" & operation & " result=ERROR code=" & $code &
          " resource=0x" & toHex(resource, 8))
    cFree(error)
    if missingIsOk and code == ErrorBadWindow: return
    raise newException(IOError, &"{operation} failed (X error {code}, resource 0x{resource:08x})")
  when defined(stage6FailureInjection):
    stage6FailureTrace("CHECK sequence=" & $cookie.sequence &
        " operation=" & operation & " result=OK")
  if not connection.isConnected:
    raise newException(IOError, operation & " lost the X connection")

proc checkedIgnoringError(connection: XConnection; cookie: XcbVoidCookie) =
  ## C's EWMH property helpers collect and free checked errors but ignore the
  ## result. Preserve that per-path behavior without hiding connection loss.
  let error = xcbRequestCheck(connection.rawHandleForX11(), cookie)
  if error != nil: cFree(error)
  if not connection.isConnected:
    raise newException(IOError, "X connection failed during EWMH property update")

proc queryRootChildren*(connection: XConnection): seq[uint32] =
  ## XCB QueryTree returns root children bottom-to-top (index zero is bottom).
  let raw = connection.rawHandleForX11()
  var error: ptr XcbGenericError
  let reply = xcbQueryTreeReply(raw, xcbQueryTree(raw, connection.root), addr error)
  if error != nil:
    let code = error.errorCode
    cFree(error)
    if reply != nil: cFree(reply)
    raise newException(IOError, &"root QueryTree failed (X error {code})")
  if reply == nil:
    raise newException(IOError, "root QueryTree returned no reply")
  let count = xcbQueryTreeChildrenLength(reply)
  let children = cast[ptr UncheckedArray[uint32]](xcbQueryTreeChildren(reply))
  for index in 0 ..< count:
    result.add(children[index])
  cFree(reply)

proc beginStackingGrab*(connection: XConnection) =
  checked(connection, xcbGrabServerChecked(connection.rawHandleForX11()),
      "grab server for stacking operation")

proc endStackingGrab*(connection: XConnection) =
  checked(connection, xcbUngrabServerChecked(connection.rawHandleForX11()),
      "release server after stacking operation")

proc beginConfigureRequestStacking*(connection: XConnection) =
  # Frozen C uses unchecked GrabServer/UnGrabServer around the redirected
  # ConfigureWindow request and the subsequent checked layer enforcement.
  discard xcbGrabServer(connection.rawHandleForX11())

proc endConfigureRequestStacking*(connection: XConnection) =
  discard xcbUngrabServer(connection.rawHandleForX11())
  # The coordinator polls the XCB file descriptor rather than calling
  # xcb_wait_for_event. Flush the unchecked ungrab before it returns to poll.
  discard xcbFlush(connection.rawHandleForX11())

proc beginCirculateRequestStacking*(connection: XConnection) =
  # Frozen C uses unchecked GrabServer around circulation plus layer repair.
  discard xcbGrabServer(connection.rawHandleForX11())

proc endCirculateRequestStacking*(connection: XConnection) =
  discard xcbUngrabServer(connection.rawHandleForX11())
  discard xcbFlush(connection.rawHandleForX11())

proc restackPhysicalBottomToTop*(connection: XConnection;
                                 windows: openArray[WindowId];
                                 diagnosticFailureIndex = -1) =
  ## Realize a previously model-ordered root list. The input direction is
  ## bottom-to-top and XCB receives each child above its predecessor.
  let raw = connection.rawHandleForX11()
  for index in 1 ..< windows.len:
    let intended = windows[index].raw
    let target = when defined(stage6FailureInjection):
        (if index == diagnosticFailureIndex: 0xffff_fffe'u32 else: intended)
      else: intended
    var values = XcbConfigureWindowValueList(data32: [windows[index - 1].raw,
        0'u32, 0, 0])
    let cookie = xcbConfigureWindowChecked(raw, target,
        (1'u32 shl 5) or (1'u32 shl 6), addr values)
    when defined(stage6FailureInjection):
      stage6FailureTrace("REQUEST sequence=" & $cookie.sequence &
          " index=" & $index & " intended=0x" & toHex(intended, 8) &
          " target=0x" & toHex(target, 8) & " sibling=0x" &
          toHex(windows[index - 1].raw, 8))
    checked(connection, cookie,
        "restack root child above predecessor")

proc publishClientLists*(connection: XConnection; managedWindows: openArray[uint32]) =
  let managed = toHashSet(managedWindows)
  var physicalOrder: seq[uint32]
  for window in connection.queryRootChildren():
    if window in managed:
      physicalOrder.add(window)
  let raw = connection.rawHandleForX11()
  if physicalOrder.len == 0:
    checked(connection, xcbDeletePropertyChecked(raw, connection.root,
        connection.atoms.netClientList), "clear _NET_CLIENT_LIST")
    checked(connection, xcbDeletePropertyChecked(raw, connection.root,
        connection.atoms.netClientListStacking), "clear _NET_CLIENT_LIST_STACKING")
    return
  let valuesPtr = if physicalOrder.len == 0: nil else: unsafeAddr physicalOrder[0]
  checked(connection, xcbChangePropertyChecked(raw, PropModeReplace,
      connection.root, connection.atoms.netClientList, connection.atoms.window,
      32, uint32(physicalOrder.len), valuesPtr), "publish _NET_CLIENT_LIST")
  checked(connection, xcbChangePropertyChecked(raw, PropModeReplace,
      connection.root, connection.atoms.netClientListStacking,
      connection.atoms.window, 32, uint32(physicalOrder.len), valuesPtr),
      "publish _NET_CLIENT_LIST_STACKING")

proc passUnmanagedConfigureGeometry*(connection: XConnection; window: uint32;
                                     mask: uint16; x, y: int16;
                                     width, height: uint16) =
  ## Forward only geometry fields. Stack/sibling behavior is a later stage.
  var values: XcbConfigureWindowValueList
  let packed = packGeometryValues(mask, int32(x), int32(y), uint32(width), uint32(height))
  values.data32 = [packed.values[0], packed.values[1], packed.values[2], packed.values[3]]
  if packed.mask == 0: return
  checked(connection, xcbConfigureWindowChecked(connection.rawHandleForX11(),
      window, packed.mask, addr values), "forward unmanaged geometry ConfigureRequest",
      missingIsOk = true)

when defined(stage7d3cPrivateExecution):
  proc realizePrivateGeometryUnchecked*(connection: XConnection;
      effect: WmEffect): uint32 =
    ## Diagnostic-only compatibility path for the frozen-C unchecked move / resize
    ## requests. It deliberately does not call xcb_request_check.
    let raw = connection.rawHandleForX11()
    var values: XcbConfigureWindowValueList
    var mask: uint16
    case effect.kind
    of weMoveClient:
      mask = 1'u16 or 2'u16
      values.data32 = [uint32(effect.geometry.x and 0xffff'i32),
          uint32(effect.geometry.y and 0xffff'i32), 0, 0]
    of weResizeClient:
      mask = 4'u16 or 8'u16
      values.data32 = [effect.geometry.width, effect.geometry.height, 0, 0]
    else:
      raise newException(ValueError,
          "diagnostic unchecked geometry path only accepts move/resize effects")
    let cookie = xcbConfigureWindow(raw, effect.window.raw, mask, addr values)
    result = uint32(cookie.sequence)

proc realizePrivateButtonEffect*(connection: XConnection;
                                 effect: PrivateEffect): seq[uint32] =
  ## Diagnostic private realization only. Requests are unchecked like frozen C;
  ## their sequence numbers are returned for attribution by the coordinator.
  let raw = connection.rawHandleForX11()
  case effect.kind
  of pfeUngrabButtons:
    let cookie = xcbUngrabButton(raw, ButtonIndexAny, effect.window.raw,
        ModMaskAny)
    result.add(uint32(cookie.sequence))
  of pfeGrabButtons:
    for spec in effect.buttonGrabs:
      let cookie = xcbGrabButton(raw, 0, effect.window.raw,
          uint16(EventMaskButtonPress), GrabModeSync, GrabModeAsync,
          0, 0, spec.button, spec.modifiers)
      result.add(uint32(cookie.sequence))
  else:
    raise newException(ValueError, "not a button-grab private effect")

proc realize*(connection: XConnection; effect: WmEffect;
              managedWindows: openArray[uint32]; diagnosticRaiseSubrequest = -1) =
  let raw = connection.rawHandleForX11()
  case effect.kind
  of weSelectClientEvents:
    var mask = EventMaskEnterWindow or EventMaskFocusChangeClient or
        EventMaskPropertyChangeClient
    checked(connection, xcbChangeWindowAttributesChecked(raw,
        effect.window.raw, CwEventMask, addr mask), "select client events")
  of weAddToSaveSet:
    checked(connection, xcbChangeSaveSetChecked(raw, SaveSetInsert,
        effect.window.raw), "add client to save-set")
  of weRemoveFromSaveSet:
    checked(connection, xcbChangeSaveSetChecked(raw, SaveSetDelete,
        effect.window.raw), "remove client from save-set", missingIsOk = true)
  of wePublishDesktop:
    var group = effect.group.raw
    checked(connection, xcbChangePropertyChecked(raw, PropModeReplace,
        effect.window.raw, connection.atoms.netWmDesktop,
        connection.atoms.cardinal, 32, 1, addr group),
        "publish _NET_WM_DESKTOP")
  of weMapClient:
    let cookie = xcbMapWindowChecked(raw, effect.window.raw)
    if effect.ignoreFailure:
      checkedIgnoringError(connection, cookie)
    else:
      checked(connection, cookie, "map client")
  of weUnmapClient:
    checked(connection, xcbUnmapWindowChecked(raw, effect.window.raw),
        "unmap failed management client", missingIsOk = true)
  of weCreateDecoration:
    if connection.decorationVisual == 0 or connection.decorationFormat == 0:
      raise newException(IOError, "ARGB decoration resources unavailable")
    # Selected-value order follows the XCB CW bit order.
    var values = [0'u32, 0'u32, 1'u32, 1'u32 shl 15,
        connection.decorationColormap]
    let mask = CwBackPixel or (1'u32 shl 3) or (1'u32 shl 11) or
        CwOverrideRedirect or (1'u32 shl 13)
    checked(connection, xcbCreateWindowChecked(raw, 32,
        effect.decoration.raw, connection.root, effect.x, effect.y,
        effect.width, effect.height, 0, WindowClassInputOutput,
        connection.decorationVisual, mask, addr values[0]), "create sibling decoration")
  of wePaintDecoration:
    paintDecoration(raw, effect.decoration.raw, connection.decorationFormat,
        effect.geometry.width, effect.geometry.height, effect.outerColor)
  of weMapDecoration:
    # C's frame-map path is unchecked and continues if a frame disappeared.
    # Preserve that stale-decoration behavior while still surfacing other X errors.
    let cookie = xcbMapWindowChecked(raw, effect.decoration.raw)
    if effect.ignoreFailure:
      checkedIgnoringError(connection, cookie)
    else:
      checked(connection, cookie, "map sibling decoration", missingIsOk = true)
  of wePlaceClientAboveDecoration:
    var values = XcbConfigureWindowValueList(data32: [effect.decoration.raw,
        0'u32, 0, 0])
    checked(connection, xcbConfigureWindowChecked(raw, effect.window.raw,
        (1'u32 shl 5) or (1'u32 shl 6), addr values),
        "place startup client above sibling decoration")
  of weUnmapDecoration:
    checked(connection, xcbUnmapWindowChecked(raw, effect.decoration.raw),
        "unmap sibling decoration", missingIsOk = true)
  of weDestroyDecoration:
    checked(connection, xcbDestroyWindowChecked(raw, effect.decoration.raw),
        "destroy sibling decoration", missingIsOk = true)
  of weMoveClient:
    let packed = packGeometryValues(3'u16, effect.geometry.x, effect.geometry.y,
        effect.geometry.width, effect.geometry.height)
    var values = XcbConfigureWindowValueList(data32: [packed.values[0],
        packed.values[1], 0'u32, 0])
    if getEnv("CIRRUS_STAGE5_TRACE") == "1":
      stderr.writeLine(&"STAGE5_NIM configure-client mask=0x3 values={values.data32} geometry=({effect.geometry.x},{effect.geometry.y},{effect.geometry.width},{effect.geometry.height})")
    checked(connection, xcbConfigureWindowChecked(raw, effect.window.raw,
        1'u32 or 2'u32, addr values), "move client")
  of weResizeClient:
    var values = XcbConfigureWindowValueList(data32: [
        uint32(min(effect.geometry.width, uint32(high(uint16)))),
        uint32(min(effect.geometry.height, uint32(high(uint16)))), 0, 0])
    checked(connection, xcbConfigureWindowChecked(raw, effect.window.raw,
        4'u32 or 8'u32, addr values), "resize client")
  of weConfigureDecoration:
    if effect.geometry.width == 0 or effect.geometry.height == 0:
      checked(connection, xcbUnmapWindowChecked(raw, effect.decoration.raw),
          "unmap clipped decoration", missingIsOk = true)
    else:
      let packed = packGeometryValues(15'u16, effect.geometry.x, effect.geometry.y,
          effect.geometry.width, effect.geometry.height)
      var values = XcbConfigureWindowValueList(data32: [packed.values[0],
          packed.values[1], packed.values[2], packed.values[3]])
      if getEnv("CIRRUS_STAGE5_TRACE") == "1":
        stderr.writeLine(&"STAGE5_NIM configure-decoration mask=0xf values={values.data32} geometry=({effect.geometry.x},{effect.geometry.y},{effect.geometry.width},{effect.geometry.height})")
      checked(connection, xcbConfigureWindowChecked(raw, effect.decoration.raw,
          packed.mask, addr values),
          "synchronize sibling decoration")
      checked(connection, xcbMapWindowChecked(raw, effect.decoration.raw),
          "map synchronized sibling decoration")
  of weConfigureRequest:
    let values = packConfigureRequestValues(effect.configureValueMask,
        effect.x, effect.y, effect.width, effect.height,
        effect.configureBorderWidth, effect.configureSibling.raw,
        effect.configureStackMode)
    # Frozen C deliberately uses the unchecked ConfigureWindow request here.
    # The surrounding coordinator performs layer enforcement when STACK_MODE
    # is active; errors from this request remain asynchronous, as in C.
    discard xcbConfigureWindow(raw, effect.window.raw,
        effect.configureValueMask, cast[pointer](unsafeAddr values[0]))
    discard xcbFlush(raw)
  of weCirculateRequest:
    # Preserve frozen C's call `xcb_circulate_window(conn, window, direction)`
    # despite the XCB signature being (connection, direction, window). C
    # narrows the child XID into direction and converts place into the window
    # argument. This intentionally submits the same invalid request.
    let direction = uint8(effect.window.raw and 0xff'u32)
    let target = uint32(effect.circulatePlace)
    let cookie = xcbCirculateWindow(raw, direction, target)
    when defined(stage6FailureInjection):
      stage6FailureTrace("CIRCULATE request sequence=" & $cookie.sequence &
          " direction=" & $direction & " window=" & $target &
          " originalChild=0x" & toHex(effect.window.raw, 8) &
          " originalPlace=" & $effect.circulatePlace)
  of weApplyEwmhGeometry:
    if effect.maxed:
      var border = [0'u32, 0, 0, 0]
      discard xcbConfigureWindow(raw, effect.window.raw, 1'u16 shl 4,
          cast[pointer](unsafeAddr border[0]))
    let position = [uint32(cast[uint16](int16(effect.geometry.x))),
        uint32(cast[uint16](int16(effect.geometry.y))), 0'u32, 0]
    discard xcbConfigureWindow(raw, effect.window.raw, 3'u16,
        cast[pointer](unsafeAddr position[0]))
    let size = [uint32(min(effect.geometry.width, uint32(high(uint16)))),
        uint32(min(effect.geometry.height, uint32(high(uint16)))), 0'u32, 0]
    discard xcbConfigureWindow(raw, effect.window.raw, 12'u16,
        cast[pointer](unsafeAddr size[0]))
    if effect.decoration.raw != 0:
      let frame = packGeometryValues(15'u16, effect.frameGeometry.x,
          effect.frameGeometry.y, effect.frameGeometry.width,
          effect.frameGeometry.height)
      var values = XcbConfigureWindowValueList(data32: [frame.values[0],
          frame.values[1], frame.values[2], frame.values[3]])
      discard xcbConfigureWindow(raw, effect.decoration.raw, uint16(frame.mask),
          addr values)
  of wePublishEwmhState:
    var values: array[4, uint32]
    var count = 0'u32
    if effect.layer == wlAbove:
      values[count] = connection.atoms.netWmStateAbove; inc count
    if effect.maxed:
      values[count] = connection.atoms.netWmStateFullscreen; inc count
    if effect.vmaxed:
      values[count] = connection.atoms.netWmStateMaximizedVert; inc count
    if effect.hmaxed:
      values[count] = connection.atoms.netWmStateMaximizedHorz; inc count
    let data = if count == 0: nil else: addr values[0]
    checkedIgnoringError(connection, xcbChangePropertyChecked(raw,
        PropModeReplace, effect.window.raw, connection.atoms.netWmState,
        connection.atoms.atom, 32, count, data))
  of weSetUnmanagedEwmhState:
    let data = if effect.stateAtoms.len == 0: nil else: unsafeAddr effect.stateAtoms[0]
    checkedIgnoringError(connection, xcbChangePropertyChecked(raw,
        PropModeReplace, effect.window.raw, connection.atoms.netWmState,
        connection.atoms.atom, 32, uint32(effect.stateAtoms.len), data))
  of wePublishWmStateNormal:
    var values = [1'u32, 0'u32] # Normal, no icon window
    checked(connection, xcbChangePropertyChecked(raw, PropModeReplace,
        effect.window.raw, connection.atoms.wmState, connection.atoms.wmState,
        32, 2, addr values[0]), "publish WM_STATE")
  of weCenterPointerOnClient:
    checked(connection, xcbWarpPointerChecked(raw, 0, effect.window.raw,
        0, 0, 0, 0, int16(effect.width div 2), int16(effect.height div 2)),
        "center pointer on managed client", missingIsOk = true)
  of wePublishClientLists:
    connection.publishClientLists(managedWindows)
  of weRestackLayers:
    raise newException(ValueError, "layer restacking must be coordinated with a fresh runtime observation")
  of wePublishLayerState:
    let current = connection.readRuntimeProperty(effect.window.raw,
        connection.atoms.netWmState, connection.atoms.atom)
    var values: seq[uint32]
    if current.present and current.format == 32:
      for atom in current.values:
        if atom != connection.atoms.netWmStateAbove: values.add(atom)
    if effect.layer == wlAbove: values.add(connection.atoms.netWmStateAbove)
    let data = if values.len == 0: nil else: unsafeAddr values[0]
    let cookie = xcbChangePropertyChecked(raw, PropModeReplace,
        effect.window.raw, connection.atoms.netWmState, connection.atoms.atom,
        32, uint32(values.len), data)
    if effect.ignoreFailure:
      checkedIgnoringError(connection, cookie)
    else:
      checked(connection, cookie, "publish _NET_WM_STATE_ABOVE")
  of weSetInputFocus:
    let target = if effect.window.raw == 0: connection.root else: effect.window.raw
    let cookie = xcbSetInputFocusChecked(raw, 1'u8, target, 0'u32)
    if effect.ignoreFailure:
      checkedIgnoringError(connection, cookie)
    else:
      checked(connection, cookie, "set X input focus", missingIsOk = true)
  of weInstallButtonGrabs:
    for spec in buttonGrabPlan(effect.pointerModifier,
                               effect.pointerLockMasks):
      discard xcbGrabButton(raw, 0, effect.window.raw,
          uint16(EventMaskButtonPress), GrabModeSync, GrabModeAsync,
          0, 0, spec.button, spec.modifiers)
  of weAllowPointer:
    let mode = case effect.pointerAllowMode
      of pamSyncPointer: AllowSyncPointer
      of pamReplayPointer: AllowReplayPointer
    discard xcbAllowEvents(raw, mode, effect.pointerTime)
    discard xcbFlush(raw)
  of weGrabPointer:
    var error: ptr XcbGenericError
    let reply = xcbGrabPointerReply(raw,
        xcbGrabPointer(raw, 0, connection.root,
            uint16(EventMaskButtonRelease or EventMaskButtonMotion),
            GrabModeAsync, GrabModeAsync, 0, 0, effect.pointerTime), addr error)
    if error != nil:
      let code = error.errorCode
      cFree(error)
      if reply != nil: cFree(reply)
      raise newException(IOError, "grab pointer failed (X error " & $code & ")")
    if reply == nil:
      raise newException(IOError, "grab pointer returned no reply")
    let status = reply.status
    cFree(reply)
    if status != GrabStatusSuccess:
      raise newException(IOError, "grab pointer was not successful")
  of weUngrabPointer:
    discard xcbUngrabPointer(raw, effect.pointerTime)
    discard xcbFlush(raw)
  of wePublishActiveWindow:
    var target = effect.window.raw
    let cookie = xcbChangePropertyChecked(raw, PropModeReplace,
        connection.root, connection.atoms.netActiveWindow, connection.atoms.window,
        32, 1, addr target)
    if effect.ignoreFailure:
      checkedIgnoringError(connection, cookie)
    else:
      checked(connection, cookie, "publish _NET_ACTIVE_WINDOW")
  of wePublishCurrentDesktop:
    var group = effect.group.raw
    let cookie = xcbChangePropertyChecked(raw, PropModeReplace,
        connection.root, connection.atoms.netCurrentDesktop, connection.atoms.cardinal,
        32, 1, addr group)
    if effect.ignoreFailure:
      checkedIgnoringError(connection, cookie)
    else:
      checked(connection, cookie, "publish _NET_CURRENT_DESKTOP")
  of weRaiseClient:
    var values = XcbConfigureWindowValueList(data32: [0'u32, 0, 0, 0])
    if effect.decoration.raw != 0:
      let intended = effect.decoration.raw
      let target = when defined(stage6FailureInjection):
          (if diagnosticRaiseSubrequest == 1: 0xffff_fffe'u32 else: intended)
        else: intended
      let cookie = xcbConfigureWindowChecked(raw, target,
          1'u32 shl 6, addr values)
      when defined(stage6FailureInjection):
        stage6FailureTrace("RAISE sequence=" & $cookie.sequence &
            " intended=0x" & toHex(intended, 8) & " target=0x" &
            toHex(target, 8))
      if effect.ignoreFailure:
        checkedIgnoringError(connection, cookie)
      else:
        checked(connection, cookie, "raise focused decoration", missingIsOk = true)
    let intended = effect.window.raw
    let target = when defined(stage6FailureInjection):
        (if diagnosticRaiseSubrequest == 2: 0xffff_fffe'u32 else: intended)
      else: intended
    let cookie = xcbConfigureWindowChecked(raw, target,
        1'u32 shl 6, addr values)
    when defined(stage6FailureInjection):
      stage6FailureTrace("RAISE sequence=" & $cookie.sequence &
          " intended=0x" & toHex(intended, 8) & " target=0x" &
          toHex(target, 8))
    if effect.ignoreFailure:
      checkedIgnoringError(connection, cookie)
    else:
      checked(connection, cookie, "raise focused client", missingIsOk = true)
  of wePublishActiveGroups:
    var groups = effect.groups
    if groups.len == 0: groups = @[RawGroup(0)]
    var values = newSeq[uint32](groups.len)
    for index, group in groups: values[index] = group.raw
    checked(connection, xcbChangePropertyChecked(raw, PropModeReplace,
        connection.root, connection.atoms.cirrusActiveGroups,
        connection.atoms.integer, 32, uint32(values.len), addr values[0]),
        "publish _CIRRUS_ACTIVE_GROUPS")
  of wePublishStatus:
    let state = if effect.maxed: "maxed"
      elif effect.hmaxed: "hmaxed"
      elif effect.vmaxed: "vmaxed"
      elif effect.monocled: "monocled"
      else: "normal"
    let status = "{\"window\":\"0x" & toHex(effect.window.raw, 8).toLowerAscii &
        "\",\"geom\":{\"x\":" & $effect.x & ",\"y\":" & $effect.y &
        ",\"width\":" & $effect.width & ",\"height\":" & $effect.height &
        ",\"set_by_user\":" & (if effect.setByUser: "true" else: "false") &
        "},\"state\":\"" & state & "\",\"min_width\":" &
        $effect.resizeHints.minWidth & ",\"min_height\":" &
        $effect.resizeHints.minHeight & ",\"max_width\":0,\"max_height\":0," &
        "\"width_inc\":" & $effect.resizeHints.widthIncrement &
        ",\"height_inc\":" & $effect.resizeHints.heightIncrement & "," &
        "\"mapped\":" & (if effect.mapped: "true" else: "false") &
        ",\"group\":" & $effect.group.raw & "}"
    checked(connection, xcbChangePropertyChecked(raw, PropModeReplace,
        effect.window.raw, connection.atoms.cirrusStatus, connection.atoms.string,
        8, uint32(status.len), unsafeAddr status[0]), "publish CIRRUS_STATUS")
  if xcbFlush(raw) <= 0:
    raise newException(IOError, "failed to flush lifecycle effect " & $effect.kind)
