import std/options
import std/sequtils
import std/unittest

import ../wm/snapshot_diff
import ../wm/window_query

proc snapshot(
  focused: Option[string],
  current: uint32,
  clients: seq[WmClientState]
): WmSnapshot =
  WmSnapshot(focused: focused, currentGroup: current, clients: clients)

proc client(winid: string, group: uint32, mapped: bool): WmClientState =
  WmClientState(winid: winid, group: group, mapped: mapped)

suite "snapshot diff":
  let a = snapshot(
    some("0x00000001"), 2,
    @[client("0x00000001", 2, true), client("0x00000002", 4, false)]
  )

  test "identical snapshots and reordered clients are equal":
    let b = snapshot(
      some("0x00000001"), 2,
      @[client("0x00000002", 4, false), client("0x00000001", 2, true)]
    )
    check diffSnapshots(a, b).len == 0

  test "focus and current changes":
    let b = snapshot(
      some("0x00000002"), 4,
      @[client("0x00000001", 2, true), client("0x00000002", 4, false)]
    )
    let changes = diffSnapshots(a, b)
    check changes.len == 2
    check changes[0].kind == FocusChanged
    check changes[1].kind == CurrentChanged

  test "add, remove, group, mapped, and null changes are deterministic":
    let b = snapshot(
      none(string), NullGroup,
      @[client("0x00000001", NullGroup, false), client("0x00000003", 3, true)]
    )
    let reports = diffSnapshots(a, b).mapIt(it.report())
    check reports == @[
      "FOCUS_CHANGED 0x00000001 NONE",
      "CURRENT_CHANGED 2 4294967295",
      "CLIENT_REMOVED 0x00000002 4 0",
      "CLIENT_ADDED 0x00000003 3 1",
      "GROUP_CHANGED 0x00000001 2 4294967295",
      "MAPPED_CHANGED 0x00000001 1 0",
      "NULLGROUP_CHANGED 0 1"
    ]
