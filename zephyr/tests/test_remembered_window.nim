import std/os
import std/options
import std/unittest

import ../wm/group

proc testRoot(): string =
  result = getTempDir() / ("zephyr-remembered-" & $getCurrentProcessId())
  if dirExists(result):
    removeDir(result)
  createDir(result)

suite "remembered window lookup":
  test "missing directory and empty directory mean no child":
    let root = testRoot()
    check singleChildName(root / "missing").isNone
    createDir(root / "empty")
    check singleChildName(root / "empty").isNone
    removeDir(root)

  test "single child is returned as a nonempty option":
    let root = testRoot()
    createDir(root / "windows")
    createDir(root / "windows" / "0x0123abcd")
    writeFile(root / "windows" / "ignored-file", "not a window directory")
    let child = singleChildName(root / "windows")
    check child.isSome
    check child.get == "0x0123abcd"
    check child.get.len > 0
    removeDir(root)

  test "multiple child directories retain first-child behavior":
    let root = testRoot()
    createDir(root / "windows")
    createDir(root / "windows" / "0x00000001")
    createDir(root / "windows" / "0x00000002")
    let child = singleChildName(root / "windows")
    check child.isSome
    check child.get in ["0x00000001", "0x00000002"]
    check child.get.len > 0
    removeDir(root)
