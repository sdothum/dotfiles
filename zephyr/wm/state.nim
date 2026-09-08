import std/algorithm
import std/envvars
import std/os
import std/sequtils
import std/re
import std/sets
import std/strutils

import types
import window_query as query

proc writeGeometry(g: Geometry, root: string, token: query.ClientToken = query.ClientToken()) =
  removeDir(root)
  createDir(root)

  if token.isPresent:
    createDir(root / ("ID=" & $token))

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

proc explodeTxnMarkerPath(root: string): string =
  splitFile(root).dir / ExplodeTxnName

proc explodeTxnLockPath(root: string): string =
  splitFile(root).dir / ExplodeTxnLockName

proc explodeOperationMarkerPath(root: string): string =
  splitFile(root).dir / ExplodeOperationName

proc writeRestoreMarker(path, phase, stage, backup: string, pid: int) =
  let temporary = path & ".tmp"
  writeFile(temporary, phase & "\n" & stage & "\n" & backup & "\n" & $pid & "\n")
  moveFile(temporary, path)

proc processAlive(pid: int): bool =
  pid > 0 and fileExists("/proc/" & $pid)

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
    quit("state WINFO: restore-all transaction is active")

  # Readers wait for the short publication/cleanup window rather than
  # interpreting a temporarily absent WINFO root as missing history.
  var attempts = 0
  while dirExists(lock) and attempts < 200:
    sleep(10)
    recoverRestoreHistory(root)
    inc attempts
  if dirExists(lock):
    quit("state WINFO: restore-all transaction did not complete")

proc recoverRestoreHistory*(root: string, fromExplodeOperation = false) =
  ## Complete or discard an interrupted restore-all publication.  A live
  ## owner is left alone; only a dead owner can have left durable residue.
  if root.len == 0:
    return
  if not fromExplodeOperation:
    let operationRoot = splitFile(root).dir / "layout" / "explode"
    if fileExists(explodeOperationMarkerPath(operationRoot)):
      recoverExplodeOperation(operationRoot)
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
      quit("layout explode: transaction is already active")
    removeDir(result)
  createDir(splitFile(root).dir)
  createDir(result)
  writeFile(result / "pid", $getCurrentProcessId())

proc releaseExplodeLock*(lock: string) =
  if dirExists(lock): removeDir(lock)

proc beginExplodeState*(root: string, records: seq[ExplodeStateRecord]): ExplodeTransaction =
  result.root = root
  result.stage = root & ".stage"
  result.backup = root & ".backup"
  result.marker = explodeTxnMarkerPath(root)
  result.lock = acquireExplodeLock(root)
  if dirExists(result.stage): removeDir(result.stage)
  if dirExists(result.backup): removeDir(result.backup)
  createDir(result.stage)
  for position, record in records:
    writeGeometry(record.geometry, result.stage / align($(position + 1), 3, '0') & "=" & record.winid)
  writeRestoreMarker(result.marker, "PREPARED", result.stage, result.backup, getCurrentProcessId())
  result.active = true

proc beginExplodeStateIdentity*(root: string,
    records: seq[IdentityExplodeStateRecord]): ExplodeTransaction =
  var plain: seq[ExplodeStateRecord] = @[]
  for record in records:
    plain.add((record.winid, record.geometry))
  result = beginExplodeState(root, plain)
  for position, record in records:
    writeGeometry(record.geometry,
      result.stage / align($(position + 1), 3, '0') & "=" & record.winid,
      record.token)
  writeRestoreMarker(result.marker, "PREPARED", result.stage, result.backup,
    getCurrentProcessId())

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
    history: seq[IdentityHistoryUpdate]): ExplodeOperation =
  result.root = root
  result.marker = explodeOperationMarkerPath(root)
  result.explode = beginExplodeStateIdentity(root, records)
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

proc beginRestoreHistory*(updates: seq[RestoreHistoryUpdate]): RestoreHistoryTransaction =
  let root = getEnv("WINFO")
  if root.len == 0:
    quit("state restore-all: WINFO is not configured")
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
      quit("state restore-all: history transaction is already active")
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

  for update in updates:
    writeGeometry(update.geometry, result.stage / update.winid)

  writeRestoreMarker(
    result.marker,
    "PREPARED",
    result.stage,
    result.backup,
    getCurrentProcessId()
  )
  result.active = true

proc beginRestoreHistoryIdentity*(updates: seq[IdentityHistoryUpdate]): RestoreHistoryTransaction =
  var plain: seq[RestoreHistoryUpdate] = @[]
  for update in updates:
    plain.add((update.winid, update.geometry))
  result = beginRestoreHistory(plain)
  for update in updates:
    writeGeometry(update.geometry, result.stage / update.winid, update.token)
  # Rewrite the marker after token-bearing records are complete.
  writeRestoreMarker(result.marker, "PREPARED", result.stage, result.backup,
    getCurrentProcessId())

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
    else: query.ClientToken()

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
  prepareWinfoAccess(getEnv("WINFO"), true)
  writeGeometry(g, getEnv("WINFO") / winid, token)

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
    else: query.ClientToken()

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
  writeGeometry(g, root / align($position, 3, '0') & "=" & winid, token)

proc saveState*(root: string, position: int, winid: string) =
  saveState(root, position, winid, query.geometry(winid))

proc hasGeometryForToken*(winid: string, token: query.ClientToken,
    root: string = getEnv("WINFO")): bool
proc historyToken(root, id: string): query.ClientToken

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
    var token: query.ClientToken
    if not query.tryClientToken(id, token):
      return false
    return hasGeometryForToken(id, token, root)
  result = true

proc historyToken(root, id: string): query.ClientToken =
  let path = root / id
  var found = ""
  for kind, entry in walkDir(path):
    if kind == pcDir and extractFilename(entry).startsWith("ID="):
      if found.len > 0:
        quit("state history: duplicate identity for " & id)
      found = extractFilename(entry)[3 .. ^1]
  if found.len == 0:
    return query.ClientToken()
  try:
    result = query.parseClientToken(found)
  except ValueError:
    quit("state history: malformed identity for " & id)

proc hasGeometryForToken*(winid: string, token: query.ClientToken,
    root: string = getEnv("WINFO")): bool =
  if root == getEnv("WINFO"):
    prepareWinfoAccess(root, false)
  let path = root / winid
  if not dirExists(path):
    return false
  let stored = historyToken(root, winid)
  if not stored.isPresent or stored != token:
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

  proc fail(error: string) =
    quit("state loadGeometry: " & error)

  let path = root / id

  if not dirExists(path):
    fail("no saved geometry for window " & id)

  if validateIdentity and root == getEnv("WINFO") and id.match(re(r"^0x[0-9a-fA-F]{8}$")):
    var live: query.ClientToken
    if not query.tryClientToken(id, live):
      fail("no saved geometry for window " & id)
    let stored = historyToken(root, id)
    if not stored.isPresent or stored != live:
      fail("no saved geometry for window " & id)

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
    fail("incomplete saved geometry for window " & id)

proc loadGeometryForToken*(winid: string, token: query.ClientToken,
    root: string = getEnv("WINFO")): Geometry =
  if root == getEnv("WINFO"):
    prepareWinfoAccess(root, false)
  let path = root / winid
  if not dirExists(path):
    quit("state loadGeometry: no saved geometry for window " & winid)
  let stored = historyToken(root, winid)
  if not stored.isPresent or stored != token:
    quit("state loadGeometry: history identity mismatch for window " & winid)
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
      quit("state explode: malformed record " & item.path)
    let expected = align($(index + 1), 3, '0')
    if item.path[0 .. 2] != expected:
      quit("state explode: non-contiguous ordinal " & item.path)
    let winid = item.path[4 .. ^1]
    if not winid.match(re(r"^0x[0-9a-fA-F]{8}$")) or winid in seen:
      quit("state explode: invalid or duplicate XID " & winid)
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
      quit("state explode: malformed record " & item.path)
    let ordinal = align($expected, 3, '0')
    if item.path[0 .. 2] != ordinal:
      quit("state explode: non-contiguous ordinal " & item.path)
    let winid = item.path[4 .. ^1]
    if not winid.match(re(r"^0x[0-9a-fA-F]{8}$")):
      quit("state explode: invalid XID " & winid)
    let recordName = item.path
    let token = historyToken(root, recordName)
    if token.isPresent:
      result.add((winid, token, loadGeometry(recordName, root)))
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

  writeGeometry(
    query.geometry(id),
    getEnv("WME") / "snapshot" / id
    )

proc restore*(args: seq[string]) =
  let id =
    if args.len == 0:
      query.focusedWinid()
    else:
      args[0]

  writeGeometry(
    loadGeometry(id, getEnv("WME") / "snapshot"),
    getEnv("WINFO") / id
    )


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
    quit("unknown state action: " & verb)
