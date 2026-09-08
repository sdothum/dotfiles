import std/os
import std/posix
import std/times

import snapshot_diff

type
  PanelRefreshTargets* = object
    desktop*: bool
    system*: bool

proc panelRefreshTargets*(changes: openArray[SnapshotChange]): PanelRefreshTargets =
  for change in changes:
    case change.kind
    of FocusChanged, CurrentChanged, ClientRemoved, ClientAdded,
       GroupChanged, MappedChanged, NullGroupChanged:
      result.desktop = true
    case change.kind
    of CurrentChanged, ClientRemoved, ClientAdded, GroupChanged, MappedChanged:
      result.system = true
    else:
      discard

proc notifyFifo(path, message: string): bool =
  let descriptor = posix.open(path.cstring, O_WRONLY or O_NONBLOCK)
  if descriptor < 0:
    return false
  let written = posix.write(descriptor, message.cstring, message.len)
  discard posix.close(descriptor)
  written == message.len

proc notifyPanels*(changes: openArray[SnapshotChange]): bool =
  let targets = panelRefreshTargets(changes)
  var success = true
  let fifoRoot = getEnv("FIFO")
  if fifoRoot.len == 0:
    return false

  if targets.desktop and not notifyFifo(fifoRoot / "desktop", "X\n"):
    success = false
  if targets.system:
    let stamp = $int(epochTime())
    if not notifyFifo(fifoRoot / "system", "S" & stamp & "\n"):
      success = false
  success
