import std/os
import std/nativesockets
import std/posix
import std/oserrors
import std/strutils
import std/times
import std/re

const
  ProtocolVersion* = 1'u16
  MaxFrameSize* = 64 * 1024
  MaxClients = 16
  RequestPing = 1'u8
  RequestQueryFocused* = 2'u8
  RequestQueryCurrentGroup* = 3'u8
  RequestQuerySnapshot* = 4'u8
  RequestQueryClientState* = 5'u8
  RequestQueryClientList* = 6'u8
  RequestQueryClientClass* = 7'u8
  RequestWaitClass* = 8'u8
  RequestWaitName* = 9'u8
  RequestQueryClassList* = 10'u8
  RequestQueryNameList* = 11'u8
  ResponsePong = 1'u8
  StatusOk = 0'u8
  StatusError = 1'u8
  ErrorUnsupportedVersion = 1'u8
  ErrorUnknownRequest = 2'u8
  ErrorMalformedRequest = 3'u8
  ErrorFrameTooLarge = 4'u8
  ErrorInternal* = 5'u8
  ErrorNotReady* = 6'u8
  ErrorUnknownClient* = 7'u8
  ErrorMetadataUnavailable* = 8'u8
  ErrorTimeout* = 9'u8
  ResponseWaitClass = 8'u8
  ResponseWaitName = 9'u8

type
  DaemonRequestKind* = enum
    drPing, drQueryFocused, drQueryCurrentGroup, drQuerySnapshot,
      drQueryClientState, drQueryClientList, drQueryClientClass, drWaitClass,
      drWaitName, drQueryClassList, drQueryNameList

  DaemonRequest* = object
    version*: uint16
    kind*: DaemonRequestKind
    argument*: string
    timeoutMs*: uint32
    includeAll*: bool

  DaemonCachedClient* = object
    winid*: string
    group*: uint32
    mapped*: bool
    token*: string
    instanceName*: string
    className*: string
    metadataAvailable*: bool
    title*: string
    titleAvailable*: bool

  IpcClient = object
    fd: SocketHandle
    input: string
    output: string
    outputOffset: int
    closing: bool
    waiting: bool
    waitByName: bool
    waitPattern: string
    waitDeadline: float

  IpcServer* = object
    listener*: SocketHandle
    path*: string
    clients: seq[IpcClient]
    initialized: bool
    snapshotReady*: bool
    snapshotBody: string
    focused: string
    currentGroup: uint32
    cachedClients: seq[DaemonCachedClient]

proc close*(server: var IpcServer)

proc queueResponse(client: var IpcClient, payload: string)

proc be16(value: uint16): array[2, char] =
  result[0] = char((value shr 8) and 0xff)
  result[1] = char(value and 0xff)

proc readBe16(value: string): uint16 =
  (uint16(ord(value[0])) shl 8) or uint16(ord(value[1]))

proc be32(value: uint32): array[4, char] =
  result[0] = char((value shr 24) and 0xff)
  result[1] = char((value shr 16) and 0xff)
  result[2] = char((value shr 8) and 0xff)
  result[3] = char(value and 0xff)

proc readBe32(value: string): uint32 =
  (uint32(ord(value[0])) shl 24) or
  (uint32(ord(value[1])) shl 16) or
  (uint32(ord(value[2])) shl 8) or
  uint32(ord(value[3]))

proc frame(payload: string): string =
  let size = be32(uint32(payload.len))
  result = newStringOfCap(4 + payload.len)
  for c in size: result.add(c)
  result.add(payload)

proc responseOk(kind: uint8): string =
  let version = be16(ProtocolVersion)
  result.add(version[0]); result.add(version[1])
  result.add(char(StatusOk)); result.add(char(kind))
  result = frame(result)

proc responseData(kind: uint8, body: string): string =
  let version = be16(ProtocolVersion)
  result.add(version[0]); result.add(version[1])
  result.add(char(StatusOk)); result.add(char(kind))
  result.add(body)
  result = frame(result)

proc responseError(version: uint16, code: uint8, detail: string): string =
  let encodedVersion = be16(version)
  result.add(encodedVersion[0]); result.add(encodedVersion[1])
  result.add(char(StatusError)); result.add(char(code))
  result.add(detail)
  result = frame(result)

proc pingFrame*(): string =
  let version = be16(ProtocolVersion)
  var payload = newStringOfCap(3)
  payload.add(version[0]); payload.add(version[1]); payload.add(char(RequestPing))
  frame(payload)

proc decodeRequest(payload: string): tuple[request: DaemonRequest, error: string,
    code: uint8] =
  if payload.len < 3:
    return (DaemonRequest(), "request payload is too short", ErrorMalformedRequest)
  let version = readBe16(payload)
  if version != ProtocolVersion:
    return (DaemonRequest(version: version), "unsupported protocol version",
      ErrorUnsupportedVersion)
  if payload.len == 3:
    case uint8(ord(payload[2]))
    of RequestPing:
      result.request = DaemonRequest(version: version, kind: drPing)
      return
    of RequestQueryFocused, RequestQueryCurrentGroup, RequestQuerySnapshot,
      RequestQueryClientList:
      result.request = DaemonRequest(version: version,
        kind: DaemonRequestKind(ord(payload[2]) - int(RequestPing)))
      return
    else:
      return (DaemonRequest(version: version), "unknown request kind",
        ErrorUnknownRequest)
  if payload.len < 5:
    return (DaemonRequest(version: version), "malformed request payload",
      ErrorMalformedRequest)
  let kind = uint8(ord(payload[2]))
  if kind == RequestWaitClass or kind == RequestWaitName:
    let argumentLength = (uint16(ord(payload[3])) shl 8) or uint16(ord(payload[4]))
    if argumentLength == 0 or payload.len != 9 + int(argumentLength):
      return (DaemonRequest(version: version), "malformed request payload",
        ErrorMalformedRequest)
    let timeoutOffset = 5 + int(argumentLength)
    let timeoutMs = (uint32(ord(payload[timeoutOffset])) shl 24) or
      (uint32(ord(payload[timeoutOffset + 1])) shl 16) or
      (uint32(ord(payload[timeoutOffset + 2])) shl 8) or
      uint32(ord(payload[timeoutOffset + 3]))
    if timeoutMs == 0 or timeoutMs > 60000:
      return (DaemonRequest(version: version), "invalid wait timeout",
        ErrorMalformedRequest)
    try:
      discard re(payload[5 ..< timeoutOffset], {reIgnoreCase})
    except ValueError:
      return (DaemonRequest(version: version), "invalid wait pattern",
        ErrorMalformedRequest)
    result.request = DaemonRequest(version: version,
      kind: if kind == RequestWaitClass: drWaitClass else: drWaitName,
      argument: payload[5 ..< timeoutOffset], timeoutMs: timeoutMs)
    return
  if kind == RequestQueryClassList or kind == RequestQueryNameList:
    if payload.len < 8:
      return (DaemonRequest(version: version), "malformed request payload", ErrorMalformedRequest)
    let argumentLength = (uint16(ord(payload[4])) shl 8) or uint16(ord(payload[5]))
    if payload.len != 6 + int(argumentLength) or argumentLength == 0:
      return (DaemonRequest(version: version), "malformed request payload", ErrorMalformedRequest)
    if payload[3].ord != 0 and payload[3].ord != 1:
      return (DaemonRequest(version: version), "malformed request payload", ErrorMalformedRequest)
    result.request = DaemonRequest(version: version,
      kind: if kind == RequestQueryClassList: drQueryClassList else: drQueryNameList,
      includeAll: payload[3].ord == 1,
      argument: payload[6 .. ^1])
    return
  if kind != RequestQueryClientState and kind != RequestQueryClientClass:
    result.request = DaemonRequest(version: version)
    result.error = "unknown request kind"
    result.code = ErrorUnknownRequest
    return
  let argumentLength = (uint16(ord(payload[3])) shl 8) or uint16(ord(payload[4]))
  if argumentLength == 0 or payload.len != 5 + int(argumentLength):
    return (DaemonRequest(version: version), "malformed request payload",
      ErrorMalformedRequest)
  result.request = DaemonRequest(version: version,
    kind: DaemonRequestKind(ord(kind - RequestPing)),
    argument: payload[5 ..< 5 + int(argumentLength)])

proc cachedResponse(server: IpcServer, request: DaemonRequest): tuple[body: string,
    errorCode: uint8, error: string] =
  if not server.snapshotReady:
    return ("", ErrorNotReady, "daemon snapshot is not ready")
  case uint8(request.kind)
  of RequestQueryFocused - RequestPing:
    if server.focused.len > 0:
      return (server.focused, 0'u8, "")
    return ("ERROR no focused managed window", 0'u8, "")
  of RequestQueryCurrentGroup - RequestPing:
    return ($server.currentGroup, 0'u8, "")
  of RequestQuerySnapshot - RequestPing:
    return (server.snapshotBody, 0'u8, "")
  of RequestQueryClientState - RequestPing:
    for client in server.cachedClients:
      if client.winid == request.argument:
        return ("CLIENT " & client.winid & " " & $client.group & " " &
          (if client.mapped: "1" else: "0") &
          (if client.token.len > 0: " " & client.token else: ""), 0'u8, "")
    return ("", ErrorUnknownClient, "unknown managed window")
  of RequestQueryClientList - RequestPing:
    var body = newStringOfCap(server.cachedClients.len * 80)
    for client in server.cachedClients:
      body.add("CLIENT " & client.winid & " " & $client.group & " " &
        (if client.mapped: "1" else: "0") &
        (if client.token.len > 0: " " & client.token else: "") & "\n")
    return (body, 0'u8, "")
  of RequestQueryClientClass - RequestPing:
    for client in server.cachedClients:
      if client.winid == request.argument:
        if not client.metadataAvailable:
          return ("", ErrorMetadataUnavailable, "WM_CLASS unavailable")
        return (client.className, 0'u8, "")
    return ("", ErrorUnknownClient, "unknown managed window")
  else:
    return ("", ErrorUnknownRequest, "unknown request kind")

proc matchingClassClients(clients: seq[DaemonCachedClient], pattern: string): seq[string] =
  for client in clients:
    if client.mapped and client.metadataAvailable and client.className == pattern:
      result.add(client.winid)

proc matchingNameClients(clients: seq[DaemonCachedClient], pattern: string): seq[string] =
  let expression = re(pattern, {reIgnoreCase})
  for client in clients:
    if client.mapped and client.titleAvailable and client.title.match(expression):
      result.add(client.winid)

proc filteredClients(clients: seq[DaemonCachedClient], byName, includeAll: bool,
    pattern: string): seq[string] =
  if byName:
    let matches = matchingNameClients(clients, pattern)
    if includeAll:
      for client in clients:
        if client.titleAvailable and client.title.match(re(pattern, {reIgnoreCase})):
          result.add(client.winid)
    else:
      result = matches
  else:
    for client in clients:
      if (includeAll or client.mapped) and client.metadataAvailable and
          client.className == pattern:
        result.add(client.winid)

proc queueWaitResult(client: var IpcClient, clients: seq[DaemonCachedClient]) =
  if not client.waiting:
    return
  let matches = if client.waitByName: matchingNameClients(clients, client.waitPattern)
    else: matchingClassClients(clients, client.waitPattern)
  if matches.len > 0:
    queueResponse(client, responseData(
      if client.waitByName: ResponseWaitName else: ResponseWaitClass,
      matches.join("\n")))

proc serviceWaiters(server: var IpcServer) =
  let now = epochTime()
  for client in server.clients.mitems:
    if client.waiting and now >= client.waitDeadline:
      queueResponse(client, responseError(ProtocolVersion, ErrorTimeout,
        "window await timed out"))
    elif client.waiting:
      queueWaitResult(client, server.cachedClients)

proc closeClient(server: var IpcServer, index: int) =
  if server.clients[index].fd != osInvalidSocket:
    close(server.clients[index].fd)
  server.clients.delete(index)

proc queueResponse(client: var IpcClient, payload: string) =
  client.output = payload
  client.outputOffset = 0
  client.closing = true
  client.waiting = false

proc processInput(server: var IpcServer, client: var IpcClient): bool =
  ## Returns false when the client should be disconnected.
  if client.input.len > 4 + MaxFrameSize:
    queueResponse(client, responseError(ProtocolVersion, ErrorFrameTooLarge,
      "frame exceeds limit"))
    return true
  while client.input.len >= 4:
    let length = readBe32(client.input[0 .. 3])
    if length == 0 or length > MaxFrameSize:
      queueResponse(client, responseError(ProtocolVersion, ErrorFrameTooLarge,
        "frame exceeds limit"))
      return true
    if client.input.len < 4 + int(length):
      return true
    let payload = client.input[4 ..< 4 + int(length)]
    let consumed = 4 + int(length)
    if consumed == client.input.len:
      client.input.setLen(0)
    else:
      client.input = client.input[consumed .. ^1]
    let decoded = decodeRequest(payload)
    if decoded.error.len > 0:
      queueResponse(client, responseError(decoded.request.version,
        decoded.code, decoded.error))
      return true
    case decoded.request.kind
    of drPing:
      queueResponse(client, responseOk(ResponsePong))
    of drQueryFocused, drQueryCurrentGroup, drQuerySnapshot, drQueryClientState,
        drQueryClientList, drQueryClientClass:
      let cached = server.cachedResponse(decoded.request)
      if cached.errorCode != 0:
        queueResponse(client, responseError(ProtocolVersion, cached.errorCode,
          cached.error))
      elif cached.body.len + 4 > MaxFrameSize:
        queueResponse(client, responseError(ProtocolVersion, ErrorFrameTooLarge,
          "response exceeds limit"))
      else:
        queueResponse(client, responseData(uint8(ord(decoded.request.kind) + 1),
          cached.body))
    of drQueryClassList, drQueryNameList:
      if not server.snapshotReady:
        queueResponse(client, responseError(ProtocolVersion, ErrorNotReady,
          "daemon snapshot is not ready"))
      else:
        let values = filteredClients(server.cachedClients,
          decoded.request.kind == drQueryNameList, decoded.request.includeAll,
          decoded.request.argument)
        queueResponse(client, responseData(uint8(ord(decoded.request.kind) + 1),
          values.join("\n")))
    of drWaitClass:
      if not server.snapshotReady:
        queueResponse(client, responseError(ProtocolVersion, ErrorNotReady,
          "daemon snapshot is not ready"))
      else:
        let matches = matchingClassClients(server.cachedClients, decoded.request.argument)
        if matches.len > 0:
          queueResponse(client, responseData(ResponseWaitClass, matches.join("\n")))
        else:
          client.waiting = true
          client.waitByName = false
          client.waitPattern = decoded.request.argument
          client.waitDeadline = epochTime() + float(decoded.request.timeoutMs) / 1000.0
    of drWaitName:
      if not server.snapshotReady:
        queueResponse(client, responseError(ProtocolVersion, ErrorNotReady,
          "daemon snapshot is not ready"))
      else:
        let matches = matchingNameClients(server.cachedClients, decoded.request.argument)
        if matches.len > 0:
          queueResponse(client, responseData(ResponseWaitName, matches.join("\n")))
        else:
          client.waiting = true
          client.waitByName = true
          client.waitPattern = decoded.request.argument
          client.waitDeadline = epochTime() + float(decoded.request.timeoutMs) / 1000.0
    return true
  true

proc cacheSnapshot*(server: var IpcServer, body, focused: string,
    currentGroup: uint32, clients: seq[DaemonCachedClient]) =
  server.snapshotBody = body
  server.focused = focused
  server.currentGroup = currentGroup
  server.cachedClients = clients
  server.snapshotReady = true
  serviceWaiters(server)

proc invalidateCache*(server: var IpcServer) =
  server.snapshotReady = false
  server.snapshotBody = ""
  server.focused = ""
  server.currentGroup = 0
  server.cachedClients.setLen(0)
  for client in server.clients.mitems:
    if client.waiting:
      queueResponse(client, responseError(ProtocolVersion, ErrorNotReady,
        "daemon snapshot is not ready"))

proc cachedMetadata*(server: IpcServer, winid, token: string,
    instanceName, className: var string): bool =
  ## Reuse metadata only when it belongs to the currently accepted identity.
  for client in server.cachedClients:
    if client.winid == winid and client.token == token and client.metadataAvailable:
      instanceName = client.instanceName
      className = client.className
      return true
  false

proc retryableSocketError(): bool =
  osLastError().cint in [EAGAIN, EINTR]

proc socketPath*(): string =
  let runtime = getEnv("XDG_RUNTIME_DIR")
  if runtime.len == 0:
    let wme = getEnv("WME")
    if wme.len == 0:
      return ""
    return wme / "zephyrd.sock"
  runtime / "zephyr" / "zephyrd.sock"

proc ensureParent(path: string) =
  let parent = splitFile(path).dir
  if parent.len == 0:
    quit("zephyrd IPC: invalid socket path")
  if not dirExists(parent):
    createDir(parent)
  let permissions = getFilePermissions(parent)
  if fpGroupWrite in permissions or fpOthersWrite in permissions:
    quit("zephyrd IPC: unsafe socket parent permissions")

proc probe(path: string): bool =
  let fd = createNativeSocket(AF_UNIX, SOCK_STREAM, 0)
  if fd == osInvalidSocket:
    return false
  defer: close(fd)
  var address = makeUnixAddr(path)
  connect(fd, cast[ptr SockAddr](addr address), sizeof(address).SockLen) == 0

proc open*(server: var IpcServer, path = socketPath()): bool =
  if server.initialized:
    server.close()
  if path.len == 0:
    return false
  ensureParent(path)
  if fileExists(path):
    if probe(path):
      quit("zephyrd IPC: another daemon is serving " & path)
    removeFile(path)
    stderr.writeLine("IPC_SOCKET_STALE_REMOVED " & path)

  let fd = createNativeSocket(AF_UNIX, SOCK_STREAM, 0)
  if fd == osInvalidSocket:
    return false
  var address = makeUnixAddr(path)
  if bindAddr(fd, cast[ptr SockAddr](addr address), sizeof(address).SockLen) < 0 or
      nativesockets.listen(fd, MaxClients.cint) < 0:
    close(fd)
    return false
  setBlocking(fd, false)
  setFilePermissions(path, {fpUserRead, fpUserWrite})
  server.listener = fd
  server.path = path
  server.clients = @[]
  server.initialized = true
  true

proc close*(server: var IpcServer) =
  if not server.initialized:
    return
  for client in server.clients:
    close(client.fd)
  server.clients.setLen(0)
  if server.listener != osInvalidSocket:
    close(server.listener)
    server.listener = osInvalidSocket
  if server.path.len > 0 and fileExists(server.path):
    removeFile(server.path)
  server.path = ""
  server.initialized = false

proc descriptor*(server: IpcServer): cint = cint(server.listener)

proc service*(server: var IpcServer, invalidationFd: cint): bool =
  ## Services ready IPC descriptors and returns whether the invalidation fd is ready.
  serviceWaiters(server)
  var descriptors = newSeq[TPollfd](1 + server.clients.len)
  descriptors[0] = TPollfd(fd: cint(server.listener), events: POLLIN, revents: 0)
  for index, client in server.clients:
    descriptors[index + 1] = TPollfd(
      fd: cint(client.fd),
      events: (if client.output.len > client.outputOffset: POLLOUT else: POLLIN),
      revents: 0)
  var watched = descriptors
  if invalidationFd >= 0:
    watched = newSeq[TPollfd](descriptors.len + 1)
    watched[0] = TPollfd(fd: invalidationFd, events: POLLIN, revents: 0)
    for index, descriptor in descriptors:
      watched[index + 1] = descriptor
  let count = poll(addr watched[0], watched.len.Tnfds, 250)
  if count <= 0:
    return false
  var offset = if invalidationFd >= 0: 1 else: 0
  result = invalidationFd >= 0 and watched[0].revents != 0
  let polledClients = server.clients.len
  if watched[offset].revents != 0:
    let accepted = accept(server.listener)
    if accepted[0] != osInvalidSocket:
      if server.clients.len >= MaxClients:
        close(accepted[0])
      else:
        setBlocking(accepted[0], false)
        server.clients.add(IpcClient(fd: accepted[0], input: "", output: "",
          outputOffset: 0, closing: false))
  offset.inc
  var index = polledClients - 1
  while index >= 0:
    if index >= server.clients.len:
      dec index
      continue
    let event = watched[offset + index].revents
    var remove = (event and (POLLERR or POLLHUP or POLLNVAL)) != 0
    if not remove and (event and POLLIN) != 0:
      var buffer = newString(4096)
      let readCount = posix.read(cint(server.clients[index].fd), addr buffer[0], buffer.len)
      if readCount < 0 and not retryableSocketError():
        remove = true
      elif readCount == 0:
        remove = true
      elif readCount > 0:
        buffer.setLen(readCount)
        server.clients[index].input.add(buffer)
        discard processInput(server, server.clients[index])
    if not remove and (event and POLLOUT) != 0 and
        server.clients[index].outputOffset < server.clients[index].output.len:
      let remaining = server.clients[index].output.len - server.clients[index].outputOffset
      let wrote = posix.write(cint(server.clients[index].fd),
        unsafeAddr server.clients[index].output[server.clients[index].outputOffset], remaining)
      if wrote < 0 and not retryableSocketError():
        remove = true
      elif wrote > 0:
        server.clients[index].outputOffset += wrote
    if not remove and server.clients[index].closing and
        server.clients[index].outputOffset >= server.clients[index].output.len:
      remove = true
    if remove:
      server.closeClient(index)
    dec index
