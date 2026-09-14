import std/[os, sets, strutils]

import state
import x11_invalidation

type WindowLifecycle* = object
  pending: HashSet[string]
  reconcile*: bool

proc validWinid(winid: string): bool =
  if winid.len != 10 or not winid.startsWith("0x"):
    return false
  for character in winid[2 .. ^1]:
    if character notin {'0'..'9', 'a'..'f', 'A'..'F'}:
      return false
  true

proc clearHiddenState*(winid: string): bool =
  let root = getEnv("HIDDEN")
  if root.len == 0:
    return true
  if not validWinid(winid):
    return false
  let path = root / winid
  try:
    if symlinkExists(path) or fileExists(path):
      removeFile(path)
    elif dirExists(path):
      removeDir(path)
    true
  except CatchableError:
    false

proc queueDestroyed*(lifecycle: var WindowLifecycle, window: uint32) =
  lifecycle.pending.incl("0x" & toHex(window, 8).toLowerAscii())

proc queueMapped*(lifecycle: var WindowLifecycle, window: uint32) =
  # Both events request current-state validation, never deletion by event alone.
  lifecycle.pending.incl("0x" & toHex(window, 8).toLowerAscii())

proc hasEntry(root, winid: string): bool =
  root.len > 0 and (dirExists(root / winid) or fileExists(root / winid) or
    symlinkExists(root / winid))

proc service*(lifecycle: var WindowLifecycle, event: var X11Invalidation): bool =
  result = true
  if not lifecycle.reconcile and lifecycle.pending.len == 0:
    return true
  let winfoReady = windowStateCleanupReady()
  let winfoRoot = getEnv("WINFO")
  let hiddenRoot = getEnv("HIDDEN")
  # WINFO transactions may defer their own cleanup, but never block HIDDEN.
  var scanned = winfoReady
  for root in [winfoRoot, hiddenRoot]:
    if root.len == 0 or (root == winfoRoot and not winfoReady):
      continue
    try:
      if dirExists(root):
        for kind, path in walkDir(root):
          let winid = lastPathPart(path)
          if kind notin {pcDir, pcFile, pcLinkToDir, pcLinkToFile} or not validWinid(winid):
            continue
          if lifecycle.reconcile or winid.toLowerAscii() in lifecycle.pending:
            lifecycle.pending.incl(winid)
            if lifecycle.reconcile:
              # Also cover existing windows reparented away from the root.
              event.watchClients(@[parseHexInt(winid[2 .. ^1]).uint32])
    except CatchableError:
      scanned = false
  if scanned:
    lifecycle.reconcile = false
  else:
    result = false
  var completed: seq[string]
  for winid in lifecycle.pending:
    if not hasEntry(winfoRoot, winid) and not hasEntry(hiddenRoot, winid):
      if winfoReady:
        completed.add(winid)
      continue
    var done = true
    case event.windowVisibility(parseHexInt(winid[2 .. ^1]).uint32)
    of WindowViewable:
      done = clearHiddenState(winid)
    of WindowUnmapped:
      discard
    of VisibilityMissing:
      # Attempt both cleanups even if one fails; retries remain idempotent.
      done = clearHiddenState(winid)
      if not winfoReady or not cleanupWindowState(winid):
        done = false
    of VisibilityUnknown:
      done = false
    if done and winfoReady:
      completed.add(winid)
    else:
      result = false
  for winid in completed:
    lifecycle.pending.excl(winid)
