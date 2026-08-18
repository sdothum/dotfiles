import std/os
import std/strutils
import std/sequtils

import cliargs
import constants
import compat
import state
import types
import window
import window_query as query

#
# Helpers
#

type
  GridAction = proc(args: seq[string])

proc grid(
  command: string,
  args: seq[string],
  action: GridAction
) =
  requireArgs(command, args, 1, 6)

  var a = parseArguments(
    command,
    args,
    [
      ArgColumns,
      ArgRows,
      ArgPosition,
      ArgClassname,
      ArgSpread
    ]
  )

  if a.rows == -1:
    a.rows = 1

  proc column(): int =
    let columnOrder =
      case a.columns
      of 1: @[1]
      of 2: @[1, 2]
      of 3: @[1, 2, 3]
      of 4: @[1, 3, 4, 2]
      of 5: @[1, 3, 4, 5, 2]
      else: toSeq(1 .. a.columns)
    if a.rows == 1:
      result = columnOrder[a.position mod a.columns]
    else:
      result = columnOrder[((a.position - 1) div a.rows + 1) mod a.columns]

  proc row(): int =
    (a.position - 1) mod a.rows + 1

  if a.rows == 1:
    action(@[$a.columns, $column()])
  else:
    action(@[
      $a.columns,
      $column(),
      "--rows", $a.rows,
      "--row", $row()
    ])

#
# Actions
#

proc level*(args: seq[string]) =
  requireNoArgs("layout level", args)
  runvArgs("layout", "level", args, 0, 0)

proc restore*(args: seq[string]) =
  requireNoArgs("layout restore", args)
  runvArgs("layout", "restore", @[], 0, 0)

proc tile*(args: seq[string]) =
  grid("tile", args, window.tile)

proc spread*(args: seq[string]) =
  grid("spread", args, window.spread)

proc fold*(args: seq[string]) =
  requireArgs("layout fold", args, 1, 6)

  var a = parseArguments(
    "layout fold",
    args,
    [
      ArgColumns,
      ArgRows,
      ArgClassname,
      ArgSpread
    ]
  )

  if a.rows == -1:
    a.rows = 1

  let action: GridAction =
    if a.spread: spread
    else: tile

  let focused = query.focusedWinid()

  let windowIds =
    if a.classname.len > 0:
      window.ids(@[a.classname]).splitLines()
    else:
      window.ids(@[]).splitLines()

  if windowIds.len == 0:
    quit("layout fold: no matching windows")

  var position = 1

  for winid in windowIds:
    runvArgs(
      "sirocco",
      "window",
      @["focus", winid],
      2,
      2
    )

    if a.rows == 1:
      action(@[
        $a.columns,
        "--position", $position
      ])
    else:
      action(@[
        $a.columns,
        "--rows", $a.rows,
        "--position", $position
      ])

    inc position

  runvArgs(
    "sirocco",
    "window",
    @["focus", focused],
    2,
    2
  )

proc explode*(args: seq[string]) =
  requireNoArgs("layout explode", args)

  let focused = query.focusedWinid()
  let windowIds = query.stack()

  if windowIds.len == 0:
    quit("layout explode: no matching windows")

  var
    columns = 1
    rows = 1

  case windowIds.len
  of 1:
    return
  of 2:
    columns = 3
  of 3:
    columns = 4
  of 4:
    columns = 3
    rows = 2
  of 5 .. 9:
    columns = 4
    rows = 3
  else:
    columns = 5
    rows = 3

  let root = getEnv("WME") / "layout" / "explode"
  removeDir(root)
  createDir(root / ("focus=" & focused))

  var position = 1

  for winid in windowIds:
    runvArgs(
      "sirocco",
      "window",
      @["focus", winid],
      2,
      2
    )

    state.saveState(root, position, winid)

    if rows == 1:
      tile(@[
        $columns,
        "--position", $position
      ])
    else:
      tile(@[
        $columns,
        "--rows", $rows,
        "--position", $position
      ])

    inc position

  runvArgs(
    "sirocco",
    "window",
    @["focus", focused],
    2,
    2
  )

proc unexplode*(args: seq[string]) =
  requireNoArgs("layout unexplode", args)

  let root = getEnv("WME") / "layout" / "explode"

  let windowIds = loadStateWinids(root)

  if windowIds.len == 0:
    quit("layout unexplode: no matching windows")

  var
    position = 1
    g: Geometry

  for winid in windowIds:
    runvArgs(
      "sirocco",
      "window",
      @["focus", winid],
      2,
      2
    )

    g = loadGeometry(align($position, 3, '0') & "=" & winid, root)

    wtp(g)

    inc position

  let focused = loadStateFocus(root)

  if focused.len > 0:
    runvArgs(
      "sirocco",
      "window",
      @["focus", focused],
      2,
      2
    )

  removeDir(root)

#
# Native Nim convenience overloads
#

proc fold*(columns: string) =
  fold(@[columns])

proc fold*(columns, classname: string) =
  fold(@[columns, classname])

proc fold*(spread, columns, classname: string) =
  fold(@[spread, columns, classname])

proc fold*(columns, rows, num, classname: string) =
  fold(@[columns, rows, num, classname])

proc fold*(stateless, columns, rows, num, classname: string) =
  fold(@[stateless, columns, rows, num, classname])

proc spread*(columns: string) =
  spread(@[columns])

proc spread*(columns, classname: string) =
  spread(@[columns, classname])

proc spread*(columns, position, classname: string) =
  spread(@[columns, position, classname])

proc spread*(columns, rows, num, classname: string) =
  spread(@[columns, rows, num, classname])

proc tile*(columns: string) =
  tile(@[columns])

proc tile*(columns, classname: string) =
  tile(@[columns, classname])

proc tile*(columns, rows, num, classname: string) =
  tile(@[columns, rows, num, classname])

#
# Dispatch
#

proc dispatch*(verb: string, rest: seq[string]) =
  case verb
  of "explode":
    explode(rest)
  of "fold":
    fold(rest)
  of "level":
    level(rest)
  of "restore":
    restore(rest)
  of "spread":
    spread(rest)
  of "tile":
    tile(rest)
  of "unexplode":
    unexplode(rest)
  else:
    quit("unknown layout action")
