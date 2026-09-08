import std/os
import std/nativesockets
import std/posix
import std/unittest
import std/strutils

import ../wm/daemon_ipc

proc readBe32(value: string): uint32 =
  (uint32(ord(value[0])) shl 24) or
  (uint32(ord(value[1])) shl 16) or
  (uint32(ord(value[2])) shl 8) or
  uint32(ord(value[3]))

proc readResponse(fd: SocketHandle): string =
  var bytes = newString(4096)
  let count = posix.read(cint(fd), addr bytes[0], bytes.len)
  if count > 0:
    bytes.setLen(count)
  else:
    bytes.setLen(0)
  bytes

proc queryFrame(kind: uint8, argument = ""): string =
  let hasArgument = kind == RequestQueryClientState or kind == RequestQueryClientClass
  let payloadLen = 3 + (if hasArgument: 2 + argument.len else: 0)
  result = newString(4 + payloadLen)
  result[0] = char((uint32(payloadLen) shr 24) and 0xff)
  result[1] = char((uint32(payloadLen) shr 16) and 0xff)
  result[2] = char((uint32(payloadLen) shr 8) and 0xff)
  result[3] = char(uint32(payloadLen) and 0xff)
  result[4] = char(0)
  result[5] = char(1)
  result[6] = char(kind)
  if hasArgument:
    result[7] = char((uint16(argument.len) shr 8) and 0xff)
    result[8] = char(uint16(argument.len) and 0xff)
    for index, value in argument:
      result[9 + index] = value

proc waitFrame(kind: uint8, pattern: string, timeoutMs = 5000'u32): string =
  let payloadLen = 3 + 2 + pattern.len + 4
  result = newString(4 + payloadLen)
  result[0] = char((uint32(payloadLen) shr 24) and 0xff)
  result[1] = char((uint32(payloadLen) shr 16) and 0xff)
  result[2] = char((uint32(payloadLen) shr 8) and 0xff)
  result[3] = char(uint32(payloadLen) and 0xff)
  result[4] = char(0); result[5] = char(1); result[6] = char(kind)
  result[7] = char((uint16(pattern.len) shr 8) and 0xff)
  result[8] = char(uint16(pattern.len) and 0xff)
  for index, value in pattern: result[9 + index] = value
  let offset = 9 + pattern.len
  result[offset] = char((timeoutMs shr 24) and 0xff)
  result[offset + 1] = char((timeoutMs shr 16) and 0xff)
  result[offset + 2] = char((timeoutMs shr 8) and 0xff)
  result[offset + 3] = char(timeoutMs and 0xff)

proc connectAndService(server: var IpcServer, path: string, request: string): string =
  let fd = createNativeSocket(AF_UNIX, SOCK_STREAM, 0)
  doAssert fd != osInvalidSocket
  defer: close(fd)
  var address = makeUnixAddr(path)
  doAssert connect(fd, cast[ptr SockAddr](addr address), sizeof(address).SockLen) == 0
  doAssert posix.write(cint(fd), unsafeAddr request[0], request.len) == request.len
  discard server.service(-1) # accept
  discard server.service(-1) # read and decode
  discard server.service(-1) # write response
  readResponse(fd)

suite "zephyrd IPC transport":
  test "PING returns framed PONG and socket is private":
    let root = getTempDir() / ("zephyrd-ipc-" & $getCurrentProcessId())
    createDir(root)
    let path = root / "zephyrd.sock"
    var server: IpcServer
    check server.open(path)
    defer:
      server.close()
      if dirExists(root): removeDir(root)
    check getFilePermissions(path) == {fpUserRead, fpUserWrite}
    let response = connectAndService(server, path, pingFrame())
    check response.len == 8
    check readBe32(response[0 .. 3]) == 4
    check response[4].ord == 0
    check response[5].ord == 1
    check response[6].ord == 0
    check response[7].ord == 1

  test "unsupported version is an error and server remains usable":
    let root = getTempDir() / ("zephyrd-ipc-version-" & $getCurrentProcessId())
    createDir(root)
    let path = root / "zephyrd.sock"
    var server: IpcServer
    check server.open(path)
    defer:
      server.close()
      if dirExists(root): removeDir(root)
    var request = pingFrame()
    request[4] = char(0)
    request[5] = char(2)
    let errorResponse = connectAndService(server, path, request)
    check errorResponse.len > 8
    check errorResponse[4].ord == 0
    check errorResponse[5].ord == 2
    check errorResponse[6].ord == 1
    check errorResponse[7].ord == 1
    let pong = connectAndService(server, path, pingFrame())
    check pong[5].ord == 1

  test "unknown request and oversized frame are isolated":
    let root = getTempDir() / ("zephyrd-ipc-errors-" & $getCurrentProcessId())
    createDir(root)
    let path = root / "zephyrd.sock"
    var server: IpcServer
    check server.open(path)
    defer:
      server.close()
      if dirExists(root): removeDir(root)
    var unknown = pingFrame()
    unknown[6] = char(99)
    let unknownResponse = connectAndService(server, path, unknown)
    check unknownResponse[6].ord == 1
    check unknownResponse[7].ord == 2
    var oversized = newString(4)
    oversized[0] = char(0)
    oversized[1] = char(1)
    oversized[2] = char(0)
    oversized[3] = char(1)
    let oversizedResponse = connectAndService(server, path, oversized)
    check oversizedResponse[6].ord == 1
    check oversizedResponse[7].ord == 4
    var malformed = newString(6)
    malformed[3] = char(2)
    malformed[4] = char(0)
    malformed[5] = char(1)
    let malformedResponse = connectAndService(server, path, malformed)
    check malformedResponse[6].ord == 1
    check malformedResponse[7].ord == 3
    check connectAndService(server, path, pingFrame())[5].ord == 1

  test "partial frame and client disconnect do not stall the server":
    let root = getTempDir() / ("zephyrd-ipc-partial-" & $getCurrentProcessId())
    createDir(root)
    let path = root / "zephyrd.sock"
    var server: IpcServer
    check server.open(path)
    defer:
      server.close()
      if dirExists(root): removeDir(root)
    let fd = createNativeSocket(AF_UNIX, SOCK_STREAM, 0)
    var address = makeUnixAddr(path)
    check connect(fd, cast[ptr SockAddr](addr address), sizeof(address).SockLen) == 0
    let request = pingFrame()
    check posix.write(cint(fd), unsafeAddr request[0], 2) == 2
    discard server.service(-1) # accept
    discard server.service(-1) # retain partial header
    check posix.write(cint(fd), unsafeAddr request[2], request.len - 2) == request.len - 2
    discard server.service(-1) # decode
    discard server.service(-1) # respond
    check readResponse(fd)[5].ord == 1
    close(fd)
    discard server.service(-1) # observe disconnect
    check connectAndService(server, path, pingFrame())[5].ord == 1

  test "stale regular path is replaced":
    let root = getTempDir() / ("zephyrd-ipc-stale-" & $getCurrentProcessId())
    createDir(root)
    let path = root / "zephyrd.sock"
    writeFile(path, "stale")
    var server: IpcServer
    check server.open(path)
    server.close()
    if dirExists(root): removeDir(root)

  test "cached queries return typed snapshot state and NOT_READY":
    let root = getTempDir() / ("zephyrd-ipc-cache-" & $getCurrentProcessId())
    createDir(root)
    let path = root / "zephyrd.sock"
    var server: IpcServer
    check server.open(path)
    defer:
      server.close()
      if dirExists(root): removeDir(root)
    let notReady = connectAndService(server, path, queryFrame(RequestQueryCurrentGroup))
    check notReady[6].ord == 1
    check notReady[7].ord == int(ErrorNotReady)
    let listNotReady = connectAndService(server, path, queryFrame(RequestQueryClientList))
    check listNotReady[6].ord == 1
    check listNotReady[7].ord == int(ErrorNotReady)
    server.cacheSnapshot(
      "SNAPSHOT 2\nFOCUSED 0x00000001\nCURRENT 3\nCLIENT 0x00000001 3 1 " &
        "0123456789abcdef0123456789abcdef:0000000000000001\n",
      "0x00000001", 3,
      @[DaemonCachedClient(winid: "0x00000001", group: 3, mapped: true,
        token: "0123456789abcdef0123456789abcdef:0000000000000001",
        instanceName: "xterm", className: "XTerm", metadataAvailable: true)])
    let current = connectAndService(server, path, queryFrame(RequestQueryCurrentGroup))
    check current[8 .. ^1] == "3"
    let focused = connectAndService(server, path, queryFrame(RequestQueryFocused))
    check focused[8 .. ^1] == "0x00000001"
    let snapshot = connectAndService(server, path, queryFrame(RequestQuerySnapshot))
    check snapshot[8 .. ^1].startsWith("SNAPSHOT 2\n")
    let client = connectAndService(server, path,
      queryFrame(RequestQueryClientState, "0x00000001"))
    check client[8 .. ^1].startsWith("CLIENT 0x00000001 3 1 ")
    let clients = connectAndService(server, path, queryFrame(RequestQueryClientList))
    check clients[8 .. ^1] ==
      "CLIENT 0x00000001 3 1 " &
      "0123456789abcdef0123456789abcdef:0000000000000001\n"
    let classname = connectAndService(server, path,
      queryFrame(RequestQueryClientClass, "0x00000001"))
    check classname[8 .. ^1] == "XTerm"
    server.invalidateCache()
    let invalidated = connectAndService(server, path,
      queryFrame(RequestQueryClientList))
    check invalidated[6].ord == 1
    check invalidated[7].ord == int(ErrorNotReady)
    let pingAfterInvalidation = connectAndService(server, path, pingFrame())
    check pingAfterInvalidation[6].ord == 0
    check pingAfterInvalidation[7].ord == 1

  test "name waiter matches cached and updated titles":
    let root = getTempDir() / ("zephyrd-ipc-name-" & $getCurrentProcessId())
    createDir(root)
    let path = root / "zephyrd.sock"
    var server: IpcServer
    check server.open(path)
    defer:
      server.close()
      if dirExists(root): removeDir(root)
    server.cacheSnapshot("SNAPSHOT 2\n", "", 1,
      @[DaemonCachedClient(winid: "0x00000001", group: 1, mapped: true,
        token: "t", title: "initial title", titleAvailable: true)])
    let immediate = connectAndService(server, path,
      waitFrame(RequestWaitName, "initial"))
    check immediate[6].ord == 0
    check immediate[7].ord == 9
    check immediate[8 .. ^1] == "0x00000001"

  test "name waiter keeps zero-match requests pending then times out":
    let root = "/tmp/zephyrd-ipc-name-timeout-" & $getCurrentProcessId()
    createDir(root)
    let path = root / "zephyrd.sock"
    var server: IpcServer
    check server.open(path)
    defer:
      server.close()
      if dirExists(root): removeDir(root)
    server.cacheSnapshot("SNAPSHOT 2\n", "", 1,
      @[DaemonCachedClient(winid: "0x00000001", group: 1, mapped: true,
        token: "t", title: "ordinary terminal title", titleAvailable: true)])
    let fd = createNativeSocket(AF_UNIX, SOCK_STREAM, 0)
    defer: close(fd)
    var address = makeUnixAddr(path)
    check connect(fd, cast[ptr SockAddr](addr address), sizeof(address).SockLen) == 0
    let request = waitFrame(RequestWaitName, "^D5_PROPERTY_TEST$", 1)
    check posix.write(cint(fd), unsafeAddr request[0], request.len) == request.len
    discard server.service(-1) # accept
    discard server.service(-1) # register pending waiter
    # No response is queued for a zero-match request; the short deadline then
    # deterministically produces the typed timeout response.
    sleep(10)
    discard server.service(-1)
    let response = readResponse(fd)
    check response[6].ord == 1
    check response[7].ord == int(ErrorTimeout)

    server.cacheSnapshot("SNAPSHOT 2\n", "", 1,
      @[DaemonCachedClient(winid: "0x00000001", group: 1, mapped: false,
        token: "t", title: "D5_PROPERTY_TEST", titleAvailable: true)])
    let zeroFd = createNativeSocket(AF_UNIX, SOCK_STREAM, 0)
    defer: close(zeroFd)
    var zeroAddress = makeUnixAddr(path)
    check connect(zeroFd, cast[ptr SockAddr](addr zeroAddress), sizeof(zeroAddress).SockLen) == 0
    let zeroRequest = waitFrame(RequestWaitName, "^D5_PROPERTY_TEST$", 1)
    check posix.write(cint(zeroFd), unsafeAddr zeroRequest[0], zeroRequest.len) == zeroRequest.len
    discard server.service(-1)
    discard server.service(-1)
    sleep(10)
    discard server.service(-1)
    let zeroResponse = readResponse(zeroFd)
    check zeroResponse[7].ord == int(ErrorTimeout)
