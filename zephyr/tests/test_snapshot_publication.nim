import std/os
import std/options
import std/unittest

import ../wm/snapshot_publication
import ../wm/window_query

suite "snapshot publication":
  test "serializes canonical snapshot with trailing newline":
    let snapshot = WmSnapshot(
      focused: some("0x01234567"),
      currentGroup: 4,
      clients: @[
        WmClientState(winid: "0x01234567", group: 4, mapped: true),
        WmClientState(winid: "0x89abcdef", group: NullGroup, mapped: false)
      ]
    )
    check serializeWmSnapshot(snapshot) ==
      "SNAPSHOT 1\n" &
      "FOCUSED 0x01234567\n" &
      "CURRENT 4\n" &
      "CLIENT 0x01234567 4 1\n" &
      "CLIENT 0x89abcdef 4294967295 0\n"

  test "publishes atomically and creates the wm directory":
    let root = getTempDir() / ("cirrus-snapshot-" & $getCurrentProcessId())
    if dirExists(root):
      removeDir(root)
    putEnv("WME", root)
    let snapshot = WmSnapshot(
      focused: none(string),
      currentGroup: NullGroup,
      clients: @[]
    )
    check publishWmSnapshot(snapshot)
    check readFile(root / "wm" / "snapshot") ==
      "SNAPSHOT 1\nFOCUSED NONE\nCURRENT 4294967295\n"
    check not fileExists(root / "wm" / (".snapshot." & $getCurrentProcessId()))
    removeDir(root / "wm")
    removeDir(root)
    delEnv("WME")

  test "invalid WME does not publish":
    putEnv("WME", "relative-wme")
    check not publishWmSnapshot(WmSnapshot(currentGroup: NullGroup))
    delEnv("WME")

  test "publication failure retains the previous file":
    let root = getTempDir() / ("cirrus-snapshot-failure-" & $getCurrentProcessId())
    if dirExists(root):
      removeDir(root)
    putEnv("WME", root)
    let oldSnapshot = WmSnapshot(currentGroup: NullGroup)
    check publishWmSnapshot(oldSnapshot)
    let finalPath = root / "wm" / "snapshot"
    let oldText = readFile(finalPath)
    setFilePermissions(root / "wm", {fpUserRead, fpUserExec})
    check not publishWmSnapshot(WmSnapshot(
      focused: some("0x00000001"),
      currentGroup: 1,
      clients: @[WmClientState(winid: "0x00000001", group: 1, mapped: true)]
    ))
    setFilePermissions(root / "wm", {fpUserRead, fpUserWrite, fpUserExec})
    check readFile(finalPath) == oldText
    removeDir(root / "wm")
    removeDir(root)
    delEnv("WME")
