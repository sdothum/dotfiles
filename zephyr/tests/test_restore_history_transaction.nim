import std/os
import std/unittest

import ../wm/state
import ../wm/types
import ../wm/window_query

let root = getTempDir() / "zephyr-restore-history-test"
let parent = root.parentDir
let marker = parent / ".restore-all.txn"
let lock = parent / ".restore-all.lock"
let stage = root & ".restore-all.stage"
let backup = root & ".restore-all.backup"

proc clearAll() =
  for path in [root, stage, backup, marker, lock]:
    if dirExists(path): removeDir(path)
    elif fileExists(path): removeFile(path)
  createDir(parent)

proc makeGeometry(base, id: string, g: Geometry) =
  let path = base / id
  createDir(path)
  createDir(path / ("X=" & $g.x))
  createDir(path / ("Y=" & $g.y))
  createDir(path / ("WIDTH=" & $g.width))
  createDir(path / ("HEIGHT=" & $g.height))

proc mark(phase: string) =
  writeFile(marker, phase & "\n" & stage & "\n" & backup & "\n0\n")
  createDir(lock)
  writeFile(lock / "pid", "0\n")

let oldA = Geometry(x: 1, y: 2, width: 30, height: 40)
let newA = Geometry(x: 10, y: 20, width: 30, height: 40)
let oldC = Geometry(x: 5, y: 6, width: 50, height: 60)
let newC = Geometry(x: 15, y: 16, width: 50, height: 60)
let tokenA = parseClientToken("0123456789abcdef0123456789abcdef:0000000000000001")
let explodeRoot = root.parentDir / "explode-state"
let explodeMarker = explodeRoot.parentDir / ".explode.txn"
let explodeLock = explodeRoot.parentDir / ".explode.lock"
let explodeStage = explodeRoot & ".stage"
let explodeBackup = explodeRoot & ".backup"
let operationMarker = explodeRoot.parentDir / ".explode-operation.txn"

putEnv("WINFO", root)

suite "restore-all history transaction recovery":
  test "interrupted first rename rolls staged generation forward":
    clearAll()
    createDir(backup)
    createDir(stage)
    makeGeometry(backup, "A", oldA)
    makeGeometry(backup, "term", oldC)
    makeGeometry(stage, "A", newA)
    makeGeometry(stage, "term", newC)
    mark("PUBLISHING")
    recoverRestoreHistory(root)
    check loadGeometry("A") == newA
    check loadGeometry("term") == newC
    check not dirExists(backup)
    check not fileExists(marker)
    check not dirExists(lock)
    recoverRestoreHistory(root)
    check loadGeometry("A") == newA

  test "interrupted second rename keeps published generation":
    clearAll()
    createDir(root)
    createDir(backup)
    makeGeometry(root, "A", newA)
    makeGeometry(backup, "A", oldA)
    mark("PUBLISHING")
    recoverRestoreHistory(root)
    check loadGeometry("A") == newA
    check not dirExists(backup)
    check not fileExists(marker)
    recoverRestoreHistory(root)
    check loadGeometry("A") == newA

  test "committed cleanup residue never restores old geometry":
    clearAll()
    createDir(root)
    createDir(backup)
    makeGeometry(root, "A", newA)
    makeGeometry(backup, "A", oldA)
    mark("COMMIT_REQUIRED")
    recoverRestoreHistory(root)
    check loadGeometry("A") == newA
    check not dirExists(backup)
    check not fileExists(marker)
    recoverRestoreHistory(root)
    check loadGeometry("A") == newA

  test "prepared transaction preserves old generation":
    clearAll()
    createDir(root)
    createDir(stage)
    makeGeometry(root, "A", oldA)
    makeGeometry(stage, "A", newA)
    mark("PREPARED")
    recoverRestoreHistory(root)
    check loadGeometry("A") == oldA
    check not dirExists(stage)
    check not fileExists(marker)
    recoverRestoreHistory(root)
    check loadGeometry("A") == oldA

  test "reader recovers missing-root handoff before reading":
    clearAll()
    createDir(backup)
    createDir(stage)
    makeGeometry(backup, "A", oldA)
    makeGeometry(stage, "A", newA)
    mark("PUBLISHING")
    check hasGeometry("A")
    check loadGeometry("A") == newA
    recoverRestoreHistory(root)
    check loadGeometry("A") == newA

  test "writer recovers then writes authoritative generation":
    clearAll()
    createDir(backup)
    createDir(stage)
    makeGeometry(backup, "A", oldA)
    makeGeometry(stage, "A", newA)
    mark("PUBLISHING")
    saveGeometry(newC, "C", false)
    check loadGeometry("A") == newA
    check loadGeometry("C") == newC
    recoverRestoreHistory(root)
    check loadGeometry("C") == newC

  test "publication preserves unrelated XID and term entries":
    clearAll()
    createDir(root)
    makeGeometry(root, "A", oldA)
    makeGeometry(root, "C", oldC)
    makeGeometry(root, "term", oldC)
    var transaction = beginRestoreHistory(@[("A", newA)])
    commitRestoreHistory(transaction)
    check loadGeometry("A") == newA
    check loadGeometry("C") == oldC
    check loadGeometry("term") == oldC
    recoverRestoreHistory(root)
    check loadGeometry("C") == oldC

  test "explode generation publishes and recovers idempotently":
    for path in [explodeRoot, explodeStage, explodeBackup, explodeMarker, explodeLock]:
      if dirExists(path): removeDir(path)
      elif fileExists(path): removeFile(path)
    createDir(explodeRoot.parentDir)
    var transaction = beginExplodeState(explodeRoot, @[
      ("0x00000001", oldA),
      ("0x00000002", oldC)
    ])
    commitExplodeState(transaction)
    check loadStateWinids(explodeRoot) == @["0x00000001", "0x00000002"]
    check loadGeometry("001=0x00000001", explodeRoot) == oldA
    recoverExplodeState(explodeRoot)
    check loadStateWinids(explodeRoot).len == 2

  test "identity-bearing explode records round-trip":
    for path in [explodeRoot, explodeStage, explodeBackup, explodeMarker, explodeLock]:
      if dirExists(path): removeDir(path)
      elif fileExists(path): removeFile(path)
    createDir(explodeRoot.parentDir)
    var transaction = beginExplodeStateIdentity(explodeRoot, @[
      ("0x00000001", tokenA, oldA)])
    commitExplodeState(transaction)
    let entries = loadStateEntries(explodeRoot)
    check entries.len == 1
    check entries[0].token == tokenA
    check entries[0].geometry == oldA

  test "tokenless explode records never become restore entries":
    for path in [explodeRoot, explodeStage, explodeBackup, explodeMarker, explodeLock]:
      if dirExists(path): removeDir(path)
      elif fileExists(path): removeFile(path)
    createDir(explodeRoot)
    makeGeometry(explodeRoot, "001=0x00000001", oldA)
    check loadStateEntries(explodeRoot).len == 0

  test "interrupted explode publication rolls forward":
    for path in [explodeRoot, explodeStage, explodeBackup, explodeMarker, explodeLock]:
      if dirExists(path): removeDir(path)
      elif fileExists(path): removeFile(path)
    createDir(explodeBackup)
    createDir(explodeStage)
    makeGeometry(explodeBackup, "001=0x00000001", oldA)
    makeGeometry(explodeStage, "001=0x00000001", newA)
    writeFile(explodeMarker, "PUBLISHING\n" & explodeStage & "\n" & explodeBackup & "\n0\n")
    createDir(explodeLock)
    writeFile(explodeLock / "pid", "0\n")
    recoverExplodeState(explodeRoot)
    check loadGeometry("001=0x00000001", explodeRoot) == newA
    recoverExplodeState(explodeRoot)
    check not fileExists(explodeMarker)

  test "shared commit intent completes WINFO after explode publication":
    clearAll()
    for path in [explodeRoot, explodeStage, explodeBackup, explodeMarker,
      explodeLock, operationMarker]:
      if dirExists(path): removeDir(path)
      elif fileExists(path): removeFile(path)
    createDir(explodeRoot)
    makeGeometry(explodeRoot, "001=0x00000001", newA)
    createDir(root & ".restore-all.stage")
    makeGeometry(root & ".restore-all.stage", "A", newA)
    writeFile(root.parentDir / ".restore-all.txn",
      "PREPARED\n" & root & ".restore-all.stage\n" & root & ".restore-all.backup\n0\n")
    writeFile(operationMarker, "COMMIT_REQUIRED\n" & explodeRoot & "\n" & root & "\n0\n")
    recoverExplodeOperation(explodeRoot)
    check loadGeometry("001=0x00000001", explodeRoot) == newA
    check loadGeometry("A") == newA
    recoverExplodeOperation(explodeRoot)
    check not fileExists(operationMarker)

  test "shared commit intent completes explode after WINFO publication":
    clearAll()
    for path in [explodeRoot, explodeStage, explodeBackup, explodeMarker,
      explodeLock, operationMarker]:
      if dirExists(path): removeDir(path)
      elif fileExists(path): removeFile(path)
    createDir(root)
    makeGeometry(root, "A", newA)
    createDir(explodeStage)
    makeGeometry(explodeStage, "001=0x00000001", newA)
    writeFile(explodeMarker,
      "PREPARED\n" & explodeStage & "\n" & explodeBackup & "\n0\n")
    createDir(explodeLock)
    writeFile(explodeLock / "pid", "0\n")
    writeFile(operationMarker,
      "COMMIT_REQUIRED\n" & explodeRoot & "\n" & root & "\n0\n")
    recoverExplodeOperation(explodeRoot)
    check loadGeometry("001=0x00000001", explodeRoot) == newA
    check loadGeometry("A") == newA
    recoverExplodeOperation(explodeRoot)
    check not fileExists(operationMarker)

  test "geometry-applied intent survives a failed restack":
    clearAll()
    for path in [explodeRoot, explodeStage, explodeBackup, explodeMarker,
      explodeLock, operationMarker, root & ".restore-all.stage",
      root & ".restore-all.backup", root.parentDir / ".restore-all.txn",
      root.parentDir / ".restore-all.lock"]:
      if dirExists(path): removeDir(path)
      elif fileExists(path): removeFile(path)
    createDir(explodeRoot)
    makeGeometry(explodeRoot, "001=0x00000001", oldA)
    createDir(explodeStage)
    makeGeometry(explodeStage, "001=0x00000001", newA)
    writeFile(explodeMarker,
      "PREPARED\n" & explodeStage & "\n" & explodeBackup & "\n0\n")
    createDir(explodeLock)
    writeFile(explodeLock / "pid", "0\n")
    createDir(root)
    createDir(root & ".restore-all.stage")
    makeGeometry(root & ".restore-all.stage", "A", newA)
    writeFile(root.parentDir / ".restore-all.txn",
      "PREPARED\n" & root & ".restore-all.stage\n" &
      root & ".restore-all.backup\n0\n")
    writeFile(operationMarker,
      "GEOMETRY_APPLIED\n" & explodeRoot & "\n" & root & "\n0\n")
    recoverExplodeOperation(explodeRoot)
    check loadGeometry("001=0x00000001", explodeRoot) == newA
    check loadGeometry("A") == newA
    recoverExplodeOperation(explodeRoot)
    check loadGeometry("001=0x00000001", explodeRoot) == newA
    check loadGeometry("A") == newA
    check not fileExists(operationMarker)

for path in [explodeRoot, explodeStage, explodeBackup, explodeMarker, explodeLock]:
  if dirExists(path): removeDir(path)
  elif fileExists(path): removeFile(path)
clearAll()
