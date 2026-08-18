import std/envvars
import std/strutils

import cliargs
import compat
import constants
import display
import group as groups
import screen
import state
import types

import window_query as query

#
# Queries
#

proc classname*(args: seq[string]): string =
  shvArgs("window", "classname", args, 0, 0)

proc count*(args: seq[string]): string =
  shvArgs("window", "count", args, 0, 3)

proc geometry*(args: seq[string]): string =
  requireArgs("window geometry", args, 0, 1)

  let g =
    if args.len == 0:
      query.geometry()
    else:
      query.geometry(args[0])

  echo "X=" & $g.x
  echo "Y=" & $g.y
  echo "WIDTH=" & $g.width
  echo "HEIGHT=" & $g.height

proc ids*(args: seq[string]): string =
  shvArgs("window", "ids", args, 0, 3)

proc stack*(args: seq[string]): string =
  shvArgs("sirocco", "window", @["stack"] & args, 1, 2)

proc screenGeometry(): ScreenGeometry =
  result.gap = parseInt(screen.gap())
  result.margin = parseInt(screen.margin())
  result.top = parseInt(screen.top())

  result.width =
    parseInt(display.width()) - result.margin * 2

  result.height =
    parseInt(display.height()) - result.top * 2

#
# Helpers
#

proc wtp*(rect: Geometry, winid: string = "") =
  let id =
    if winid.len == 0:
      query.focusedWinid()
    else:
      winid

  runvArgs(
    "sirocco",
    "window",
    @["move", $rect.x, $rect.y, $id],
    4,
    4
  )

  runvArgs(
    "sirocco",
    "window",
    @["resize", $rect.width, $rect.height, $id],
    4,
    4
  )

#
# Actions
#

proc extend*(args: seq[string]) =
  requireArgs("window extend", args, 1, 2)

  let direction = args & @[""]
  let g = query.geometry()
  let s = screenGeometry()

  let leftWidth = g.x + g.width - s.margin
  let rightWidth = s.width - g.x + s.margin

  proc oppositeSide(): int =
    s.width + s.margin * 2 - (g.x + g.width)

  proc extendLeft() =
    wtp(Geometry(
      x: s.margin,
      y: g.y,
      width: leftWidth,
      height: g.height
    ))

  proc extendRight() =
    wtp(Geometry(
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

  proc extendErr() =
    quit(
      "invalid window extend direction: " &
      direction[0] &
      (if direction.len > 1: " " & direction[1] else: "")
    )

  case direction[0]
  of Left:
    if direction[1].len == 0:
      extendLeft()
    else:
      extendErr()

  of Right:
    if direction[1].len == 0:
      extendRight()
    else:
      extendErr()

  of "near":
    if direction[1].len == 0:
      near()
    else:
      extendErr()

  of "far":
    if direction[1].len == 0:
      far()
    else:
      extendErr()

  of Top:
    let verticalHeight = g.y + g.height - s.top

    case direction[1]
    of "":
      wtp(Geometry(
        x: g.x,
        y: s.top,
        width: g.width,
        height: verticalHeight
      ))
    of Left:
      wtp(Geometry(
        x: s.margin,
        y: s.top,
        width: leftWidth,
        height: verticalHeight
      ))
    of Right:
      wtp(Geometry(
        x: g.x,
        y: s.top,
        width: rightWidth,
        height: verticalHeight
      ))
    else:
      extendErr()

  of Bottom:
    let verticalHeight = s.height - g.y + s.top

    case direction[1]
    of "":
      wtp(Geometry(
        x: g.x,
        y: g.y,
        width: g.width,
        height: verticalHeight
      ))
    of Left:
      wtp(Geometry(
        x: s.margin,
        y: g.y,
        width: leftWidth,
        height: verticalHeight
      ))
    of Right:
      wtp(Geometry(
        x: g.x,
        y: g.y,
        width: rightWidth,
        height: verticalHeight
      ))
    else:
      extendErr()

  else:
    extendErr()

  saveGeometry(g)

proc group*(args: seq[string]) =
  requireArgs("window group", args, 0, 1)

  discard parseArguments(
    "window group",
    args,
    [ArgGroup, ArgTeleport]
  )

  runvArgs("window", "group", args, 1, 2)

proc hide*(args: seq[string]) =
  runvArgs("window", "hide", args, 0, 1)

proc restore*(args: seq[string]) =
  # runvArgs("window", "restore", args, 0, 1)
  let g = loadGeometry()
  saveGeometry()

  wtp(g)

proc shift*(args: seq[string]) =
  requireArgs("window shift", args, 1, 1)

  let g = query.geometry()
  var
    height = 0
    width = 0

  case args[0]
  of Up:
    height = -g.height
  of Down:
    height = g.height
  of Left:
    width = -g.width
  of Right:
    width = g.width
  else:
    quit("window shift expects up, down, left, or right")

  saveGeometry()

  runvArgs(
    "sirocco",
    "window",
    @["move", "--relative", $width, $height],
    4,
    4
  )

proc rotate*(args: seq[string]) =
  requireArgs("window rotate", args, 0, 0)

  let g = query.geometry()
  wtp(Geometry(
    x: g.x,
    y: g.y,
    width: g.height,
    height: g.width
  ))

  saveGeometry(g)

proc snap*(args: seq[string]) =
  requireArgs("window snap", args, 1, 2)

  let position = args & @[""]
  let g = query.geometry()
  let s = screenGeometry()

  let right = s.width - g.width + s.margin
  let verticalCenter = (s.height - g.height) div 2 + s.top
  let halfGap = s.gap div 2

  proc oppositeSide(): int =
    s.width + s.margin * 2 - (g.x + g.width)

  proc move(x, y: int) =
    runvArgs(
      "sirocco",
      "window",
      @["move", $x, $y],
      3,
      3
    )

  proc moveLeft() =
    move(s.margin, g.y)

  proc moveRight() =
    move(right, g.y)

  proc near() =
    if g.x <= oppositeSide():
      moveLeft()
    else:
      moveRight()

  proc snapErr() =
    quit(
      "invalid window snap position: " &
      position[0] &
      (if position.len > 1: " " & position[1] else: "")
    )

  case position[0]
  of Left:
    if position[1].len == 0:
      moveLeft()
    else:
      snapErr()

  of Right:
    if position[1].len == 0:
      moveRight()
    else:
      snapErr()

  of "near":
    if position[1].len == 0:
      near()
    else:
      snapErr()

  of Center:
    case position[1]
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
    else:
      snapErr()

  of Top:
    case position[1]
    of "":
      move(g.x, s.top)
    of Left:
      move(s.margin, s.top)
    of Right:
      move(right, s.top)
    else:
      snapErr()

  of Bottom:
    let bottom = s.height - g.height + s.top

    case position[1]
    of "":
      move(g.x, bottom)
    of Left:
      move(s.margin, bottom)
    of Right:
      move(right, bottom)
    else:
      snapErr()

  else:
    snapErr()

  saveGeometry(g)

proc snap*(position1, position2: string) =
  snap(@[position1, position2])

proc snap*(position: string) =
  snap(@[position])

proc size*(args: seq[string]) =
  requireArgs("window size", args, 1, 3)

  var a = parseArguments(
    "window size",
    args,
    [ArgPreset, ArgZoom, ArgRotate, ArgSize, ArgAspect]
  )

  let g = query.geometry()
  let s = screenGeometry()

  proc fail(error: string) =
    quit("window size: " & error)

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

    wtp(Geometry(
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

  proc videoSize(name: string) =
    let video = videoDimensions(name)

    wtp(Geometry(
      x: g.x,
      y: g.y,
      width: video[0],
      height: video[1]
    ))

  case args[0]
  of Monocle:
    if args.len > 1:
      fail("monocle has no options")

    wtp(Geometry(
      x: s.width div 4 + s.margin,
      y: s.top,
      width: s.width div 2,
      height: s.height
    ))

  of Terminal:
    let g = query.geometry()
    let t = loadGeometry(ClassTerm)

    wtp(Geometry(
      x: g.x,
      y: g.y,
      width: t.width,
      height: t.height
    ))

    saveGeometry(g)

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

      videoSize(size)

  of A3, B4, A4, B5, A5, B6, A6, B7:
    paperSize(
      a.preset,
      a.rotate
    )

  of "1080p", "720p", "480p":
    if args.len > 1:
      fail("invalid option")

    videoSize(a.preset)

    snap(Center)

  else:
    if 'x' in args[0]:
      if a.rotate:
        swap(a.size.width, a.size.height)

      if a.size.height > s.height:
        swap(a.size.width, a.size.height)

      wtp(Geometry(
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
        height = g.height * a.aspect.width div a.aspect.height
        width = height * a.aspect.height div a.aspect.width

      wtp(Geometry(
        x: g.x,
        y: g.y,
        width: width,
        height: height
      ))

    else:
      fail("undefined option")

  saveGeometry(g)

proc size*(size, orientation: string) =
  size(@[size, orientation])

proc size*(size: string) =
  size(@[size])

proc spread*(args: seq[string]) =
  requireArgs("window spread", args, 1, 6)

  var a = parseArguments(
    "window spread",
    args,
    [
      ArgColumns,
      ArgColumn,
      ArgColumnName,
      ArgRows,
      ArgRow,
      ArgRowName
    ]
  )

  if a.rows == -1:
    a.rows = 1

  let g = query.geometry()
  let s = screenGeometry()

  proc fail(error: string) =
    quit("window spread: " & error)

  if a.columns == -1 and a.column == -1 and a.columnName == "":
    fail("no column position specified")

  proc calculateColumns(): int =
      (s.width + s.gap) div (g.width + s.gap)

  proc centerColumn(columns: int): int =
    case getEnv("CENTER_BIAS", "right")
    of Left:
      result = (a.columns + 1) div 2
    of Right:
      result = (a.columns + 2) div 2
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

    wtp(Geometry(
      x: x,
      y: y,
      width: g.width,
      height: g.height
    ))

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

  saveGeometry(g)

proc swap*(args: seq[string]) =
  requireArgs("window swap", args, 1)

  let source = query.focusedWinid()
  let sourceGeometry = query.geometry(source)

  runvArgs(
    "sirocco",
    "window",
    @["focus", "--cardinal", args[0]],
    3,
    3
  )

  let target = query.focusedWinid()

  if target == source:
    quit("no adjacent window")

  let targetGeometry = query.geometry(target)

  wtp(targetGeometry, source)
  wtp(sourceGeometry, target)

  saveGeometry(sourceGeometry, source)
  saveGeometry(targetGeometry, target)

proc standard*(args: seq[string]) =
  runvArgs("window", "standard", args, 2, 3)

proc await*(args: seq[string]) =
  runvArgs("window", "await", args, 1, 2)

proc tile*(args: seq[string]) =
  requireArgs("window tile", args, 1, 6)

  var a = parseArguments(
    "window tile",
    args,
    [
      ArgColumns,
      ArgColumn,
      ArgColumnName,
      ArgRows,
      ArgRow,
    ]
  )

  if a.rows == -1:
    a.rows = 1

  if a.row == -1:
    a.row = 1

  let g = query.geometry()
  let s = screenGeometry()

  proc fail(error: string) =
    quit("window tile: " & error)

  case args[0]
  of Left:
      wtp(Geometry(
        x: s.margin,
        y: s.top,
        width: g.x + g.width - s.margin,
        height: s.height
      ))

  of Right:
    wtp(Geometry(
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

    wtp(Geometry(
      x: x,
      y: y,
      width: tileWidth,
      height: tileHeight
    ))

  saveGeometry(g)

proc toggle*(args: seq[string]) =
  runvArgs("window", "toggle", args, 1, 2)

#
# Native Nim convenience overloads
#

proc classname*(): string =
  classname(@[])

proc count*(): int =
  parseInt(count(@[]))

proc count*(classname: string): int =
  parseInt(count(@[classname]))

proc group*(groupname: string) =
  let groupId = groups.id(groupname)
  group(@[$groupId])

proc spread*(selector: string) =
  spread(@[selector])

proc await*(selector: string) =
  await(@[selector])

proc await*(selector, property: string) =
  await(@[selector, property])

proc tile*(side: string) =
  tile(@[side])

proc tile*(column, position: string) =
  tile(@[column, position])

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
    echo geometry(rest)
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
  of "standard":
    standard(rest)
  of "await":
    await(rest)
  of "toggle":
    toggle(rest)
  else:
    quit("unknown window action: " & verb)
