import std/algorithm
import std/envvars
import std/os
import std/sequtils
import std/re
import std/sets
import std/strutils
import std/options
import ../zephyr_errors

import types
import window_query as query

proc writeGeometry(g: Geometry, root: string,
    token = none(query.ClientToken)) =
  let identity = if token.isSome: $token.get else: ""
  removeDir(root)
  createDir(root)

  if token.isSome:
    createDir(root / ("ID=" & identity))

  createDir(root / ("X=" & $g.x))
  createDir(root / ("Y=" & $g.y))
  createDir(root / ("WIDTH=" & $g.width))
  createDir(root / ("HEIGHT=" & $g.height))

type
  RestoreHistoryUpdate* = tuple[
    winid: string,
    geometry: Geometry
  ]

  IdentityHistoryUpdate* = tuple[
    winid: string,
    token: query.ClientToken,
    geometry: Geometry
  ]

  RestoreHistoryTransaction* = object
    root: string
    stage: string
    backup: string
    marker: string
    lock: string
    active: bool

  ExplodeStateRecord* = tuple[
    winid: string,
    geometry: Geometry
  ]

  IdentityExplodeStateRecord* = tuple[
    winid: string,
    token: query.ClientToken,
    geometry: Geometry
  ]

  ExplodeTransaction* = object
    root: string
    stage: string
    backup: string
    marker: string
    lock: string
    active: bool

  ExplodeOperation* = object
    explode: ExplodeTransaction
    history: RestoreHistoryTransaction
    hasHistory: bool
    root: string
    marker: string
    active: bool

const RestoreTxnName = ".restore-all.txn"
const RestoreTxnLockName = ".restore-all.lock"
const ExplodeTxnName = ".explode.txn"
const ExplodeTxnLockName = ".explode.lock"
const ExplodeOperationName = ".explode-operation.txn"

proc restoreTxnMarkerPath(root: string): string =
  splitFile(root).dir / RestoreTxnName

proc restoreTxnLockPath(root: string): string =
  splitFile(root).dir / RestoreTxnLockName

proc explodeMetadataPath(root, legacyName: string): string =
  let name = extractFilename(root)
  if name.startsWith("explode:group:") or name.startsWith("fold:class:"):
    return splitFile(root).dir / ("." & name & legacyName[".explode".len .. ^1])
  splitFile(root).dir / legacyName

proc explodeTxnMarkerPath(root: string): string =
  explodeMetadataPath(root, ExplodeTxnName)

proc explodeTxnLockPath(root: string): string =
  explodeMetadataPath(root, ExplodeTxnLockName)

proc explodeOperationMarkerPath(root: string): string =
  explodeMetadataPath(root, ExplodeOperationName)

proc writeRestoreMarker(path, phase, stage, backup: string, pid: int) =
  let temporary = path & ".tmp"
  writeFile(temporary, phase & "\n" & stage & "\n" & backup & "\n" & $pid & "\n")
  moveFile(temporary, path)

proc processAlive(pid: int): bool =
  pid > 0 and dirExists("/proc/" & $pid)

proc recoverRestoreHistory*(root: string, fromExplodeOperation = false)
proc recoverExplodeOperation*(root: string)
proc beginRestoreHistory*(updates: seq[RestoreHistoryUpdate]): RestoreHistoryTransaction
proc beginRestoreHistoryIdentity*(updates: seq[IdentityHistoryUpdate]): RestoreHistoryTransaction
proc commitRestoreHistory*(transaction: var RestoreHistoryTransaction)

proc transactionOwner(root: string): int =
  let ownerFile = restoreTxnLockPath(root) / "pid"
  if not fileExists(ownerFile):
    return 0
  try:
    result = parseInt(readFile(ownerFile).strip())
  except ValueError:
    result = 0

proc lockOwner(lock: string): int =
  let ownerFile = lock / "pid"
  if not fileExists(ownerFile):
    return 0
  try:
    result = parseInt(readFile(ownerFile).strip())
  except ValueError:
    result = 0

proc prepareWinfoAccess(root: string, write: bool) =
  if root.len == 0:
    return
  recoverRestoreHistory(root)
  let lock = restoreTxnLockPath(root)
  if not dirExists(lock):
    return

  let owner = transactionOwner(root)
  if owner == getCurrentProcessId():
    return

  if write:
    raiseZephyrError("state WINFO: restore-all transaction is active")

  # Readers wait for the short publication/cleanup window rather than
  # interpreting a temporarily absent WINFO root as missing history.
  var attempts = 0
  while dirExists(lock) and attempts < 200:
    sleep(10)
    recoverRestoreHistory(root)
    inc attempts
  if dirExists(lock):
    raiseZephyrError("state WINFO: restore-all transaction did not complete")

proc recoverRestoreHistory*(root: string, fromExplodeOperation = false) =
  ## Complete or discard an interrupted restore-all publication.  A live
  ## owner is left alone; only a dead owner can have left durable residue.
  if root.len == 0:
    return
  if not fromExplodeOperation:
    let operationRoot = splitFile(root).dir / "layout" / "explode"
    if fileExists(explodeOperationMarkerPath(operationRoot)):
      recoverExplodeOperation(operationRoot)
    # Named layout operations share WINFO history, but own separate journals.
    var layoutRoots = @[splitFile(operationRoot).dir]
    let wme = getEnv("WME")
    if wme.len > 0 and wme / "layout" notin layoutRoots:
      layoutRoots.add(wme / "layout")
    for layoutRoot in layoutRoots:
      for kind, path in walkDir(layoutRoot):
        let name = extractFilename(path)
        if kind == pcFile and (name.startsWith(".explode:group:") or
            name.startsWith(".fold:class:")) and
            name.endsWith("-operation.txn"):
          let fields = readFile(path).splitLines()
          if fields.len >= 4 and fields[2] == root:
            let groupRoot = layoutRoot / name[1 ..< name.len - "-operation.txn".len]
            recoverExplodeOperation(groupRoot)
  let marker = restoreTxnMarkerPath(root)
  if not fileExists(marker):
    let lock = restoreTxnLockPath(root)
    if dirExists(lock) and not processAlive(lockOwner(lock)):
      removeDir(lock)
    return

  let fields = readFile(marker).splitLines()
  if fields.len < 4:
    # An incomplete marker cannot describe a publication safely.
    removeFile(marker)
    return

  let phase = fields[0]
  let stage = fields[1]
  let backup = fields[2]
  var pid = 0
  try:
    pid = parseInt(fields[3])
  except ValueError:
    pid = 0

  if processAlive(pid):
    return

  case phase
  of "PREPARED":
    if dirExists(stage):
      removeDir(stage)
  of "COMMIT_REQUIRED", "PUBLISHING":
    # Roll forward the complete staged generation.  The operation is
    # idempotent across crashes between either directory rename.
    if dirExists(stage):
      if dirExists(root) and not dirExists(backup):
        moveDir(root, backup)
      if not dirExists(root):
        moveDir(stage, root)
    if dirExists(backup):
      removeDir(backup)
  else:
    if dirExists(stage):
      removeDir(stage)

  if fileExists(marker):
    removeFile(marker)
  let lock = restoreTxnLockPath(root)
  if dirExists(lock):
    removeDir(lock)

proc recoverExplodeState*(root: string) =
  if root.len == 0:
    return
  let marker = explodeTxnMarkerPath(root)
  if not fileExists(marker):
    let lock = explodeTxnLockPath(root)
    if dirExists(lock) and not processAlive(lockOwner(lock)):
      removeDir(lock)
    return
  let fields = readFile(marker).splitLines()
  if fields.len < 4:
    removeFile(marker)
    return
  var pid = 0
  try: pid = parseInt(fields[3])
  except ValueError: discard
  if processAlive(pid):
    return
  let phase = fields[0]
  let stage = fields[1]
  let backup = fields[2]
  if phase == "PREPARED":
    if dirExists(stage): removeDir(stage)
  elif phase == "COMMIT_REQUIRED" or phase == "PUBLISHING":
    if dirExists(stage):
      if dirExists(root) and not dirExists(backup): moveDir(root, backup)
      if not dirExists(root): moveDir(stage, root)
    if dirExists(backup): removeDir(backup)
  if fileExists(marker): removeFile(marker)
  let lock = explodeTxnLockPath(root)
  if dirExists(lock): removeDir(lock)

proc recoverExplodeOperation*(root: string) =
  let marker = explodeOperationMarkerPath(root)
  if not fileExists(marker): return
  let fields = readFile(marker).splitLines()
  if fields.len < 4: removeFile(marker); return
  var pid = 0
  try: pid = parseInt(fields[3])
  except ValueError: discard
  if processAlive(pid): return
  let explodeRoot = fields[1]
  let winfoRoot = fields[2]
  if fields[0] == "PREPARED":
    recoverExplodeState(explodeRoot)
    recoverRestoreHistory(winfoRoot, true)
  else:
    # GEOMETRY_APPLIED, COMMIT_REQUIRED, and later publication phases all
    # mean that the prepared restoration generations must roll forward.
    let explodeMarker = explodeTxnMarkerPath(explodeRoot)
    if fileExists(explodeMarker):
      let child = readFile(explodeMarker).splitLines()
      if child.len >= 4 and child[0] == "PREPARED":
        writeRestoreMarker(explodeMarker, "COMMIT_REQUIRED", child[1], child[2], 0)
    let winfoMarker = restoreTxnMarkerPath(winfoRoot)
    if fileExists(winfoMarker):
      let child = readFile(winfoMarker).splitLines()
      if child.len >= 4 and child[0] == "PREPARED":
        writeRestoreMarker(winfoMarker, "COMMIT_REQUIRED", child[1], child[2], 0)
    recoverExplodeState(explodeRoot)
    recoverRestoreHistory(winfoRoot, true)
  if fileExists(marker): removeFile(marker)

proc acquireExplodeLock*(root: string): string =
  result = explodeTxnLockPath(root)
  recoverExplodeState(root)
  if dirExists(result):
    let owner = lockOwner(result)
    if processAlive(owner):
      raiseZephyrError("layout explode: transaction is already active")
    removeDir(result)
  createDir(splitFile(root).dir)
  createDir(result)
  writeFile(result / "pid", $getCurrentProcessId())

proc releaseExplodeLock*(lock: string) =
  if dirExists(lock): removeDir(lock)

proc beginExplodeStateStaging(root: string): ExplodeTransaction =
  result.root = root
  result.stage = root & ".stage"
  result.backup = root & ".backup"
  result.marker = explodeTxnMarkerPath(root)
  result.lock = acquireExplodeLock(root)
  if dirExists(result.stage): removeDir(result.stage)
  if dirExists(result.backup): removeDir(result.backup)
  createDir(result.stage)

proc beginExplodeState*(root: string, records: seq[ExplodeStateRecord]): ExplodeTransaction =
  result = beginExplodeStateStaging(root)
  for position, record in records:
    writeGeometry(record.geometry, result.stage / align($(position + 1), 3, '0') & "=" & record.winid)
  writeRestoreMarker(result.marker, "PREPARED", result.stage, result.backup, getCurrentProcessId())
  result.active = true

proc loadStateEntries*(root: string): seq[IdentityExplodeStateRecord]

proc beginExplodeStateIdentity*(root: string,
    records: seq[IdentityExplodeStateRecord], preserveOriginal = false): ExplodeTransaction =
  for record in records:
    query.validateClientToken(record.token)
  result = beginExplodeStateStaging(root)
  var saved = records
  if preserveOriginal:
    let existing = loadStateEntries(root) # Read while holding the operation lock.
    if existing.len > 0:
      saved = existing
  for position, record in saved:
    writeGeometry(record.geometry,
      result.stage / align($(position + 1), 3, '0') & "=" & record.winid,
      some(record.token))
  writeRestoreMarker(result.marker, "PREPARED", result.stage, result.backup,
    getCurrentProcessId())
  result.active = true

proc abortExplodeState*(transaction: var ExplodeTransaction) =
  if not transaction.active: return
  if fileExists(transaction.marker): removeFile(transaction.marker)
  if dirExists(transaction.stage): removeDir(transaction.stage)
  releaseExplodeLock(transaction.lock)
  transaction.active = false

proc commitExplodeState*(transaction: var ExplodeTransaction, releaseLock = true) =
  if not transaction.active: return
  writeRestoreMarker(transaction.marker, "COMMIT_REQUIRED", transaction.stage, transaction.backup, getCurrentProcessId())
  writeRestoreMarker(transaction.marker, "PUBLISHING", transaction.stage, transaction.backup, getCurrentProcessId())
  if dirExists(transaction.root): moveDir(transaction.root, transaction.backup)
  moveDir(transaction.stage, transaction.root)
  if dirExists(transaction.backup): removeDir(transaction.backup)
  if fileExists(transaction.marker): removeFile(transaction.marker)
  if releaseLock: releaseExplodeLock(transaction.lock)
  transaction.active = false

proc beginExplodeOperation*(root: string, records: seq[ExplodeStateRecord],
    history: seq[RestoreHistoryUpdate]): ExplodeOperation =
  result.root = root
  result.marker = explodeOperationMarkerPath(root)
  result.explode = beginExplodeState(root, records)
  result.hasHistory = history.len > 0
  if result.hasHistory:
    result.history = beginRestoreHistory(history)
  writeRestoreMarker(result.marker, "PREPARED", root, getEnv("WINFO"), getCurrentProcessId())
  result.active = true

proc beginExplodeOperationIdentity*(root: string,
    records: seq[IdentityExplodeStateRecord],
    history: seq[IdentityHistoryUpdate], preserveOriginal = false): ExplodeOperation =
  result.root = root
  result.marker = explodeOperationMarkerPath(root)
  result.explode = beginExplodeStateIdentity(root, records, preserveOriginal)
  result.hasHistory = history.len > 0
  if result.hasHistory:
    result.history = beginRestoreHistoryIdentity(history)
  writeRestoreMarker(result.marker, "PREPARED", root, getEnv("WINFO"),
    getCurrentProcessId())
  result.active = true

proc commitExplodeOperation*(operation: var ExplodeOperation) =
  if not operation.active: return
  writeRestoreMarker(operation.marker, "COMMIT_REQUIRED", operation.root,
    getEnv("WINFO"), getCurrentProcessId())
  commitExplodeState(operation.explode, false)
  if operation.hasHistory:
    commitRestoreHistory(operation.history)
  releaseExplodeLock(operation.explode.lock)
  if fileExists(operation.marker): removeFile(operation.marker)
  operation.active = false

proc markExplodeGeometryApplied*(operation: var ExplodeOperation) =
  ## Geometry has been acknowledged by the WM.  Preserve the prepared
  ## restoration generations even if the subsequent stacking request fails.
  if not operation.active:
    return
  writeRestoreMarker(operation.marker, "GEOMETRY_APPLIED", operation.root,
    getEnv("WINFO"), getCurrentProcessId())

proc beginRestoreHistoryStaging(): RestoreHistoryTransaction =
  let root = getEnv("WINFO")
  if root.len == 0:
    raiseZephyrError("state restore-all: WINFO is not configured")
  result.root = root
  result.marker = restoreTxnMarkerPath(root)
  result.lock = restoreTxnLockPath(root)
  recoverRestoreHistory(root)

  if not dirExists(root):
    createDir(root)

  if dirExists(result.lock):
    var owner = 0
    let ownerFile = result.lock / "pid"
    if fileExists(ownerFile):
      try:
        owner = parseInt(readFile(ownerFile).strip())
      except ValueError:
        owner = 0
    if processAlive(owner):
      raiseZephyrError("state restore-all: history transaction is already active")
    removeDir(result.lock)
  createDir(result.lock)
  writeFile(result.lock / "pid", $getCurrentProcessId())

  result.stage = root & ".restore-all.stage"
  result.backup = root & ".restore-all.backup"
  if dirExists(result.stage):
    removeDir(result.stage)
  if dirExists(result.backup):
    removeDir(result.backup)
  copyDir(root, result.stage)

proc markRestoreHistoryPrepared(transaction: var RestoreHistoryTransaction) =
  writeRestoreMarker(
    transaction.marker,
    "PREPARED",
    transaction.stage,
    transaction.backup,
    getCurrentProcessId()
  )
  transaction.active = true

proc beginRestoreHistory*(updates: seq[RestoreHistoryUpdate]): RestoreHistoryTransaction =
  result = beginRestoreHistoryStaging()

  for update in updates:
    writeGeometry(update.geometry, result.stage / update.winid)

  markRestoreHistoryPrepared(result)

proc beginRestoreHistoryIdentity*(updates: seq[IdentityHistoryUpdate]): RestoreHistoryTransaction =
  for update in updates:
    query.validateClientToken(update.token)
  result = beginRestoreHistoryStaging()
  for update in updates:
    writeGeometry(update.geometry, result.stage / update.winid, some(update.token))
  markRestoreHistoryPrepared(result)

proc abortRestoreHistory*(transaction: var RestoreHistoryTransaction) =
  if not transaction.active:
    return
  if fileExists(transaction.marker):
    removeFile(transaction.marker)
  if dirExists(transaction.stage):
    removeDir(transaction.stage)
  if dirExists(transaction.backup):
    removeDir(transaction.backup)
  if dirExists(transaction.lock):
    removeDir(transaction.lock)
  transaction.active = false

proc commitRestoreHistory*(transaction: var RestoreHistoryTransaction) =
  if not transaction.active:
    return

  # Once this marker is durable, recovery rolls the complete staged
  # generation forward after an interrupted publication.
  writeRestoreMarker(
    transaction.marker,
    "COMMIT_REQUIRED",
    transaction.stage,
    transaction.backup,
    getCurrentProcessId()
  )
  writeRestoreMarker(
    transaction.marker,
    "PUBLISHING",
    transaction.stage,
    transaction.backup,
    getCurrentProcessId()
  )
  if dirExists(transaction.root):
    moveDir(transaction.root, transaction.backup)
  moveDir(transaction.stage, transaction.root)
  if dirExists(transaction.backup):
    removeDir(transaction.backup)
  if fileExists(transaction.marker):
    removeFile(transaction.marker)
  if dirExists(transaction.lock):
    removeDir(transaction.lock)
  transaction.active = false

proc saveGeometry*(g: Geometry, winid: string = "", precheck = true) =
  prepareWinfoAccess(getEnv("WINFO"), true)
  recoverRestoreHistory(getEnv("WINFO"))
  let id =
    if winid.len == 0:
      query.focusedWinid()
    else:
      winid
  let token =
    if id.match(re(r"^0x[0-9a-fA-F]{8}$")): query.clientToken(id)
    else: none(query.ClientToken)

  # avoid losing revert history to repeated window action
  if precheck:
    let newGeometry = query.geometry(id)
    if newGeometry.x == g.x and newGeometry.y == g.y and newGeometry.width == g.width and newGeometry.height == g.height:
      return

  writeGeometry(
    g,
    getEnv("WINFO") / id,
    token
  )

proc saveGeometryWithToken*(g: Geometry, winid: string,
    token: query.ClientToken) =
  query.validateClientToken(token)
  prepareWinfoAccess(getEnv("WINFO"), true)
  writeGeometry(g, getEnv("WINFO") / winid, some(token))

proc saveOriginalIfChanged*(
  source: Geometry,
  destination: Geometry,
  winid: string = ""
) =
  if source == destination:
    return

  # Absolute moves are exact, and minimum-size enforcement cannot negate a
  # requested increase. A shrink-only resize may be clamped back to source.
  if destination.x == source.x and
      destination.y == source.y and
      destination.width <= source.width and
      destination.height <= source.height:
    saveGeometry(source, winid)
    return

  let id =
    if winid.len == 0:
      query.focusedWinid()
    else:
      winid
  let token =
    if id.match(re(r"^0x[0-9a-fA-F]{8}$")): query.clientToken(id)
    else: none(query.ClientToken)

  writeGeometry(
    source,
    getEnv("WINFO") / id,
    token
  )

proc saveGeometry*(winid: string = "") =
  let id =
    if winid.len == 0:
      query.focusedWinid()
    else:
      winid

  saveGeometry(query.geometry(id), id, false)

proc saveState*(root: string, position: int, winid: string, g: Geometry) =

  writeGeometry(
    g,
    root / align($position, 3, '0') & "=" & winid
  )

proc saveStateIdentity*(root: string, position: int, winid: string,
    token: query.ClientToken, g: Geometry) =
  query.validateClientToken(token)
  writeGeometry(g, root / align($position, 3, '0') & "=" & winid, some(token))

proc saveState*(root: string, position: int, winid: string) =
  saveState(root, position, winid, query.geometry(winid))

proc hasGeometryForToken*(winid: string, token: query.ClientToken,
    root: string = getEnv("WINFO")): bool
proc historyToken(root, id: string): Option[query.ClientToken]

proc hasGeometry*(winid: string = "", root: string = getEnv("WINFO")): bool =
  if root == getEnv("WINFO"):
    prepareWinfoAccess(root, false)
  let id =
    if winid.len == 0:
      query.focusedWinid()
    else:
      winid

  if not dirExists(root / id):
    return false
  if root == getEnv("WINFO") and id.match(re(r"^0x[0-9a-fA-F]{8}$")):
    let token = query.tryClientToken(id)
    if token.isNone:
      return false
    return hasGeometryForToken(id, token.get, root)
  result = true

proc historyToken(root, id: string): Option[query.ClientToken] =
  let path = root / id
  var found = ""
  for kind, entry in walkDir(path):
    if kind == pcDir and extractFilename(entry).startsWith("ID="):
      if found.len > 0:
        raiseZephyrError("state history: duplicate identity for " & id)
      found = extractFilename(entry)[3 .. ^1]
  if found.len == 0:
    return none(query.ClientToken)
  try:
    result = some(query.parseClientToken(found))
  except ValueError:
    raiseZephyrError("state history: malformed identity for " & id)

proc hasGeometryForToken*(winid: string, token: query.ClientToken,
    root: string = getEnv("WINFO")): bool =
  if root == getEnv("WINFO"):
    prepareWinfoAccess(root, false)
  let path = root / winid
  if not dirExists(path):
    return false
  let stored = historyToken(root, winid)
  if stored.isNone or stored.get != token:
    return false
  result = true

proc loadGeometry*(winid: string = "", root: string = getEnv("WINFO"),
    validateIdentity = true): Geometry =
  if root == getEnv("WINFO"):
    prepareWinfoAccess(root, false)
  let id =
    if winid.len == 0:
      query.focusedWinid()
    else:
      winid

  # proc fail(error: string) =
  #   raiseZephyrError("state loadGeometry: " & error)

  let path = root / id

  if not dirExists(path):
    raiseZephyrError("no saved geometry for window " & id)

  if validateIdentity and root == getEnv("WINFO") and id.match(re(r"^0x[0-9a-fA-F]{8}$")):
    let live = query.tryClientToken(id)
    if live.isNone:
      raiseZephyrError("no saved geometry for window " & id)
    let stored = historyToken(root, id)
    if stored.isNone or stored.get != live.get:
      raiseZephyrError("no saved geometry for window " & id)

  var
    gotX = false
    gotY = false
    gotWidth = false
    gotHeight = false

  for kind, entry in walkDir(path):
    if kind != pcDir:
      continue

    let name = extractFilename(entry)

    if name.startsWith("X="):
      result.x = parseInt(name[2 .. ^1])
      gotX = true
    elif name.startsWith("Y="):
      result.y = parseInt(name[2 .. ^1])
      gotY = true
    elif name.startsWith("WIDTH="):
      result.width = parseInt(name[6 .. ^1])
      gotWidth = true
    elif name.startsWith("HEIGHT="):
      result.height = parseInt(name[7 .. ^1])
      gotHeight = true

  if not (gotX and gotY and gotWidth and gotHeight):
    raiseZephyrError("incomplete saved geometry for window " & id)

proc loadGeometryForToken*(winid: string, token: query.ClientToken,
    root: string = getEnv("WINFO")): Geometry =
  if root == getEnv("WINFO"):
    prepareWinfoAccess(root, false)
  let path = root / winid
  if not dirExists(path):
    raiseZephyrError("state loadGeometry: no saved geometry for window " & winid)
  let stored = historyToken(root, winid)
  if stored.isNone or stored.get != token:
    raiseZephyrError("state loadGeometry: history identity mismatch for window " & winid)
  result = loadGeometry(winid, root, false)

proc loadStateWinids*(root: string): seq[string] =
  if not dirExists(root):
    return @[]

  let entries = toSeq(walkDir(root, relative = true))
    .sorted()

  var seen = initHashSet[string]()
  for index, item in entries:
    if item.kind != pcDir or item.path.len != 14 or item.path[3] != '=' or
        not item.path[0 .. 2].allCharsInSet(Digits):
      raiseZephyrError("state explode: malformed record " & item.path)
    let expected = align($(index + 1), 3, '0')
    if item.path[0 .. 2] != expected:
      raiseZephyrError("state explode: non-contiguous ordinal " & item.path)
    let winid = item.path[4 .. ^1]
    if not winid.match(re(r"^0x[0-9a-fA-F]{8}$")) or winid in seen:
      raiseZephyrError("state explode: invalid or duplicate XID " & winid)
    seen.incl(winid)
    # Validate the complete record before any caller can submit it to WM.
    discard loadGeometry(item.path, root)
    result.add(winid)

proc loadStateEntries*(root: string): seq[IdentityExplodeStateRecord] =
  if not dirExists(root):
    return @[]
  # Parse only identity-bearing records for production unexplode.  The
  # legacy loadStateWinids API remains available for compatibility tests, but
  # must never feed a tokenless record into a restore batch.
  let entries = toSeq(walkDir(root, relative = true)).sorted()
  var expected = 1
  for item in entries:
    if item.kind != pcDir or item.path.len != 14 or item.path[3] != '=' or
        not item.path[0 .. 2].allCharsInSet(Digits):
      raiseZephyrError("state explode: malformed record " & item.path)
    let ordinal = align($expected, 3, '0')
    if item.path[0 .. 2] != ordinal:
      raiseZephyrError("state explode: non-contiguous ordinal " & item.path)
    let winid = item.path[4 .. ^1]
    if not winid.match(re(r"^0x[0-9a-fA-F]{8}$")):
      raiseZephyrError("state explode: invalid XID " & winid)
    let recordName = item.path
    let token = historyToken(root, recordName)
    if token.isSome:
      result.add((winid, token.get, loadGeometry(recordName, root)))
    inc expected

# proc loadStateFocus*(root: string): string =
#   for kind, entry in walkDir(root, relative = true):
#     if kind == pcDir or kind == pcLinkToDir:
#       if entry.startsWith("focus="):
#         return entry[6 .. ^1]

#   result = ""

proc snapshot*(args: seq[string]) =
  let id =
    if args.len == 0:
      query.focusedWinid()
    else:
      args[0]

  let token = query.clientToken(id)

  writeGeometry(
    query.geometry(id),
    getEnv("WME") / "snapshot" / id,
    token
  )

proc snapshot*() =
  snapshot(@[])

proc restore*(args: seq[string]) =
  let id =
    if args.len == 0:
      query.focusedWinid()
    else:
      args[0]

  let root = getEnv("WME") / "snapshot"
  let token = historyToken(root, id)

  if token.isNone:
    raiseZephyrError("state restore: snapshot has no identity for window " & id)

  let live = query.tryClientToken(id)
  if live.isNone:
    raiseZephyrError("state restore: window no longer exists " & id)

  if live.get != token.get:
    raiseZephyrError("state restore: snapshot identity mismatch for window " & id)

  writeGeometry(
    loadGeometry(id, root, false),
    getEnv("WINFO") / id,
    some(token.get)
  )

proc restore*() =
  restore(@[])

#
# Dispatch
#

proc dispatch*(verb: string, rest: seq[string]) =
  case verb
  of "snapshot":
    snapshot(rest)

  of "restore":
    restore(rest)

  else:
    raiseZephyrError("unknown state action: " & verb)

proc windowStateCleanupReady*(): bool =
  ## Defer daemon cleanup while restore-all may replace the entire WINFO tree.
  let root = getEnv("WINFO")
  if root.len == 0:
    return true
  try:
    recoverRestoreHistory(root)
    return not dirExists(restoreTxnLockPath(root))
  except CatchableError:
    return false

proc cleanupWindowState*(winid: string): bool =
  let root = getEnv("WINFO")
  if root.len == 0:
    return true
  if not winid.match(re(r"^0x[0-9a-fA-F]{8}$")):
    return false
  if not windowStateCleanupReady():
    return false
  let path = root / winid
  try:
    if symlinkExists(path):
      removeFile(path)
    elif dirExists(path):
      removeDir(path)
    return true
  except CatchableError:
    return false
