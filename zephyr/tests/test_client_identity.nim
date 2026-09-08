import std/options
import std/strutils
import std/unittest

import ../wm/window_query
import ../wm/snapshot_diff

const t1 = "0123456789abcdef0123456789abcdef:0000000000000001"
const t2 = "0123456789abcdef0123456789abcdef:0000000000000002"

suite "client identity":
  test "raw reserved group zero is accepted":
    let parsed = parseWmSnapshotChecked(
      "SNAPSHOT 2\nFOCUSED 0x01234567\nCURRENT 0\n" &
      "CLIENT 0x01234567 0 1 " & t1 & "\n")
    check parsed.currentGroup == 0
    check parsed.clients[0].group == 0

  test "strict token format":
    check parseClientToken(t1).value == t1
    expect ValueError:
      discard parseClientToken("0123456789abcdef0123456789abcdeF:0000000000000001")
    expect ValueError:
      discard parseClientToken("0123456789abcdef0123456789abcdef:0000000000000000")
    expect ValueError:
      discard parseClientToken("bad")

  test "snapshot v2 carries token":
    let snapshot = parseWmSnapshotChecked(
      "SNAPSHOT 2\nFOCUSED 0x01234567\nCURRENT 4\n" &
      "CLIENT 0x01234567 4 1 " & t1)
    check snapshot.clients.len == 1
    check snapshot.clients[0].token.value == t1

  test "v2 snapshot round-trips without losing identity":
    let source =
      "SNAPSHOT 2\nFOCUSED NONE\nCURRENT 4294967295\n" &
      "CLIENT 0x01234567 4294967295 0 " & t1 & "\n" &
      "CLIENT 0x89abcdef 4 1 " & t2 & "\n"
    let parsed = parseWmSnapshotChecked(source)
    check serializeWmSnapshot(parsed) == source

  test "v1 snapshot remains v1 when tokenless":
    let source =
      "SNAPSHOT 1\nFOCUSED NONE\nCURRENT 4294967295\n" &
      "CLIENT 0x01234567 4294967295 1\n"
    check serializeWmSnapshot(parseWmSnapshotChecked(source)) == source

  test "mixed token state is rejected":
    let snapshot = WmSnapshot(
      focused: none(string), currentGroup: 4,
      clients: @[
        WmClientState(winid: "0x01234567", group: 4,
          mapped: true, token: parseClientToken(t1)),
        WmClientState(winid: "0x89abcdef", group: 4,
          mapped: true, token: ClientToken(value: ""))])
    expect ValueError:
      discard serializeWmSnapshot(snapshot)

  test "same XID with new token is replacement":
    let old = WmSnapshot(
      focused: some("0x01234567"), currentGroup: 4,
      clients: @[WmClientState(winid: "0x01234567", group: 4,
        mapped: true, token: parseClientToken(t1))])
    let current = WmSnapshot(
      focused: some("0x01234567"), currentGroup: 4,
      clients: @[WmClientState(winid: "0x01234567", group: 4,
        mapped: true, token: parseClientToken(t2))])
    let changes = diffSnapshots(old, current)
    check changes.len == 2
    check changes[0].kind == ClientRemoved
    check changes[1].kind == ClientAdded

  test "multi-client v2 serialization retains every token":
    var clients: seq[WmClientState] = @[]
    for index in 1 .. 64:
      let generation = align(toHex(index, 16).toLowerAscii(), 16, '0')
      let token = parseClientToken(
        "0123456789abcdef0123456789abcdef:" & generation)
      clients.add(WmClientState(winid: "0x" & align(toHex(index, 8).toLowerAscii(), 8, '0'),
        group: 1, mapped: true, token: token))
    let parsed = parseWmSnapshotChecked(serializeWmSnapshot(WmSnapshot(
      focused: none(string), currentGroup: NullGroup, clients: clients)))
    check parsed.clients.len == clients.len
    check parsed.clients[^1].token == clients[^1].token
