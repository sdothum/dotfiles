import std/[os, strutils]
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

proc makeIdentityGeometry(base, id: string, token: ClientToken,
    g: Geometry) =
  makeGeometry(base, id, g)
  createDir(base / id / ("ID=" & $token))

proc mark(phase: string) =
  writeFile(marker, phase & "\n" & stage & "\n" & backup & "\n0\n")
  createDir(lock)
  writeFile(lock / "pid", "0\n")

let oldA = Geometry(x: 1, y: 2, width: 30, height: 40)
let newA = Geometry(x: 10, y: 20, width: 30, height: 40)
let oldC = Geometry(x: 5, y: 6, width: 50, height: 60)
let newC = Geometry(x: 15, y: 16, width: 50, height: 60)
let tokenA = parseClientToken("0123456789abcdef0123456789abcdef:0000000000000001")
let tokenB = parseClientToken("0123456789abcdef0123456789abcdef:0000000000000002")
let explodeRoot = root.parentDir / "explode-state"
let explodeMarker = explodeRoot.parentDir / ".explode.txn"
let explodeLock = explodeRoot.parentDir / ".explode.lock"
let explodeStage = explodeRoot & ".stage"
let explodeBackup = explodeRoot & ".backup"
let operationMarker = explodeRoot.parentDir / ".explode-operation.txn"

proc clearExplodeState() =
  for path in [explodeRoot, explodeStage, explodeBackup, explodeMarker, explodeLock]:
    if dirExists(path): removeDir(path)
    elif fileExists(path): removeFile(path)

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
    check not hasGeometryForToken("A", tokenA)
    check loadGeometry("C") == oldC
    check loadGeometry("term") == oldC
    recoverRestoreHistory(root)
    check loadGeometry("C") == oldC

  test "identity history stages final records and preserves unrelated history":
    clearAll()
    createDir(root)
    makeGeometry(root, "unrelated", oldC)
    let selected = "0x00000001"
    var transaction = beginRestoreHistoryIdentity(@[
      (selected, tokenA, newA)
    ])
    let selectedStage = stage / selected
    check fileExists(marker)
    check readFile(marker).splitLines()[0] == "PREPARED"
    check hasGeometryForToken(selected, tokenA, stage)
    check loadGeometry(selected, stage, false) == newA
    check dirExists(selectedStage / ("ID=" & $tokenA))
    var fields = 0
    for kind, _ in walkDir(selectedStage):
      if kind == pcDir:
        inc fields
    check fields == 5
    check loadGeometry("unrelated", stage, false) == oldC
    commitRestoreHistory(transaction)
    check hasGeometryForToken(selected, tokenA)
    check not hasGeometryForToken(selected, tokenB)
    check loadGeometryForToken(selected, tokenA) == newA
    check loadGeometry("unrelated", root, false) == oldC

  test "identity history abort discards staged generation":
    clearAll()
    createDir(root)
    makeGeometry(root, "0x00000001", oldA)
    var transaction = beginRestoreHistoryIdentity(@[
      ("0x00000001", tokenA, newA)
    ])
    abortRestoreHistory(transaction)
    check loadGeometry("0x00000001", root, false) == oldA
    check not dirExists(stage)
    check not dirExists(lock)
    check not fileExists(marker)

  test "incomplete pre-prepared stage is discarded before a new identity stage":
    clearAll()
    createDir(root)
    makeGeometry(root, "unrelated", oldC)
    createDir(stage / "partial-record")
    createDir(lock)
    writeFile(lock / "pid", "0\n")
    var transaction = beginRestoreHistoryIdentity(@[
      ("0x00000001", tokenA, newA)
    ])
    check not dirExists(stage / "partial-record")
    check hasGeometryForToken("0x00000001", tokenA, stage)
    check loadGeometry("unrelated", stage, false) == oldC
    abortRestoreHistory(transaction)
    check not dirExists(stage)
    check not dirExists(lock)

  test "prepared identity history is discarded during recovery":
    clearAll()
    createDir(root)
    makeIdentityGeometry(root, "0x00000001", tokenA, oldA)
    createDir(stage)
    makeIdentityGeometry(stage, "0x00000001", tokenA, newA)
    mark("PREPARED")
    recoverRestoreHistory(root)
    check loadGeometry("0x00000001", root, false) == oldA
    check hasGeometryForToken("0x00000001", tokenA)
    check not dirExists(stage)
    check not fileExists(marker)
    check not dirExists(lock)

  test "commit-required identity history rolls forward":
    clearAll()
    createDir(backup)
    makeGeometry(backup, "0x00000001", oldA)
    createDir(stage)
    makeIdentityGeometry(stage, "0x00000001", tokenA, newA)
    mark("COMMIT_REQUIRED")
    recoverRestoreHistory(root)
    check hasGeometryForToken("0x00000001", tokenA)
    check loadGeometryForToken("0x00000001", tokenA) == newA
    check not dirExists(backup)
    check not fileExists(marker)
    check not dirExists(lock)

  test "publishing identity history completes both renames":
    clearAll()
    createDir(root)
    makeGeometry(root, "unrelated", oldC)
    createDir(stage)
    makeIdentityGeometry(stage, "0x00000001", tokenA, newA)
    makeGeometry(stage, "unrelated", oldC)
    mark("PUBLISHING")
    recoverRestoreHistory(root)
    check hasGeometryForToken("0x00000001", tokenA)
    check loadGeometryForToken("0x00000001", tokenA) == newA
    check loadGeometry("unrelated", root, false) == oldC
    check not dirExists(backup)
    check not fileExists(marker)
    check not dirExists(lock)

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
    clearExplodeState()
    createDir(explodeRoot.parentDir)
    var transaction = beginExplodeStateIdentity(explodeRoot, @[
      ("0x00000001", tokenA, oldA)])
    check readFile(explodeMarker).splitLines()[0] == "PREPARED"
    check hasGeometryForToken("001=0x00000001", tokenA, explodeStage)
    check loadGeometry("001=0x00000001", explodeStage) == oldA
    commitExplodeState(transaction)
    let entries = loadStateEntries(explodeRoot)
    check entries.len == 1
    check entries[0].token == tokenA
    check entries[0].geometry == oldA

  test "non-preserving identity stage replaces the prior saved generation":
    clearExplodeState()
    var first = beginExplodeStateIdentity(explodeRoot,
      @[("0x00000001", tokenA, oldA)])
    commitExplodeState(first)
    var replacement = beginExplodeStateIdentity(explodeRoot,
      @[("0x00000002", tokenB, newC)])
    check hasGeometryForToken("001=0x00000002", tokenB, explodeStage)
    check not hasGeometryForToken("001=0x00000001", tokenA, explodeStage)
    commitExplodeState(replacement)
    check loadStateEntries(explodeRoot) == @[("0x00000002", tokenB, newC)]

  test "preserving identity stage uses original generation on refold":
    clearExplodeState()
    let original = @[("0x00000001", tokenA, oldA)]
    var first = beginExplodeStateIdentity(explodeRoot, original,
      preserveOriginal = true)
    check hasGeometryForToken("001=0x00000001", tokenA, explodeStage)
    commitExplodeState(first)

    # A refold candidate includes a newly appeared client. The committed
    # original set remains authoritative and is reconstructed into the stage.
    var refold = beginExplodeStateIdentity(explodeRoot,
      @[("0x00000001", tokenA, newA), ("0x00000002", tokenB, newC)],
      preserveOriginal = true)
    check loadStateEntries(explodeStage) == original
    check not hasGeometryForToken("002=0x00000002", tokenB, explodeStage)
    check readFile(explodeMarker).splitLines()[0] == "PREPARED"
    commitExplodeState(refold)
    check loadStateEntries(explodeRoot) == original

  test "preserve mode falls back to supplied identities for empty saved entries":
    clearExplodeState()
    createDir(explodeRoot)
    makeGeometry(explodeRoot, "001=0x00000009", oldC)
    let candidate = @[("0x00000002", tokenB, newC)]
    var transaction = beginExplodeStateIdentity(explodeRoot, candidate,
      preserveOriginal = true)
    check loadStateEntries(explodeStage) == candidate
    commitExplodeState(transaction)
    check loadStateEntries(explodeRoot) == candidate

  test "incomplete stage without PREPARED is discarded on next begin":
    clearExplodeState()
    createDir(explodeStage / "partial-record")
    createDir(explodeLock)
    writeFile(explodeLock / "pid", "0\n")
    var transaction = beginExplodeStateIdentity(explodeRoot,
      @[("0x00000001", tokenA, oldA)])
    check not dirExists(explodeStage / "partial-record")
    check hasGeometryForToken("001=0x00000001", tokenA, explodeStage)
    abortExplodeState(transaction)
    check not dirExists(explodeStage)

  test "tokenless explode records never become restore entries":
    for path in [explodeRoot, explodeStage, explodeBackup, explodeMarker, explodeLock]:
      if dirExists(path): removeDir(path)
      elif fileExists(path): removeFile(path)
    createDir(explodeRoot)
    makeGeometry(explodeRoot, "001=0x00000001", oldA)
    check loadStateEntries(explodeRoot).len == 0

  test "interrupted explode publication rolls forward":
    clearExplodeState()
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

  test "prepared identity explode stage is discarded":
    clearExplodeState()
    createDir(explodeRoot)
    makeIdentityGeometry(explodeRoot, "001=0x00000001", tokenA, oldA)
    createDir(explodeStage)
    makeIdentityGeometry(explodeStage, "001=0x00000001", tokenB, newA)
    writeFile(explodeMarker,
      "PREPARED\n" & explodeStage & "\n" & explodeBackup & "\n0\n")
    createDir(explodeLock)
    writeFile(explodeLock / "pid", "0\n")
    recoverExplodeState(explodeRoot)
    check loadStateEntries(explodeRoot) == @[("0x00000001", tokenA, oldA)]
    check not dirExists(explodeStage)
    check not fileExists(explodeMarker)
    check not dirExists(explodeLock)

  test "commit-required identity explode stage rolls forward":
    clearExplodeState()
    createDir(explodeBackup)
    makeIdentityGeometry(explodeBackup, "001=0x00000001", tokenA, oldA)
    createDir(explodeStage)
    makeIdentityGeometry(explodeStage, "001=0x00000002", tokenB, newC)
    writeFile(explodeMarker,
      "COMMIT_REQUIRED\n" & explodeStage & "\n" & explodeBackup & "\n0\n")
    createDir(explodeLock)
    writeFile(explodeLock / "pid", "0\n")
    recoverExplodeState(explodeRoot)
    check loadStateEntries(explodeRoot) == @[("0x00000002", tokenB, newC)]
    check not dirExists(explodeBackup)
    check not fileExists(explodeMarker)
    check not dirExists(explodeLock)

  test "publishing identity explode stage completes both renames":
    clearExplodeState()
    createDir(explodeRoot)
    makeIdentityGeometry(explodeRoot, "001=0x00000001", tokenA, oldA)
    createDir(explodeStage)
    makeIdentityGeometry(explodeStage, "001=0x00000002", tokenB, newC)
    writeFile(explodeMarker,
      "PUBLISHING\n" & explodeStage & "\n" & explodeBackup & "\n0\n")
    createDir(explodeLock)
    writeFile(explodeLock / "pid", "0\n")
    recoverExplodeState(explodeRoot)
    check loadStateEntries(explodeRoot) == @[("0x00000002", tokenB, newC)]
    check not dirExists(explodeBackup)
    check not fileExists(explodeMarker)
    check not dirExists(explodeLock)

  test "outer prepared intent discards child identity generations":
    clearAll()
    clearExplodeState()
    for path in [operationMarker, root & ".restore-all.stage",
        root & ".restore-all.backup", root.parentDir / ".restore-all.txn",
        root.parentDir / ".restore-all.lock"]:
      if dirExists(path): removeDir(path)
      elif fileExists(path): removeFile(path)
    createDir(explodeRoot)
    makeIdentityGeometry(explodeRoot, "001=0x00000001", tokenA, oldA)
    createDir(explodeStage)
    makeIdentityGeometry(explodeStage, "001=0x00000001", tokenB, newA)
    writeFile(explodeMarker,
      "PREPARED\n" & explodeStage & "\n" & explodeBackup & "\n0\n")
    createDir(explodeLock)
    writeFile(explodeLock / "pid", "0\n")
    createDir(root)
    makeGeometry(root, "A", oldA)
    createDir(root & ".restore-all.stage")
    makeGeometry(root & ".restore-all.stage", "A", newA)
    writeFile(root.parentDir / ".restore-all.txn",
      "PREPARED\n" & root & ".restore-all.stage\n" &
      root & ".restore-all.backup\n0\n")
    writeFile(operationMarker,
      "PREPARED\n" & explodeRoot & "\n" & root & "\n0\n")
    recoverExplodeOperation(explodeRoot)
    check loadStateEntries(explodeRoot) == @[("0x00000001", tokenA, oldA)]
    check loadGeometry("A") == oldA
    check not dirExists(explodeStage)
    check not dirExists(root & ".restore-all.stage")
    check not fileExists(operationMarker)

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
    makeIdentityGeometry(explodeStage, "001=0x00000001", tokenB, newA)
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
    makeIdentityGeometry(explodeStage, "001=0x00000001", tokenB, newA)
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
