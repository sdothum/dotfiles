import std/os
import std/nativesockets
import std/posix
import std/strutils

import daemon_ipc

export daemon_ipc

const MaxResponseSize = MaxFrameSize

type DaemonReply* = object
  ok*: bool
  code*: uint8
  body*: string
  error*: string

type DaemonClientRecord* = object
  winid*: string
  group*: uint32
  mapped*: bool
  token*: string

proc socketPath(): string =
  let runtime = getEnv("XDG_RUNTIME_DIR")
  if runtime.len > 0:
      return runtime / "zephyr" / "zephyrd.sock"
  let wme = getEnv("WME")
  if wme.len > 0: wme / "zephyrd.sock" else: ""

proc writeAll(fd: SocketHandle, data: string): bool =
  var offset = 0
  while offset < data.len:
    let count = posix.write(cint(fd), unsafeAddr data[offset], data.len - offset)
    if count <= 0: return false
    offset += count
  true

proc readAll(fd: SocketHandle, destination: var string, size: int): bool =
  destination = newString(size)
  var offset = 0
  while offset < size:
    let count = posix.read(cint(fd), addr destination[offset], size - offset)
    if count <= 0: return false
    offset += count
  true

proc framePayload(version: uint16, kind: uint8, argument: string): string =
  let hasArgument = kind == RequestQueryClientState or kind == RequestQueryClientClass
  let payloadSize = 3 + (if hasArgument: 2 + argument.len else: 0)
  result = newString(4 + payloadSize)
  result[0] = char((uint32(payloadSize) shr 24) and 0xff)
  result[1] = char((uint32(payloadSize) shr 16) and 0xff)
  result[2] = char((uint32(payloadSize) shr 8) and 0xff)
  result[3] = char(uint32(payloadSize) and 0xff)
  result[4] = char((version shr 8) and 0xff)
  result[5] = char(version and 0xff)
  result[6] = char(kind)
  if hasArgument:
    result[7] = char((uint16(argument.len) shr 8) and 0xff)
    result[8] = char(uint16(argument.len) and 0xff)
    for index, value in argument:
      result[9 + index] = value

proc waitFrame(kind: uint8, pattern: string, timeoutMs: uint32): string =
  let payloadSize = 3 + 2 + pattern.len + 4
  result = newString(4 + payloadSize)
  result[0] = char((uint32(payloadSize) shr 24) and 0xff)
  result[1] = char((uint32(payloadSize) shr 16) and 0xff)
  result[2] = char((uint32(payloadSize) shr 8) and 0xff)
  result[3] = char(uint32(payloadSize) and 0xff)
  result[4] = char((ProtocolVersion shr 8) and 0xff)
  result[5] = char(ProtocolVersion and 0xff)
  result[6] = char(kind)
  result[7] = char((uint16(pattern.len) shr 8) and 0xff)
  result[8] = char(uint16(pattern.len) and 0xff)
  for index, value in pattern:
    result[9 + index] = value
  let offset = 9 + pattern.len
  result[offset] = char((timeoutMs shr 24) and 0xff)
  result[offset + 1] = char((timeoutMs shr 16) and 0xff)
  result[offset + 2] = char((timeoutMs shr 8) and 0xff)
  result[offset + 3] = char(timeoutMs and 0xff)

proc filteredFrame(kind: uint8, includeAll: bool, pattern: string): string =
  let payloadSize = 3 + 1 + 2 + pattern.len
  result = newString(4 + payloadSize)
  result[0] = char((uint32(payloadSize) shr 24) and 0xff)
  result[1] = char((uint32(payloadSize) shr 16) and 0xff)
  result[2] = char((uint32(payloadSize) shr 8) and 0xff)
  result[3] = char(uint32(payloadSize) and 0xff)
  result[4] = char((ProtocolVersion shr 8) and 0xff)
  result[5] = char(ProtocolVersion and 0xff)
  result[6] = char(kind)
  result[7] = if includeAll: char(1) else: char(0)
  result[8] = char((uint16(pattern.len) shr 8) and 0xff)
  result[9] = char(uint16(pattern.len) and 0xff)
  for index, value in pattern:
    result[10 + index] = value

proc queryDaemon*(kind: uint8, argument = ""): DaemonReply =
  let path = socketPath()
  if path.len == 0:
    return DaemonReply(error: "zephyrd socket path is unavailable")
  let fd = createNativeSocket(AF_UNIX, SOCK_STREAM, 0)
  if fd == osInvalidSocket:
    return DaemonReply(error: "unable to create zephyrd socket")
  defer: close(fd)
  var address = makeUnixAddr(path)
  if connect(fd, cast[ptr SockAddr](addr address), sizeof(address).SockLen) != 0:
    return DaemonReply(error: "zephyrd is unavailable")
  let request = framePayload(ProtocolVersion, kind, argument)
  if not writeAll(fd, request):
    return DaemonReply(error: "zephyrd request failed")
  var header: string
  if not readAll(fd, header, 4):
    return DaemonReply(error: "truncated zephyrd response")
  let size = (uint32(ord(header[0])) shl 24) or (uint32(ord(header[1])) shl 16) or
    (uint32(ord(header[2])) shl 8) or uint32(ord(header[3]))
  if size == 0 or size > MaxResponseSize:
    return DaemonReply(error: "invalid zephyrd response size")
  var payload: string
  if not readAll(fd, payload, int(size)) or payload.len < 4:
    return DaemonReply(error: "truncated zephyrd response")
  let responseVersion = (uint16(ord(payload[0])) shl 8) or uint16(ord(payload[1]))
  if responseVersion != ProtocolVersion:
    return DaemonReply(error: "unsupported zephyrd response version")
  let status = uint8(ord(payload[2]))
  if status == 0:
    result.ok = true
    if payload.len > 4:
      result.body = payload[4 .. ^1]
  else:
    result.code = uint8(ord(payload[3]))
    if payload.len > 4:
      result.error = payload[4 .. ^1]

proc queryDaemonFiltered*(kind: uint8, includeAll: bool,
    pattern: string): DaemonReply =
  let path = socketPath()
  if path.len == 0: return DaemonReply(error: "zephyrd socket path is unavailable")
  let fd = createNativeSocket(AF_UNIX, SOCK_STREAM, 0)
  if fd == osInvalidSocket: return DaemonReply(error: "unable to create zephyrd socket")
  defer: close(fd)
  var address = makeUnixAddr(path)
  if connect(fd, cast[ptr SockAddr](addr address), sizeof(address).SockLen) != 0:
    return DaemonReply(error: "zephyrd is unavailable")
  if not writeAll(fd, filteredFrame(kind, includeAll, pattern)):
    return DaemonReply(error: "zephyrd request failed")
  var header: string
  if not readAll(fd, header, 4): return DaemonReply(error: "truncated zephyrd response")
  let size = (uint32(ord(header[0])) shl 24) or (uint32(ord(header[1])) shl 16) or
    (uint32(ord(header[2])) shl 8) or uint32(ord(header[3]))
  if size == 0 or size > MaxResponseSize: return DaemonReply(error: "invalid zephyrd response size")
  var payload: string
  if not readAll(fd, payload, int(size)) or payload.len < 4:
    return DaemonReply(error: "truncated zephyrd response")
  if ((uint16(ord(payload[0])) shl 8) or uint16(ord(payload[1]))) != ProtocolVersion:
    return DaemonReply(error: "unsupported zephyrd response version")
  if payload[2].ord == 0:
    result.ok = true
    if payload.len > 4: result.body = payload[4 .. ^1]
  else:
    result.code = uint8(ord(payload[3]))
    if payload.len > 4: result.error = payload[4 .. ^1]

proc waitForClass*(pattern: string, timeoutMs = 5000'u32): DaemonReply =
  let path = socketPath()
  if path.len == 0:
    return DaemonReply(error: "zephyrd socket path is unavailable")
  let fd = createNativeSocket(AF_UNIX, SOCK_STREAM, 0)
  if fd == osInvalidSocket:
    return DaemonReply(error: "unable to create zephyrd socket")
  defer: close(fd)
  var address = makeUnixAddr(path)
  if connect(fd, cast[ptr SockAddr](addr address), sizeof(address).SockLen) != 0:
    return DaemonReply(error: "zephyrd is unavailable")
  if not writeAll(fd, waitFrame(RequestWaitClass, pattern, timeoutMs)):
    return DaemonReply(error: "zephyrd request failed")
  var header: string
  if not readAll(fd, header, 4):
    return DaemonReply(error: "truncated zephyrd response")
  let size = (uint32(ord(header[0])) shl 24) or (uint32(ord(header[1])) shl 16) or
    (uint32(ord(header[2])) shl 8) or uint32(ord(header[3]))
  if size == 0 or size > MaxResponseSize:
    return DaemonReply(error: "invalid zephyrd response size")
  var payload: string
  if not readAll(fd, payload, int(size)) or payload.len < 4:
    return DaemonReply(error: "truncated zephyrd response")
  let responseVersion = (uint16(ord(payload[0])) shl 8) or uint16(ord(payload[1]))
  if responseVersion != ProtocolVersion:
    return DaemonReply(error: "unsupported zephyrd response version")
  let status = uint8(ord(payload[2]))
  if status == 0:
    result.ok = true
    if payload.len > 4:
      result.body = payload[4 .. ^1]
  else:
    result.code = uint8(ord(payload[3]))
    if payload.len > 4:
      result.error = payload[4 .. ^1]

proc waitForName*(pattern: string, timeoutMs = 5000'u32): DaemonReply =
  let path = socketPath()
  if path.len == 0:
    return DaemonReply(error: "zephyrd socket path is unavailable")
  let fd = createNativeSocket(AF_UNIX, SOCK_STREAM, 0)
  if fd == osInvalidSocket:
    return DaemonReply(error: "unable to create zephyrd socket")
  defer: close(fd)
  var address = makeUnixAddr(path)
  if connect(fd, cast[ptr SockAddr](addr address), sizeof(address).SockLen) != 0:
    return DaemonReply(error: "zephyrd is unavailable")
  if not writeAll(fd, waitFrame(RequestWaitName, pattern, timeoutMs)):
    return DaemonReply(error: "zephyrd request failed")
  var header: string
  if not readAll(fd, header, 4):
    return DaemonReply(error: "truncated zephyrd response")
  let size = (uint32(ord(header[0])) shl 24) or (uint32(ord(header[1])) shl 16) or
    (uint32(ord(header[2])) shl 8) or uint32(ord(header[3]))
  if size == 0 or size > MaxResponseSize:
    return DaemonReply(error: "invalid zephyrd response size")
  var payload: string
  if not readAll(fd, payload, int(size)) or payload.len < 4:
    return DaemonReply(error: "truncated zephyrd response")
  let responseVersion = (uint16(ord(payload[0])) shl 8) or uint16(ord(payload[1]))
  if responseVersion != ProtocolVersion:
    return DaemonReply(error: "unsupported zephyrd response version")
  let status = uint8(ord(payload[2]))
  if status == 0:
    result.ok = true
    if payload.len > 4:
      result.body = payload[4 .. ^1]
  else:
    result.code = uint8(ord(payload[3]))
    if payload.len > 4:
      result.error = payload[4 .. ^1]

proc queryDaemonClientList*(): tuple[ok: bool, clients: seq[DaemonClientRecord],
    error: string] =
  let reply = queryDaemon(RequestQueryClientList)
  if not reply.ok:
    return (false, @[], reply.error)
  for line in reply.body.splitLines():
    if line.len == 0:
      continue
    let fields = line.splitWhitespace()
    if fields.len != 4 and fields.len != 5:
      return (false, @[], "malformed zephyrd client-list response")
    if fields[0] != "CLIENT":
      return (false, @[], "malformed zephyrd client-list response")
    if fields[1].len != 10 or fields[1][0 .. 1] != "0x":
      return (false, @[], "malformed zephyrd client-list response")
    let group = try:
      let value = parseUInt(fields[2])
      if value > uint64(high(uint32)):
        return (false, @[], "malformed zephyrd client-list response")
      value.uint32
    except ValueError:
      return (false, @[], "malformed zephyrd client-list response")
    if fields[3] != "0" and fields[3] != "1":
      return (false, @[], "malformed zephyrd client-list response")
    result.clients.add(DaemonClientRecord(
      winid: fields[1].toLowerAscii(),
      group: group,
      mapped: fields[3] == "1",
      token: if fields.len == 5: fields[4] else: ""
    ))
  result.ok = true

proc queryDaemonClientClass*(winid: string): DaemonReply =
  queryDaemon(RequestQueryClientClass, winid)
