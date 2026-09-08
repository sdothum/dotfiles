import std/os

import window_query

proc publishWmSnapshot*(snapshot: WmSnapshot): bool =
  let wme = getEnv("WME")
  if wme.len == 0 or wme[0] != '/':
    return false

  let directory = wme / "wm"
  let finalPath = directory / "snapshot"
  let temporaryPath = directory / (".snapshot." & $getCurrentProcessId())
  try:
    createDir(directory)
    writeFile(temporaryPath, serializeWmSnapshot(snapshot))
    moveFile(temporaryPath, finalPath)
    result = true
  except CatchableError:
    try:
      removeFile(temporaryPath)
    except CatchableError:
      discard
    result = false

proc clearWmSnapshot*(): bool =
  let wme = getEnv("WME")
  if wme.len == 0 or wme[0] != '/':
    return false
  try:
    let path = wme / "wm" / "snapshot"
    if fileExists(path):
      removeFile(path)
    result = true
  except CatchableError:
    result = false
