import std/options
import std/re
import std/sequtils
import std/strutils

import cliargs
import compat
import types
import x11_ipc
import daemon_client

#
# Queries
#

proc focusedWinid*(): string =
  shvArgs("sirocco", "window", @["focused"], 1, 1).strip()

proc tryWmGroup*(winid: string, group: var uint32): bool =
  let reply = queryDaemon(RequestQueryClientState, winid)
  if not reply.ok:
    return false
  let fields = reply.body.splitWhitespace()
  if fields.len < 4 or fields[0] != "CLIENT" or fields[1] != winid:
    return false

  try:
    let value = parseUInt(fields[2])
    if value > uint64(high(uint32)):
      return false
    group = value.uint32
    result = true
  except ValueError:
    return false

proc wmGroup*(winid: string): uint32 =
  if not tryWmGroup(winid, result):
    quit("window_query wm group: invalid or unavailable group for " & winid)

type WmGroupEntry* = tuple[
  winid: string,
  group: uint32
]

type ClientToken* = object
  value*: string

proc isPresent*(token: ClientToken): bool = token.value.len > 0

proc `$`*(token: ClientToken): string = token.value

proc parseClientToken*(value: string): ClientToken =
  if value.len != 49 or value[32] != ':' or
      value[0 .. 31].anyIt(it notin {'0'..'9', 'a'..'f'}) or
      value[33 .. 48].anyIt(it notin {'0'..'9', 'a'..'f'}) or
      value[33 .. 48] == "0000000000000000":
    raise newException(ValueError, "invalid client token " & value)
  result.value = value

type WmClientState* = object
  winid*: string
  group*: uint32
  mapped*: bool
  token*: ClientToken

type WmSnapshot* = object
  focused*: Option[string]
  currentGroup*: uint32
  clients*: seq[WmClientState]

const NullGroup* = high(uint32)

type StackGeometryEntry* = object
  winid*: string
  geometry*: Geometry

proc parseSnapshotUInt(value: string, field: string): uint32 =
  if value.len == 0 or value.anyIt(it notin {'0'..'9'}):
    raise newException(ValueError, "invalid " & field & " " & value)
  try:
    let parsed = parseUInt(value)
    if parsed > uint64(high(uint32)):
      raise newException(ValueError, "invalid " & field & " " & value)
    result = parsed.uint32
  except ValueError:
    raise newException(ValueError, "invalid " & field & " " & value)

proc parseSnapshotWinid(value: string): string =
  if not value.match(re(r"^0x[0-9a-fA-F]{8}$")):
    raise newException(ValueError, "invalid winid " & value)
  value.toLowerAscii()

proc parseWmSnapshotChecked*(output: string): WmSnapshot =
  var lines = output.splitLines()
  # WM replies are line-oriented and conventionally end with one newline.
  # Ignore that terminator, while retaining strict rejection of empty records
  # anywhere else in the response.
  if lines.len > 0 and lines[^1].len == 0:
    lines.setLen(lines.len - 1)
  if lines.len == 0 or (lines[0] != "SNAPSHOT 1" and lines[0] != "SNAPSHOT 2"):
    raise newException(ValueError, "invalid header")
  let version2 = lines[0] == "SNAPSHOT 2"

  var gotFocused = false
  var gotCurrent = false
  result.focused = none(string)
  for index in 1 ..< lines.len:
    let line = lines[index]
    let fields = line.split(' ')
    if fields.len == 0 or fields[0] == "":
      raise newException(ValueError, "malformed record " & line)
    case fields[0]
    of "FOCUSED":
      if gotFocused or fields.len != 2:
        raise newException(ValueError, "malformed FOCUSED record")
      gotFocused = true
      if fields[1] == "NONE":
        result.focused = none(string)
      else:
        result.focused = some(parseSnapshotWinid(fields[1]))
    of "CURRENT":
      if gotCurrent or fields.len != 2:
        raise newException(ValueError, "malformed CURRENT record")
      gotCurrent = true
      result.currentGroup = parseSnapshotUInt(fields[1], "group")
    of "CLIENT":
      if (version2 and fields.len != 5) or (not version2 and fields.len != 4):
        raise newException(ValueError, "malformed CLIENT record")
      let winid = parseSnapshotWinid(fields[1])
      for client in result.clients:
        if client.winid == winid:
          raise newException(ValueError, "duplicate winid " & winid)
      let group = parseSnapshotUInt(fields[2], "group")
      if fields[3] != "0" and fields[3] != "1":
        raise newException(ValueError, "invalid mapped flag " & fields[3])
      result.clients.add(WmClientState(
        winid: winid,
        group: group,
        mapped: fields[3] == "1",
        token: if version2: parseClientToken(fields[4]) else: ClientToken()
      ))
    else:
      raise newException(ValueError, "unknown record " & fields[0])

  if not gotFocused or not gotCurrent:
    raise newException(ValueError, "incomplete snapshot")
  if result.focused.isNone:
    if result.currentGroup != NullGroup:
      raise newException(ValueError, "current group without focus")
  else:
    let focusedWinid = result.focused.get()
    var found = false
    var focusedGroup: uint32
    for client in result.clients:
      if client.winid == focusedWinid:
        if found:
          raise newException(ValueError, "duplicate focused winid " & focusedWinid)
        found = true
        focusedGroup = client.group
    if not found:
      raise newException(ValueError, "focused winid absent from clients")
    if result.currentGroup != focusedGroup:
      raise newException(ValueError, "focused/current group mismatch")

proc parseWmSnapshot*(output: string): WmSnapshot =
  try:
    result = parseWmSnapshotChecked(output)
  except ValueError as error:
    quit("window snapshot: " & error.msg)

proc wmGroups*(): seq[WmGroupEntry] =
  let reply = queryDaemon(RequestQuerySnapshot)
  if not reply.ok:
    quit("window_query wm groups: " & reply.error)
  let snapshot = parseWmSnapshot(reply.body)
  for client in snapshot.clients:
    result.add((client.winid, client.group))

proc wmSnapshot*(): WmSnapshot =
  let reply = shvStatus("sirocco", ["window", "snapshot"])
  if reply.status != 0:
    quit("window_query wm snapshot failed: " & $reply.status)
  result = parseWmSnapshot(reply.output)

proc cachedWmSnapshot*(): WmSnapshot =
  let reply = queryDaemon(RequestQuerySnapshot)
  if not reply.ok:
    quit("window_query wm snapshot failed: " & reply.error)
  result = parseWmSnapshot(reply.body)

proc clientToken*(winid: string): ClientToken =
  let snapshot = wmSnapshot()
  for client in snapshot.clients:
    if client.winid == winid:
      return client.token
  quit("window_query client token: unknown window " & winid)

proc tryClientToken*(winid: string, token: var ClientToken): bool =
  try:
    token = clientToken(winid)
    result = token.isPresent
  except CatchableError:
    result = false

proc tryWmSnapshot*(snapshot: var WmSnapshot): bool =
  try:
    let reply = shvStatus("sirocco", ["window", "snapshot"])
    if reply.status != 0:
      return false
    snapshot = parseWmSnapshotChecked(reply.output)
    result = true
  except CatchableError:
    result = false

proc serializeWmSnapshot*(snapshot: WmSnapshot): string =
  let focused =
    if snapshot.focused.isSome: snapshot.focused.get()
    else: "NONE"
  let version2 = snapshot.clients.anyIt(it.token.value.len > 0)
  if version2 and snapshot.clients.anyIt(it.token.value.len == 0):
    raise newException(ValueError, "mixed token-bearing and tokenless snapshot")
  result = (if version2: "SNAPSHOT 2\n" else: "SNAPSHOT 1\n") & "FOCUSED " & focused & "\nCURRENT " &
    $snapshot.currentGroup & "\n"
  for client in snapshot.clients:
    result.add("CLIENT " & client.winid & " " & $client.group & " " &
      (if client.mapped: "1" else: "0") &
      (if version2: " " & $client.token else: "") & "\n")

proc classname*(winid: string): string =
  let reply = queryDaemonClientClass(winid)
  if not reply.ok:
    quit("window_query classname: " & reply.error)
  if reply.body.len == 0:
    quit("window_query classname: empty WM_CLASS")
  reply.body

var directIpc: X11Ipc

proc directConnection(): bool =
  if directIpc.isOpen:
    return true
  directIpc.open()

proc directFailure(operation: string) =
  let reason =
    if directIpc.lastFailure.len > 0: " " & directIpc.lastFailure
    else: ""
  directIpc.close()
  quit("window_query " & operation & " failed:" & reason)

proc parseGeometryBody*(output: string): Geometry =
  proc fail(error: string) =
    quit("window_query geometry: " & error)

  var
    gotX = false
    gotY = false
    gotWidth = false
    gotHeight = false

  for line in output.splitLines():
    let parts = line.split('=', maxsplit = 1)

    if parts.len != 2:
      fail("invalid window geometry " & line)

    let value = parseInt(parts[1])

    case parts[0]
    of "X":
      result.x = value
      gotX = true
    of "Y":
      result.y = value
      gotY = true
    of "WIDTH":
      result.width = value
      gotWidth = true
    of "HEIGHT":
      result.height = value
      gotHeight = true
    else:
      fail("unknown window geometry field " & parts[0])

  if not (gotX and gotY and gotWidth and gotHeight):
    fail("incomplete window geometry")

proc geometry*(winid: string = ""): Geometry =
  var id = 0'u32
  let explicit = winid != ""
  if explicit:
    let parsed = parseArguments("window geometry", @[winid], [ArgWinid]).winid
    try:
      id = parseHexInt(parsed).uint32
    except ValueError:
      quit("window_query geometry: malformed winid " & winid)

  if not directConnection():
    directFailure("geometry")
  var body: string
  if not directIpc.geometry(id, explicit, body):
    directFailure("geometry")
  parseGeometryBody(body)

proc geometry*(args: seq[string]): string =
  shvArgs("sirocco", "window", @["geometry"] & args, 1, 2)

proc stack*(winid: string = ""): seq[string] =
  let args =
    if winid.len == 0:
      @["stack"]
    else:
      @["stack", winid]

  result =
    shvArgs(
      "sirocco",
      "window",
      args,
      args.len,
      args.len
  ).splitLines()

proc parseStackGeometries*(output: string): seq[StackGeometryEntry] =
  if output.len == 0:
    return
  for line in output.splitLines():
    let fields = line.splitWhitespace()
    if fields.len != 5:
      quit("window_query stack geometries: malformed record " & line)
    let id = parseArguments("window stack-geometries", @[fields[0]], [ArgWinid]).winid
    var x, y, width, height: int
    try:
      x = parseInt(fields[1])
      y = parseInt(fields[2])
      width = parseInt(fields[3])
      height = parseInt(fields[4])
    except ValueError:
      quit("window_query stack geometries: malformed geometry " & line)
    if x < low(int16) or x > high(int16) or y < low(int16) or y > high(int16) or
        width < 0 or width > int(high(uint16)) or
        height < 0 or height > int(high(uint16)):
      quit("window_query stack geometries: invalid geometry " & line)
    for entry in result:
      if entry.winid == id:
        quit("window_query stack geometries: duplicate winid " & id)
    result.add(StackGeometryEntry(
      winid: id,
      geometry: Geometry(x: x, y: y, width: width, height: height)
    ))

proc stackGeometries*(winid: string = ""): seq[StackGeometryEntry] =
  if not directConnection():
    directFailure("stack geometries")

  var id = 0'u32
  var explicit = winid.len > 0
  if explicit:
    let parsed = parseArguments(
      "window stack-geometries",
      @[winid],
      [ArgWinid]
    ).winid
    try:
      id = parseHexInt(parsed).uint32
    except ValueError:
      quit("window_query stack geometries: malformed winid " & winid)

  var body: string
  if not directIpc.stackGeometries(id, explicit, body):
    directFailure("stack geometries")
  parseStackGeometries(body.strip())

proc applyGeometriesBody*(body: string) =
  if not directConnection():
    directFailure("apply geometries")
  if not directIpc.applyGeometries(body):
    directFailure("apply geometries")

proc applyGeometriesCheckedBody*(body: string) =
  if not directConnection():
    directFailure("apply geometries checked")
  if not directIpc.applyGeometriesChecked(body):
    directFailure("apply geometries checked")
