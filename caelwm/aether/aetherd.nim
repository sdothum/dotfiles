import std/os
import std/options
import std/times
import std/strutils
import zephyr_errors

import wm/snapshot_diff
import wm/title_diff
import wm/window_lifecycle
import wm/state_reconciliation
import wm/window_query
import wm/x11_invalidation
import wm/snapshot_publication
import wm/panel_notification
import wm/daemon_snapshot
import wm/x11_snapshot
import wm/daemon_ipc

import policy/rules
import policy/types as policyTypes

proc baseline(snapshot: WmSnapshot): string =
  let focused =
    if snapshot.focused.isSome: snapshot.focused.get()
    else: "NONE"
  var nullCount = 0
  for client in snapshot.clients:
    if client.group == NullGroup:
      nullCount.inc
  "BASELINE focused=" & focused &
    " current=" & $snapshot.currentGroup &
    " clients=" & $snapshot.clients.len &
    " null=" & $nullCount

proc refresh(
  event: var X11Invalidation,
  query: var X11SnapshotQuery,
  previous: var WmSnapshot,
  previousMetadata: var seq[DaemonCachedClient],
  havePrevious: var bool,
  pendingReconcile: var Option[WmSnapshot],
  ipc: var IpcServer,
  notifyBootstrap = false,
  timeoutMs = 2000
): bool =
  var current: WmSnapshot
  if not tryWmSnapshotDirect(query, current, timeoutMs):
    let stage = if query.lastFailure.len > 0: " " & query.lastFailure else: ""
    stderr.writeLine("SNAPSHOT_FAILED" & stage)
    return false
  var focused = ""
  if current.focused.isSome:
    focused = current.focused.get()
  var cachedClients: seq[DaemonCachedClient] = @[]
  var watched: seq[uint32] = @[]
  for client in current.clients:
    var instanceName = ""
    var className = ""
    var metadataAvailable = ipc.cachedMetadata(client.winid, $client.token,
      instanceName, className)
    var title = ""
    var titleAvailable = false
    var xid: uint32
    var xidValid = false
    if client.winid.len > 2 and client.winid[0 .. 1] == "0x":
      try:
        xid = parseHexInt(client.winid[2 .. ^1]).uint32
        xidValid = true
        watched.add(xid)
      except ValueError:
        discard
    if xidValid:
      if not metadataAvailable:
        metadataAvailable = query.tryWmClass(xid, instanceName, className)
      titleAvailable = query.tryWmTitle(xid, title)
    cachedClients.add(DaemonCachedClient(
      winid: client.winid,
      group: client.group,
      mapped: client.mapped,
      token: $client.token,
      instanceName: instanceName,
      className: className,
      metadataAvailable: metadataAvailable,
      title: title,
      titleAvailable: titleAvailable
    ))
  ipc.cacheSnapshot(serializeWmSnapshot(current), focused,
    current.currentGroup, cachedClients)
  event.watchClients(watched)
  if not publishWmSnapshot(current):
    stderr.writeLine("SNAPSHOT_PUBLISH_FAILED")
  if not reconcileSnapshot(current):
    stderr.writeLine("RECONCILE_FAILED")
    pendingReconcile = some(current)
  else:
    pendingReconcile = none(WmSnapshot)
  if not havePrevious:
    echo baseline(current)
    if notifyBootstrap:
      let empty = WmSnapshot(
        focused: none(string),
        currentGroup: NullGroup,
        clients: @[]
      )
      discard notifyPanels(diffSnapshots(empty, current))
    havePrevious = true
  else:
    let changes = diffSnapshots(previous, current)
    for change in changes:
      echo change.report()
      if change.kind == ClientAdded:
        for client in cachedClients:
          if client.winid != change.winid:
            continue
          if client.metadataAvailable or client.titleAvailable:
            let rule = rules.matchCreated(policyTypes.RuleClient(
              winid: client.winid,
              instanceName: client.instanceName,
              className: client.className,
              title: client.title
            ))
            if rule.isSome:
              let verb = rule.get
              echo "RULE_MATCH " & client.winid & " " & verb
              stdout.flushFile()
              try:
                rules.applyRule(verb, client.winid)
                echo "RULE_APPLIED " & client.winid & " " & verb
                stdout.flushFile()
              except ZephyrError as error:
                stderr.writeLine("RULE_FAILED " & client.winid & " " & verb & " " & error.msg)
                stderr.flushFile()
          break
    var oldTitles: seq[ObservedTitle] = @[]
    var newTitles: seq[ObservedTitle] = @[]
    for client in previousMetadata:
      oldTitles.add(ObservedTitle(winid: client.winid, token: client.token,
        title: client.title, available: client.titleAvailable))
    for client in cachedClients:
      newTitles.add(ObservedTitle(winid: client.winid, token: client.token,
        title: client.title, available: client.titleAvailable))
    for transition in diffTitleChanges(oldTitles, newTitles):
      for client in cachedClients:
        if client.winid != transition.winid or client.token != transition.token:
          continue
        let matched = rules.matchTitleChanged(policyTypes.RuleClient(
          winid: client.winid,
          instanceName: client.instanceName,
          className: client.className,
          title: transition.newTitle
        ), transition.oldTitle)
        if matched.isSome:
          let verb = matched.get
          echo "RULE_EVENT " & client.winid & " title"
          echo "RULE_MATCH " & client.winid & " " & verb & " title"
          stdout.flushFile()
          try:
            rules.applyRule(verb, client.winid)
            echo "RULE_APPLIED " & client.winid & " " & verb & " title"
            stdout.flushFile()
          except ZephyrError as error:
            stderr.writeLine("RULE_FAILED " & client.winid & " " & verb &
              " title " & error.msg)
            stderr.flushFile()
        break
    discard notifyPanels(changes)
  previous = current
  previousMetadata = cachedClients
  true

var ipc: IpcServer
while not ipc.open():
  stderr.writeLine("IPC_SOCKET_FAILED")
  sleep(1000)
stderr.writeLine("IPC_SOCKET_READY " & ipc.path)

var
  event: X11Invalidation
  lifecycle = WindowLifecycle(reconcile: true)
  query: X11SnapshotQuery
  previous: WmSnapshot
  previousMetadata: seq[DaemonCachedClient]
  havePrevious = false
  pendingReconcile: Option[WmSnapshot]
  observationReady = false
  connectedOnce = false
  notifyBootstrap = false
  lastProbe = 0.0
  snapshotTimeoutMs = 100
  nextReconnect = 0.0
  retry = true

proc loseObservation(
  event: var X11Invalidation,
  query: var X11SnapshotQuery,
  ipc: var IpcServer,
  previous: var WmSnapshot,
  havePrevious: var bool,
  pendingReconcile: var Option[WmSnapshot]
) =
  event.close()
  query.close()
  ipc.invalidateCache()
  discard clearWmSnapshot()
  havePrevious = false
  previous = WmSnapshot()
  previousMetadata.setLen(0)
  pendingReconcile = none(WmSnapshot)

proc drainLifecycle(event: var X11Invalidation): bool =
  result = event.drain(
    onDestroyed = proc(window: uint32) = lifecycle.queueDestroyed(window),
    onMapped = proc(window: uint32) = lifecycle.queueMapped(window)
  )
  if not lifecycle.service(event):
    stderr.writeLine("WINDOW_STATE_CLEANUP_DEFERRED")

while true:
  if not observationReady:
    if epochTime() < nextReconnect:
      discard ipc.service(-1)
      continue
    loseObservation(event, query, ipc, previous, havePrevious, pendingReconcile)
    # Drain one IPC readiness pass before attempting a potentially failing WM
    # attachment.  This prevents an accepted client from waiting behind XCB
    # reconnect probes while the WM is absent.
    discard ipc.service(-1)
    if not event.open():
      nextReconnect = epochTime() + 1.0
      discard ipc.service(-1)
      continue
    # Subscribe before scanning: deaths during reconciliation remain queued.
    lifecycle.reconcile = true
    if not lifecycle.service(event):
      stderr.writeLine("WINDOW_STATE_CLEANUP_DEFERRED")
    if not query.open():
      nextReconnect = epochTime() + 1.0
      discard ipc.service(-1)
      continue
    observationReady = true
    notifyBootstrap = connectedOnce
    connectedOnce = true
    retry = true

  if not lifecycle.service(event):
    stderr.writeLine("WINDOW_STATE_CLEANUP_DEFERRED")

  if retry:
    let refreshed = refresh(event, query, previous, previousMetadata, havePrevious, pendingReconcile, ipc,
      notifyBootstrap, snapshotTimeoutMs)
    notifyBootstrap = false
    lastProbe = epochTime()
    snapshotTimeoutMs = 2000
    retry = false
    if not refreshed:
      observationReady = false
      nextReconnect = epochTime() + 1.0
      # Keep the daemon's local IPC responsive while the WM is absent.  The
      # next loop will retry XCB attachment after servicing bounded clients.
      discard ipc.service(-1)
      continue
    # refresh() has now installed `previous` and completed either baseline
    # establishment or the normal diff path.  From here, later clients are
    # eligible for post-baseline ClientAdded processing.
    ipc.markReady()
    if drainLifecycle(event):
      retry = true
      continue

  if pendingReconcile.isSome:
    let invalidationReady = ipc.service(event.descriptor())
    if invalidationReady:
      if not event.healthy():
        observationReady = false
        snapshotTimeoutMs = 100
        nextReconnect = epochTime() + 1.0
      elif drainLifecycle(event):
        retry = true
      continue
    if reconcileSnapshot(pendingReconcile.get()):
      pendingReconcile = none(WmSnapshot)
    else:
      stderr.writeLine("RECONCILE_FAILED")
    continue

  let invalidationReady = ipc.service(event.descriptor())
  if invalidationReady:
    if not event.healthy():
      observationReady = false
      snapshotTimeoutMs = 100
      nextReconnect = epochTime() + 1.0
    elif drainLifecycle(event):
      retry = true
    continue
  if not event.healthy():
    stderr.writeLine("EVENT_WAIT_FAILED")
    observationReady = false
    snapshotTimeoutMs = 100
    nextReconnect = epochTime() + 1.0
    continue
  if drainLifecycle(event):
    retry = true
  elif epochTime() - lastProbe >= 1.0:
    # A WM can disappear without changing the XCB connection state.  Periodic
    # authoritative snapshots detect that case and also bootstrap a replacement
    # WM whose root properties have not generated an invalidation yet.
    snapshotTimeoutMs = 100
    retry = true
