import std/os
import std/options
import std/unittest

import ../wm/state_reconciliation
import ../wm/window_query

proc makeRoot(name: string): string =
  result = getTempDir() / (name & "-" & $getCurrentProcessId())
  if dirExists(result):
    removeDir(result)
  createDir(result)
  putEnv("GROUP", result / "group")
  putEnv("HIDDEN", result / "hidden")
  createDir(result / "group")
  createDir(result / "group:focus")
  createDir(result / "hidden")
  let bin = result / "bin"
  createDir(bin)
  writeFile(bin / "sirocco", "#!/bin/sh\n[ \"$1 $2\" = \"group count\" ] && echo '10' || exit 1\n")
  setFilePermissions(bin / "sirocco", {fpUserExec, fpUserRead, fpUserWrite})
  putEnv("PATH", bin & ":" & getEnv("PATH"))

proc cleanRoot(root: string) =
  delEnv("GROUP")
  delEnv("HIDDEN")
  removeDir(root)

proc client(winid: string, group: uint32, mapped: bool): WmClientState =
  WmClientState(winid: winid, group: group, mapped: mapped)

suite "state reconciliation":
  test "raw group zero is mirrored without translation":
    let root = makeRoot("cirrus-void")
    let winid = "0x00000000"
    createDir(root / "group" / "current" / "1")
    let snapshot = WmSnapshot(
      focused: some(winid), currentGroup: 0,
      clients: @[client(winid, 0, true)]
    )
    check reconcileSnapshot(snapshot)
    check dirExists(root / "group" / "0" / winid)
    check dirExists(root / "group" / "current" / "0")
    check not dirExists(root / "group" / "1" / winid)
    cleanRoot(root)

  test "mapped membership is created before stale membership is removed":
    let root = makeRoot("cirrus-reconcile")
    let winid = "0x00000001"
    createDir(root / "group" / "2" / winid)
    createDir(root / "group:focus" / "2" / winid)
    createDir(root / "group" / "current" / "1")
    createDir(root / "group" / "last" / "1")
    createDir(root / "group:deactivated" / "2")
    let snapshot = WmSnapshot(
      focused: some(winid), currentGroup: 5,
      clients: @[client(winid, 5, true)]
    )
    check reconcileSnapshot(snapshot)
    check dirExists(root / "group" / "5" / winid)
    check not dirExists(root / "group" / "2" / winid)
    check not dirExists(root / "group:focus" / "2" / winid)
    check not dirExists(root / "group:focus" / "5" / winid)
    check dirExists(root / "group" / "current" / "5")
    check not dirExists(root / "group" / "current" / "1")
    check dirExists(root / "group" / "last" / "1")
    check dirExists(root / "group:deactivated" / "2")
    check reconcileSnapshot(snapshot)
    cleanRoot(root)

  test "NULL_GROUP removes valid memberships without creating a sentinel":
    let root = makeRoot("cirrus-null")
    let winid = "0x00000002"
    createDir(root / "group" / "2" / winid)
    createDir(root / "group:focus" / "2" / winid)
    createDir(root / "group" / "5" / winid)
    let snapshot = WmSnapshot(
      focused: some(winid), currentGroup: NullGroup,
      clients: @[client(winid, NullGroup, true)]
    )
    check reconcileSnapshot(snapshot)
    check not dirExists(root / "group" / "2" / winid)
    check not dirExists(root / "group" / "5" / winid)
    check not dirExists(root / "group:focus" / "2" / winid)
    check not dirExists(root / "group" / $NullGroup / winid)
    cleanRoot(root)

  test "unmapped managed and hidden clients are retained":
    let root = makeRoot("cirrus-hidden")
    let winid = "0x00000003"
    createDir(root / "group" / "2" / winid)
    createDir(root / "hidden" / winid)
    let snapshot = WmSnapshot(
      focused: none(string), currentGroup: NullGroup,
      clients: @[client(winid, 2, false)]
    )
    check reconcileSnapshot(snapshot)
    check dirExists(root / "group" / "2" / winid)
    check dirExists(root / "hidden" / winid)
    cleanRoot(root)

  test "destroyed clients lose membership and hidden metadata":
    let root = makeRoot("cirrus-destroy")
    let winid = "0x00000004"
    createDir(root / "group" / "2" / winid)
    createDir(root / "group:focus" / "2" / winid)
    createDir(root / "hidden" / winid)
    let snapshot = WmSnapshot(
      focused: none(string), currentGroup: NullGroup, clients: @[]
    )
    check reconcileSnapshot(snapshot)
    check not dirExists(root / "group" / "2" / winid)
    check not dirExists(root / "group:focus" / "2" / winid)
    check not dirExists(root / "hidden" / winid)
    cleanRoot(root)

  test "destination failure preserves stale membership and can retry":
    let root = makeRoot("cirrus-retry")
    let winid = "0x00000005"
    createDir(root / "group" / "2" / winid)
    writeFile(root / "group" / "5", "block")
    let snapshot = WmSnapshot(
      focused: some(winid), currentGroup: 5,
      clients: @[client(winid, 5, true)]
    )
    check not reconcileSnapshot(snapshot)
    check dirExists(root / "group" / "2" / winid)
    removeFile(root / "group" / "5")
    check reconcileSnapshot(snapshot)
    check dirExists(root / "group" / "5" / winid)
    check not dirExists(root / "group" / "2" / winid)
    cleanRoot(root)

  test "current follows coherent focused membership without touching history":
    let root = makeRoot("cirrus-current")
    let winid = "0x00000006"
    createDir(root / "group" / "3" / winid)
    createDir(root / "group" / "current" / "2")
    createDir(root / "group" / "last" / "1")
    let snapshot = WmSnapshot(
      focused: some(winid), currentGroup: 3,
      clients: @[client(winid, 3, true)]
    )
    check reconcileSnapshot(snapshot)
    check dirExists(root / "group" / "current" / "3")
    check not dirExists(root / "group" / "current" / "2")
    check dirExists(root / "group" / "last" / "1")
    cleanRoot(root)

  test "current is not changed for an incoherent membership":
    let root = makeRoot("cirrus-current-mismatch")
    let winid = "0x00000007"
    createDir(root / "group" / "2" / winid)
    createDir(root / "group" / "current" / "2")
    let snapshot = WmSnapshot(
      focused: some(winid), currentGroup: 3,
      clients: @[client(winid, 3, false)]
    )
    check reconcileSnapshot(snapshot)
    check dirExists(root / "group" / "current" / "2")
    check not dirExists(root / "group" / "current" / "3")
    cleanRoot(root)

  test "NULL_GROUP focused state does not change current":
    let root = makeRoot("cirrus-current-null")
    let winid = "0x00000008"
    createDir(root / "group" / "2" / winid)
    createDir(root / "group" / "current" / "2")
    let snapshot = WmSnapshot(
      focused: some(winid), currentGroup: NullGroup,
      clients: @[client(winid, NullGroup, true)]
    )
    check reconcileSnapshot(snapshot)
    check dirExists(root / "group" / "current" / "2")
    cleanRoot(root)

  test "current replacement failure retains state and retries":
    let root = makeRoot("cirrus-current-retry")
    let winid = "0x00000009"
    createDir(root / "group" / "3" / winid)
    createDir(root / "group" / "current" / "2")
    let temporary = root / "group" / (".current." & $getCurrentProcessId())
    writeFile(temporary, "block")
    let snapshot = WmSnapshot(
      focused: some(winid), currentGroup: 3,
      clients: @[client(winid, 3, true)]
    )
    check not reconcileSnapshot(snapshot)
    check dirExists(root / "group" / "current" / "2")
    check reconcileSnapshot(snapshot)
    check dirExists(root / "group" / "current" / "3")
    cleanRoot(root)
