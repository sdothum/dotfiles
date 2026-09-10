import std/envvars
import std/os
import std/strutils
import std/algorithm
import std/sequtils

import cliargs
import compat
import constants
import display
import group as groups
import screen
import state
import types

import window_query as query
import daemon_client

#
# Queries
#

proc classname*(args: seq[string]): string =
  requireNoArgs("window classname", args)
  query.classname(query.focusedWinid())

proc classname*(): string =
  classname(@[])

proc liveIds*(args: seq[string]): string =
  requireArgs("window ids", args, 0, 3)

  let a = parseArguments(
    "window ids",
    args,
    [
      ArgAll,
      ArgClassname,
      ArgName
    ]
  )

  if a.classname != "" and a.name != "":
    quit("window ids: only one of " & a.classname & " or --name " & a.name & " is allowed")

  if a.classname == "" and a.name == "":
    if a.all:
      shvArgs("sirocco", "window", @["ids", "--all"], 2, 2)
    else:
      shvArgs("sirocco", "window", @["ids"], 1, 1)
  elif a.classname != "":
    if a.all:
      shvArgs("sirocco", "window", @["ids", "--all", a.classname], 3, 3)
    else:
      shvArgs("sirocco", "window", @["ids", a.classname], 2, 2)
  else:
    if a.all:
      shvArgs("sirocco", "window", @["ids", "--all", "--name", a.name], 4, 4)
    else:
      shvArgs("sirocco", "window", @["ids", "--name", a.name], 3, 3)

proc cachedFilteredIds(includeAll: bool, classname, name: string): string =
  let kind = if name.len > 0: RequestQueryNameList else: RequestQueryClassList
  let pattern = if name.len > 0: name else: classname
  let reply = queryDaemonFiltered(kind, includeAll, pattern)
  if not reply.ok:
    quit("window ids: " & reply.error)
  reply.body

proc cachedIds(includeAll: bool): string =
  let reply = queryDaemonClientList()
  if not reply.ok:
    quit("window ids: " & reply.error)
  var values: seq[string] = @[]
  for client in reply.clients:
    if includeAll or client.mapped:
      values.add(client.winid)
  # Sirocco preserves its historical numeric-XID ordering for ids queries;
  # snapshot client order is WM list order and is not equivalent.
  values.sort()
  values.join("\n")

proc ids*(args: seq[string]): string =
  requireArgs("window ids", args, 0, 3)
  let a = parseArguments(
    "window ids",
    args,
    [
      ArgAll,
      ArgClassname,
      ArgName
    ]
  )
  if a.classname == "" and a.name == "":
    return cachedIds(a.all)
  if a.classname != "":
    return cachedFilteredIds(a.all, a.classname, "")
  if a.name != "":
    return cachedFilteredIds(a.all, "", a.name)
  liveIds(args)

proc ids*(arg: string): string =
  ids(@[arg])

proc ids*(): string =
  ids(@[])

proc count*(args: seq[string]): string =
  # Keep the historical argument-validation contract: count delegated to the
  # ids parser, whose diagnostics are named "window ids".
  requireArgs("window ids", args, 0, 3)
  let a = parseArguments(
    "window ids",
    args,
    [
      ArgAll,
      ArgClassname,
      ArgName
    ]
  )
  if a.classname == "" and a.name == "":
    let reply = queryDaemonClientList()
    if not reply.ok:
      quit("window count: " & reply.error)
    var total = 0
    for client in reply.clients:
      if a.all or client.mapped:
        inc total
    return $total
  let filtered = cachedFilteredIds(a.all, a.classname, a.name)
  return $filtered.splitLines().filterIt(it.len > 0).len

proc count*(classname: string): int =
  parseInt(count(@[classname]))

proc count*(): int =
  parseInt(count(@[]))

proc focus*(winid: string) =
  runvArgs(
    "sirocco",
    "window",
    @["focus", winid],
    2,
    2
  )

proc geometry*(args: seq[string]) =
  requireArgs("window geometry", args, 0, 1)

  var a = parseArguments(
    "window geometry",
    args,
    [
      ArgWinid
    ]
  )

  let g = query.geometry(a.winid)

  echo "X=" & $g.x
  echo "Y=" & $g.y
  echo "WIDTH=" & $g.width
  echo "HEIGHT=" & $g.height

proc wmGroup*(args: seq[string]) =
  requireArgs("window wm-group", args, 1, 1)

  let a = parseArguments(
    "window wm-group",
    args,
    [
      ArgWinid
    ]
  )

  echo query.wmGroup(a.winid)

proc wmGroups*(args: seq[string]) =
  requireNoArgs("window wm-groups", args)

  for entry in query.wmGroups():
    echo entry.winid & " " & $entry.group

proc snapshot*(args: seq[string]) =
  requireNoArgs("window snapshot", args)
  stdout.write(query.serializeWmSnapshot(query.cachedWmSnapshot()))

proc stack*(args: seq[string]): string =

  let a = parseArguments(
    "window stack",
    args,
    [
      ArgWinid
    ]
  )

  if args.len == 0:
    shvArgs("sirocco", "window", @["stack"], 1, 1)
  else:
    shvArgs("sirocco", "window", @["stack", a.winid], 2, 2)

proc screenGeometry*(): ScreenGeometry =
  let metrics = screen.metrics()
  let dimensions = display.dimensions()
  result.gap = metrics.gap
  result.margin = metrics.margin
  result.top = metrics.top

  result.width =
    dimensions.width - result.margin * 2

  result.height =
    dimensions.height - result.top * 2

#
# Helpers
#

proc wtp*(rect: Geometry, winid: string = "") =
  let wid =
    if winid.len == 0:
      query.focusedWinid()
    else:
      winid

  runvArgs(
    "sirocco",
    "window",
    @[
      "move", $rect.x, $rect.y, $wid,
      ".",
      "window", "resize", $rect.width, $rect.height, $wid
    ],
    10,
    10
  )

type GeometryApplication* = tuple[
  winid: string,
  geometry: Geometry
]

type CheckedGeometryApplication* = tuple[
  winid: string,
  token: query.ClientToken,
  geometry: Geometry
]

proc serializeCheckedGeometries*(entries: seq[CheckedGeometryApplication]): string

proc applyGeometries*(entries: seq[GeometryApplication]) =
  if entries.len == 0:
    quit("window apply-geometries: no geometry records")

  var body = newStringOfCap(entries.len * 64)
  for entry in entries:
    body.add(entry.winid & " " & $entry.geometry.x & " " &
      $entry.geometry.y & " " & $entry.geometry.width & " " &
      $entry.geometry.height & "\n")

  query.applyGeometriesBody(body)

proc applyGeometriesChecked*(entries: seq[CheckedGeometryApplication]) =
  if entries.len == 0:
    quit("window apply-geometries-checked: no geometry records")
  query.applyGeometriesCheckedBody(serializeCheckedGeometries(entries))

proc serializeCheckedGeometries*(entries: seq[CheckedGeometryApplication]): string =
  if entries.len == 0:
    return ""
  var body = newStringOfCap(entries.len * 120)
  for entry in entries:
    body.add(entry.winid & " " & $entry.token & " " & $entry.geometry.x & " " &
      $entry.geometry.y & " " & $entry.geometry.width & " " &
      $entry.geometry.height & "\n")
  result = body

proc raiseMany*(winids: seq[string]) =
  if winids.len == 0:
    return
  var args = @[
    "raise-many"
  ]
  args.add(winids)
  runvArgs(
    "sirocco",
    "window",
    args,
    1,
    high(int)
  )

#
# Actions
#

proc extend*(args: seq[string]) =
  requireArgs("window extend", args, 1, 3)

  let a = parseArguments(
    "window extend",
    args,
    [
      ArgDirection,
      ArgSide,
      ArgWinid
    ]
  )

  let g = query.geometry(a.winid)
  let s = screenGeometry()

  let leftWidth = g.x + g.width - s.margin
  let rightWidth = s.width - g.x + s.margin

  proc oppositeSide(): int =
    s.width + s.margin * 2 - (g.x + g.width)

  proc applyGeometry(destination: Geometry) =
    wtp(destination, a.winid)
    saveOriginalIfChanged(g, destination, a.winid)

  proc extendLeft() =
    applyGeometry(Geometry(
      x: s.margin,
      y: g.y,
      width: leftWidth,
      height: g.height
    ))

  proc extendRight() =
    applyGeometry(Geometry(
      x: g.x,
      y: g.y,
      width: rightWidth,
      height: g.height
    ))

  proc near() =
    if g.x <= oppositeSide():
      extendLeft()
    else:
      extendRight()

  proc far() =
    if g.x <= oppositeSide():
      extendRight()
    else:
      extendLeft()

  if a.direction in [Left, Right, Near, Far] and a.side != "" or a.direction == Center:
    quit("window extend: invalid direction " & a.direction & " " & a.side)

  case a.direction
  of Left:
    extendLeft()

  of Right:
    extendRight()

  of "near":
    near()

  of "far":
    far()

  of Top:
    let verticalHeight = g.y + g.height - s.top

    case a.side
    of "":
      applyGeometry(Geometry(
        x: g.x,
        y: s.top,
        width: g.width,
        height: verticalHeight
      ))
    of Left:
      applyGeometry(Geometry(
        x: s.margin,
        y: s.top,
        width: leftWidth,
        height: verticalHeight
      ))
    of Right:
      applyGeometry(Geometry(
        x: g.x,
        y: s.top,
        width: rightWidth,
        height: verticalHeight
      ))

  of Bottom:
    let verticalHeight = s.height - g.y + s.top

    case a.side
    of "":
      applyGeometry(Geometry(
        x: g.x,
        y: g.y,
        width: g.width,
        height: verticalHeight
      ))
    of Left:
      applyGeometry(Geometry(
        x: s.margin,
        y: g.y,
        width: leftWidth,
        height: verticalHeight
      ))
    of Right:
      applyGeometry(Geometry(
        x: g.x,
        y: g.y,
        width: rightWidth,
        height: verticalHeight
      ))

proc group*(args: seq[string]) =
  requireArgs("window group", args, 1, 2)

  let a = parseArguments(
    "window group",
    args,
    [
      ArgGroup,
      ArgTeleport
    ]
  )

  if a.group == 0:
    quit("window group: group 0 is reserved VOID")
  if a.group >= groups.count():
    quit("window group: invalid group id " & $a.group)

  let root = getEnv("GROUP")
  var winid = query.focusedWinid()

  if dirExists(root / $a.group / winid):
    return

  let group = groups.currentLive()
  runvArgs("sirocco", "group", @["remove", winid], 2, 2)
  removeDir(root / group / winid)
  runvArgs("sirocco", "group", @["add", $a.group, winid], 3, 3)
  createDir(root / $a.group / winid)

  let sourceFocus = (root & ":focus") / group / winid
  if dirExists(sourceFocus):
    removeDir(sourceFocus)

  if not a.teleport:
    return

  winid = groups.singleChildName(root / group)

  if winid != "":
    focus(winid)

    groups.add(@[group, winid])

proc group*(groupname: string) =
  let group = groups.id(groupname)
  group(@[$group])

proc hide*(args: seq[string]) =
  requireArgs("window hide", args, 0, 1)

  var a = parseArguments(
    "window hide",
    args,
    [
      ArgWinid
    ]
  )

  if a.winid == "":
    a.winid = query.focusedWinid()

  if a.winid == "":
    return

  var group = ""
  let groupRoot = getEnv("GROUP")

  for g in 1 ..< groups.count():
    if dirExists(groupRoot / $g / a.winid):
      group = $g
      break

  if group == "":
    group = groups.currentLive()

  let targetClassname = query.classname(a.winid)

  runvArgs(
    "sirocco",
    "window",
    @["hide", a.winid],
    2,
    2
  )

  let hiddenPath = getEnv("HIDDEN") / a.winid
  removeDir(hiddenPath)
  createDir(hiddenPath / group & ":" & targetClassname)

  focus("--last")


proc restore*(args: seq[string]) =
  requireArgs("window restore", args, 0, 1)

  var a = parseArguments(
    "window restore",
    args,
    [
      ArgWinid
    ]
  )

  if a.winid == "":
    a.winid = query.focusedWinid()

  if a.winid == "":
    return

  var token: query.ClientToken
  if not query.tryClientToken(a.winid, token):
    return
  if not hasGeometryForToken(a.winid, token):
    return

  let g = loadGeometryForToken(a.winid, token)
  let source = query.geometry(a.winid)
  applyGeometriesChecked(@[(a.winid, token, g)])
  saveGeometryWithToken(source, a.winid, token)

proc restore*(winid: string) =
  restore(@[winid])

proc shift*(args: seq[string]) =
  requireArgs("window shift", args, 1, 2)

  var a = parseArguments(
    "window shift",
    args,
    [
      ArgCardinal,
      ArgWinid
    ]
  )

  # Resolve the implicit target once and carry it through the mutation.  The
  # geometry query already addresses this focused client; forwarding an empty
  # XID would make the WM treat the subsequent move as implicit and bypass
  # explicit-geometry crossing suppression.
  if a.winid == "":
    a.winid = query.focusedWinid()

  let g = query.geometry(a.winid)
  var
    height = 0
    width = 0

  case a.cardinal
  of Up:
    height = -g.height
  of Down:
    height = g.height
  of Left:
    width = -g.width
  of Right:
    width = g.width

  runvArgs(
    "sirocco",
    "window",
    @["move", "--relative", $width, $height, a.winid],
    5,
    5
  )

  # Relative movement can first reset WM-owned special state, so its final
  # rectangle is not always derivable from the source rectangle alone.
  saveGeometry(g, a.winid)

proc rotate*(args: seq[string]) =
  requireArgs("window rotate", args, 0, 1)

  let a = parseArguments(
    "window rotate",
    args,
    [
      ArgWinid
    ]
  )

  let g = query.geometry(a.winid)

  let destination = Geometry(
    x: g.x,
    y: g.y,
    width: g.height,
    height: g.width
  )

  wtp(destination, a.winid)
  saveOriginalIfChanged(g, destination, a.winid)

proc snap*(args: seq[string], providedScreen = ScreenGeometry()) =
  requireArgs("window snap", args, 1, 3)

  let a = parseArguments(
    "window snap",
    args,
    [
      ArgDirection,
      ArgAxis,
      ArgWinid
    ]
  )

  let g = query.geometry(a.winid)
  let s =
    if providedScreen.width == 0:
      screenGeometry()
    else:
      providedScreen

  let right = s.width - g.width + s.margin
  let verticalCenter = (s.height - g.height) div 2 + s.top
  let halfGap = s.gap div 2

  proc oppositeSide(): int =
    s.width + s.margin * 2 - (g.x + g.width)

  proc move(x, y: int) =
    let destination = Geometry(
      x: x,
      y: y,
      width: g.width,
      height: g.height
    )

    if a.winid != "":
      runvArgs(
        "sirocco",
        "window",
        @["move", $x, $y, a.winid],
        4,
        4
      )
    else:
      runvArgs(
        "sirocco",
        "window",
        @["move", $x, $y],
        3,
        3
      )

    if destination == g:
      # A move can reset WM-owned special state even at unchanged coordinates.
      saveGeometry(g, a.winid)
    else:
      saveOriginalIfChanged(g, destination, a.winid)

  proc moveLeft() =
    move(s.margin, g.y)

  proc moveRight() =
    move(right, g.y)

  proc near() =
    if g.x <= oppositeSide():
      moveLeft()
    else:
      moveRight()

  proc fail() =
    quit("window snap: invalid position: " & a.direction & " " & a.axis)

  if a.direction in [Left, Right, Near] and a.axis != "":
    fail()

  case a.direction
  of Left:
    moveLeft()

  of Right:
    moveRight()

  of "near":
    near()

  of Center:
    case a.axis
    of "":
      move((s.width - g.width) div 2 + s.margin, verticalCenter)
    of Left:
      move(s.width div 2 + s.margin - g.width - halfGap, g.y)
    of Right:
      move(s.width div 2 + s.margin + halfGap, g.y)
    of "horizontal":
      move((s.width - g.width) div 2 + s.margin, g.y)
    of "vertical":
      move(g.x, verticalCenter)

  of Top:
    case a.axis
    of "":
      move(g.x, s.top)
    of Left:
      move(s.margin, s.top)
    of Right:
      move(right, s.top)
    else:
      fail()

  of Bottom:
    let bottom = s.height - g.height + s.top

    case a.axis
    of "":
      move(g.x, bottom)
    of Left:
      move(s.margin, bottom)
    of Right:
      move(right, bottom)
    else:
      fail()

proc snap*(position1, position2, winid: string) =
  snap(@[position1, position2, winid])

proc snap*(position, argument: string) =
  snap(@[position, argument])

proc snap*(position: string) =
  snap(@[position])

proc size*(args: seq[string]) =
  requireArgs("window size", args, 1, 4)

  var a = parseArguments(
    "window size",
    args,
    [
      ArgAspect,
      ArgPreset,
      ArgRotate,
      ArgSize,
      ArgZoom,
      ArgWinid
    ]
  )

  if a.winid == "":
    a.winid = query.focusedWinid()

  let g = query.geometry(a.winid)
  let s = screenGeometry()

  proc fail(error: string) =
    quit("window size: " & error)

  proc applyGeometry(destination: Geometry) =
    wtp(destination, a.winid)
    saveOriginalIfChanged(g, destination, a.winid)

  proc paperDimensions(name: string): array[2, int] =
    case name
    of A3: result = [1334, 1890]
    of B4: result = [1123, 1587]
    of A4: result = [945, 1334]
    of B5: result = [794, 1123]
    of A5: result = [665, 945]
    of B6: result = [559, 794]
    of A6: result = [472, 665]
    of B7: result = [397, 559]
    else:
      fail("unknown paper size " & name)

  proc paperArea(name: string): int =
    let size = paperDimensions(name)
    size[0] * size[1]

  proc paperSize(name: string, rotate = false) =
    var paper = paperDimensions(name)

    if rotate:
      swap(paper[0], paper[1])

    applyGeometry(Geometry(
      x: g.x,
      y: g.y,
      width: paper[0],
      height: paper[1]
    ))

  proc videoDimensions(name: string): array[2, int] =
    case name
    of "1080p": result = [1920, 1080]
    of "720p": result = [1280, 720]
    of "480p": result = [720, 480]
    else:
      fail("unknown video size " & name)

  proc videoArea(name: string): int =
    let size = videoDimensions(name)
    size[0] * size[1]

  proc videoSize(name: string, centerHorizontal = false, centerVertical = false) =
    let video = videoDimensions(name)
    let x =
      if centerHorizontal:
        (s.width - video[0]) div 2 + s.margin
      else:
        g.x
    let y =
      if centerVertical:
        (s.height - video[1]) div 2 + s.top
      else:
        g.y

    applyGeometry(Geometry(
      x: x,
      y: y,
      width: video[0],
      height: video[1]
    ))

  case args[0]
  of Viewport:
    if a.rotate or a.zoom != "":
      fail("viewport has no options")

    applyGeometry(Geometry(
      x: s.width div 4 + s.margin,
      y: s.top,
      width: s.width div 2,
      height: s.height
    ))

  # NOTE: Terminal is a special case requiring saving the revert geometry immediately
  of Terminal:
    saveGeometry(g, a.winid, false)

    let t = loadGeometry(ClassTerm)

    wtp(Geometry(
      x: g.x,
      y: g.y,
      width: t.width,
      height: t.height
    ), a.winid)

    quit(0)

  of "paper", "video":
    if a.zoom == "":
      fail("missing --larger/--smaller zoom")

    let area = g.width * g.height

    case a.preset
    of "paper":
      var rotate = false
      let size =
        if g.height > g.width:  # portrait
          if a.zoom == "--larger":
            if area >= paperArea(B5): A4
            elif area >= paperArea(A5): B5
            elif area >= paperArea(B6): A5
            elif area >= paperArea(A6): B6
            elif area >= paperArea(B7): A6
            else: B7
          else:                 # "--smaller"
            if area <= paperArea(A6): B7
            elif area <= paperArea(B6): A6
            elif area <= paperArea(A5): B6
            elif area <= paperArea(B5): A5
            elif area <= paperArea(A4): B5
            else: A4
        else:                   # landscape
          rotate = true
          if a.zoom == "--larger":
            if area >= paperArea(B4): A3
            elif area >= paperArea(A4): B4
            elif area >= paperArea(B5): A4
            elif area >= paperArea(A5): B5
            elif area >= paperArea(B6): A5
            elif area >= paperArea(A6): B6
            elif area >= paperArea(B7): A6
            else: B7
          else:                 # "--smaller"
            if area <= paperArea(A6): B7
            elif area <= paperArea(B6): A6
            elif area <= paperArea(A5): B6
            elif area <= paperArea(B5): A5
            elif area <= paperArea(A4): B5
            elif area <= paperArea(B4): A4
            elif area <= paperArea(A3): B4
            else: A3

      paperSize(size, rotate)

    of "video":
      let size =
        if a.zoom == "--larger":
          if area >= videoArea("720p"): "1080p"
          elif area >= videoArea("480p"): "720p"
          else: "480p"
        else:         # "--smaller"
          if area <= videoArea("720p"): "480p"
          elif area <= videoArea("1080p"): "720p"
          else: "1080p"

      videoSize(size, centerVertical = true)

  of A3, B4, A4, B5, A5, B6, A6, B7:
    paperSize(
      a.preset,
      a.rotate
    )

  of "1080p", "720p", "480p":
    if a.rotate or a.zoom != "":
      fail("invalid option")

    videoSize(a.preset, centerHorizontal = true, centerVertical = true)

  else:
    if 'x' in args[0]:
      if a.rotate:
        swap(a.size.width, a.size.height)

      if a.size.height > s.height:
        swap(a.size.width, a.size.height)

      applyGeometry(Geometry(
        x: g.x,
        y: g.y,
        width: a.size.width,
        height: a.size.height
      ))

    elif ':' in args[0]:
      var width, height: int

      if a.aspect.width > a.aspect.height:
        width = g.width * a.aspect.width div a.aspect.height
        height = width * a.aspect.height div a.aspect.width
      else:
        height = g.height
        width = height * a.aspect.width div a.aspect.height

      applyGeometry(Geometry(
        x: g.x,
        y: g.y,
        width: width,
        height: height
      ))

    else:
      fail("undefined option")


proc size*(size, orientation: string) =
  size(@[size, orientation])

proc size*(size: string) =
  size(@[size])

proc spread*(
  args: seq[string],
  providedScreen = ScreenGeometry(),
  providedGeometry = Geometry()
) =
  requireArgs("window spread", args, 1, 7)

  var a = parseArguments(
    "window spread",
    args,
    [
      ArgColumns,
      ArgColumn,
      ArgColumnName,
      ArgRows,
      ArgRow,
      ArgRowName,
      ArgWinid
    ]
  )

  if a.rows == -1:
    a.rows = 1

  let g =
    if providedGeometry.width == 0:
      query.geometry(a.winid)
    else:
      providedGeometry
  let s =
    if providedScreen.width == 0:
      screenGeometry()
    else:
      providedScreen

  proc fail(error: string) =
    quit("window spread: " & error)

  if a.columns == -1 and a.column == -1 and a.columnName == "":
    fail("no column position specified")

  proc calculateColumns(): int =
      (s.width + s.gap) div (g.width + s.gap)

  proc centerColumn(columns: int): int =
    case getEnv("CENTER_BIAS", "right")
    of Left:
      result = (columns + 1) div 2
    of Right:
      result = (columns + 2) div 2
    else:
      fail("CENTER_BIAS expects left or right")

  proc setColumn() =
    case a.columnName:
    of Left:
      a.column = 1
    of Right:
      a.column = a.columns
    of Center:
      a.column = centerColumn(a.columns)

    if a.column < 1 or a.column > a.columns:
      fail("column out of range")

  proc setRow() =
    if a.row == -1:
      case a.rowName:
      of "", Top:
        a.row = 1
      else:  # Bottom
        a.row = a.rows

    if a.row < 1 or a.row > a.rows:
      fail("row out of range")

    if s.height < a.rows * g.height + (a.rows - 1) * s.gap:
      fail("window exceeds row height")

  proc spreadGeometry() =
    setRow()
    setColumn()

    let spreadWidth =
      (s.width - (a.columns - 1) * s.gap) div a.columns

    let spreadHeight =
      (s.height - (a.rows - 1) * s.gap) div a.rows

    let x =
      spreadWidth * (a.column - 1) +
      s.margin +
      (a.column - 1) * s.gap +
      (spreadWidth - g.width) div 2

    let y =
      spreadHeight * (a.row - 1) +
      s.top +
      (a.row - 1) * s.gap +
      (spreadHeight - g.height) div 2

    let destination = Geometry(
      x: x,
      y: y,
      width: g.width,
      height: g.height
    )

    wtp(destination, a.winid)
    saveOriginalIfChanged(g, destination, a.winid)

  case args[0]
  # spread left/right/center ...
  of Left, Right, Center:
    a.columns = calculateColumns()

    spreadGeometry()

  else:
    # spread column ... NOTE: one numeric operand means column of auto-sized grid
    if a.column == -1 and a.columnName == "":
      a.column = a.columns
      if a.column < 1:
        fail("column must be >= 1")

      a.columns = calculateColumns()

      spreadGeometry()

    # spread columns column/left/right/center ...
    else:
      if a.columns < 1:
        fail("columns must be >= 1")

      if a.column > a.columns:
        fail("column must be <= " & $a.columns)

      if a.columns > calculateColumns():
        fail("window exceeds column width")

      spreadGeometry()

proc spread*(selector: string) =
  spread(@[selector])

proc swap*(args: seq[string]) =
  requireArgs("window swap", args, 1)

  proc fail(error: string) =
    quit("window swap: " & error)

  let a = parseArguments(
    "window swap",
    args,
    [
      ArgCardinal
    ]
  )

  if a.cardinal == "":
    fail("missing cardinal direction")

  let source = query.focusedWinid()
  let sourceGeometry = query.geometry(source)

  runvArgs(
    "sirocco",
    "window",
    @["focus", "--cardinal", a.cardinal],
    3,
    3
  )

  let target = query.focusedWinid()

  if target == source:
    fail("no adjacent window")

  let targetGeometry = query.geometry(target)

  wtp(targetGeometry, source)
  wtp(sourceGeometry, target)

  saveGeometry(sourceGeometry, source)
  saveGeometry(targetGeometry, target)

proc await*(args: seq[string]) =
  requireArgs("window await", args, 1, 2)

  proc fail(error: string) =
    quit("window await: " & error)

  let a = parseArguments(
    "window await",
    args,
    [
      ArgClassname,
      ArgDelay,
      ArgName
    ]
  )

  # `--name PATTERN` occupies two CLI arguments but is itself the await
  # selector; do not treat it as the legacy two-parameter form.
  if args.len == 2 and a.name == "":
    if a.delay != -1.0 or a.classname != "":
      fail("multiple parameters not allowed")

  elif a.delay > 0.0:
    sleep((a.delay * 1000).int)

  elif a.classname != "":
    let reply = waitForClass(a.classname)
    if not reply.ok:
      fail(reply.error)
    let winids = reply.body.splitLines().filterIt(it.len > 0)
    if winids.len == 0:
      fail("could not sync " & a.classname)
    if winids.len > 1:
      fail("indeterminate window")
    if statusvArgs(
        "sirocco",
        "window",
        @["focus", winids[0]],
        2,
        2
    ) != 0:
      fail("could not focus " & winids[0])

  elif a.name != "":
    let reply = waitForName(a.name)
    if not reply.ok:
      if reply.code == ErrorTimeout:
        quit("could not sync --name " & a.name)
      quit("window await: " & reply.error)
    let winids = reply.body.splitLines().filterIt(it.len > 0)
    if winids.len == 0:
      quit("could not sync --name " & a.name)
    if winids.len > 1:
      quit("indeterminate window")
    discard statusvArgs("sirocco", "window", @["focus", winids[0]], 2, 2)

proc await*(selector, property: string) =
  await(@[selector, property])

proc await*(selector: string) =
  await(@[selector])

proc tile*(
  args: seq[string],
  providedScreen = ScreenGeometry(),
  providedGeometry = Geometry()
) =
  requireArgs("window tile", args, 1, 7)

  var a = parseArguments(
    "window tile",
    args,
    [
      ArgColumns,
      ArgColumn,
      ArgColumnName,
      ArgRows,
      ArgRow,
      ArgWinid
    ]
  )

  if a.rows == -1:
    a.rows = 1

  if a.row == -1:
    a.row = 1

  let g =
    if providedGeometry.width == 0:
      query.geometry(a.winid)
    else:
      providedGeometry
  let s =
    if providedScreen.width == 0:
      screenGeometry()
    else:
      providedScreen

  proc fail(error: string) =
    quit("window tile: " & error)

  proc applyGeometry(destination: Geometry) =
    wtp(destination, a.winid)
    saveOriginalIfChanged(g, destination, a.winid)

  case args[0]
  of Left:
      applyGeometry(Geometry(
        x: s.margin,
        y: s.top,
        width: g.x + g.width - s.margin,
        height: s.height
      ))

  of Right:
    applyGeometry(Geometry(
    x: g.x,
    y: s.top,
    width: s.width - g.x + s.margin,
    height: s.height
    ))

  else:
    # unused columnName check
    if a.columnName == Center:
      fail("invalid column")

    if a.columns < 1:
      fail("columns must be >= 1")

    if a.column == -1:
      a.column = a.columns
    elif a.column < 1 or a.column > a.columns:
      fail("column out of range")

    if a.rows < 1:
      fail("rows must be >= 1")

    if a.row < 1 or a.row > a.rows:
      fail("row out of range")

    let tileWidth =
      (s.width - (a.columns - 1) * s.gap) div a.columns

    let tileHeight =
      (s.height - (a.rows - 1) * s.gap) div a.rows

    let x =
      tileWidth * (a.column - 1) +
      s.margin +
      (a.column - 1) * s.gap

    let y =
      tileHeight * (a.row - 1) +
      s.top +
      (a.row - 1) * s.gap

    applyGeometry(Geometry(
      x: x,
      y: y,
      width: tileWidth,
      height: tileHeight
    ))

proc tile*(columns, position: string) =
  tile(@[columns, position])

proc tile*(side: string) =
  tile(@[side])

proc toggle*(args: seq[string]) =
  requireArgs("window toggle", args, 1, 2)

  let a = parseArguments(
    "window toggle",
    args,
    [
      ArgClassname,
      ArgName,
    ]
  )

  let winids =
    if a.classname != "":
      shvArgs("sirocco", "window", @["ids", "--all", a.classname], 3, 3)
    else:
      shvArgs("sirocco", "window", @["ids", "--all", "--name", a.name], 4, 4)

  if winids == "":
    quit(1)

  for winid in winids.splitLines():
    let retcode =
      statusvArgs("sirocco", "window", @["hide", winid], 2, 2)

    if retcode != 0:
      runvArgs("sirocco", "window", @["focus", winid], 2, 2)

#
# Dispatch
#

proc dispatch*(verb: string, rest: seq[string]) =
  case verb
  of "classname":
    echo classname(rest)
  of "count":
    echo count(rest)
  of "extend":
    extend(rest)
  of "geometry":
    geometry(rest)
  of "wm-group":
    wmGroup(rest)
  of "wm-groups":
    wmGroups(rest)
  of "snapshot":
    snapshot(rest)
  of "group":
    group(rest)
  of "hide":
    hide(rest)
  of "ids":
    echo ids(rest)
  of "stack":
    echo stack(rest)
  of "restore":
    restore(rest)
  of "rotate":
    rotate(rest)
  of "shift":
    shift(rest)
  of "size":
    size(rest)
  of "snap":
    snap(rest)
  of "spread":
    spread(rest)
  of "tile":
    tile(rest)
  of "swap":
    swap(rest)
  of "await":
    await(rest)
  of "toggle":
    toggle(rest)
  else:
    quit("unknown window action: " & verb)
