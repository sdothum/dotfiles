import std/envvars
import std/os
import std/strutils

import types
import window_query as query

proc writeGeometry(g: Geometry, root: string) =
  removeDir(root)
  createDir(root)

  createDir(root / ("X=" & $g.x))
  createDir(root / ("Y=" & $g.y))
  createDir(root / ("WIDTH=" & $g.width))
  createDir(root / ("HEIGHT=" & $g.height))

proc saveGeometry*(g: Geometry, winid: string = "", precheck = true) =
  let id =
    if winid.len == 0:
      query.focusedWinid()
    else:
      winid

  # avoid losing revert history to repeated window action
  if precheck:
    let newGeometry = query.geometry(id)
    if newGeometry.x == g.x and newGeometry.y == g.y and newGeometry.width == g.width and newGeometry.height == g.height:
      return

  writeGeometry(
    g,
    getEnv("WINFO") / id
  )

proc saveGeometry*(winid: string = "") =
  let id =
    if winid.len == 0:
      query.focusedWinid()
    else:
      winid

  saveGeometry(query.geometry(id), id, false)

proc loadGeometry*(winid: string = "", root: string = getEnv("WINFO")): Geometry =
  let id =
    if winid.len == 0:
      query.focusedWinid()
    else:
      winid

  let path = root / id

  if not dirExists(path):
    quit("no saved geometry for window " & id)

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
    quit("incomplete saved geometry for window " & id)


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
