import std/strutils
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

#
# Queries
#

proc classname*(args: seq[string]): string =
  shvArgs("window", "classname", args, 0, 0)

proc count*(args: seq[string]): string =
  shvArgs("window", "count", args, 0, 3)

proc ids*(args: seq[string]): string =
  shvArgs("window", "ids", args, 0, 3)

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
  of "up":
    height = -g.height
  of "down":
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

  of "center":
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

  let format = args & @[""]
  let g = query.geometry()
  let s = screenGeometry()

  proc sizeErr(detail: string = "") =
    quit(
      "invalid window size format: " &
      format[0] &
      (if format.len > 1: " " & format[1] else: "") &
      (if detail.len > 0: " (" & detail & ")" else: "")
    )

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
      sizeErr("unknown paper size " & name)

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
      sizeErr("unknown video size " & name)

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

  case format[0]
  of "monocle":
    if format[1] != "":
      sizeErr()

    wtp(Geometry(
      x: s.width div 4 + s.margin,
      y: s.top,
      width: s.width div 2,
      height: s.height
    ))

  of "term":
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
    if format[1] == "":
      sizeErr()

    let area = g.width * g.height

    case format[0]
    of "paper":
      var rotate = false
      let size =
        if g.height > g.width:  # portrait
          if format[1] == "--larger":
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
          if format[1] == "--larger":
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
        if format[1] == "--larger":
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
      format[0],
      rotate = format[1] == "--rotate"
    )

  of "1080p", "720p", "480p":
    if format[1] != "":
      sizeErr()

    videoSize(format[0])

    snap(Center)

  else:
    if 'x' in format[0]:
      proc parseSize(size: string): tuple[width, height: int] =
        let parts = try: size.split("x", maxsplit = 1).map(parseInt)
        except ValueError:
          @[0]

        if parts.len != 2:
          sizeErr()

        if format[1] == "":
          result = (parts[0], parts[1])
        else:
          result = (parts[1], parts[0])

      var size = parseSize(format[0])

      if size.height > s.height:
        swap(size.width, size.height)

      wtp(Geometry(
        x: g.x,
        y: g.y,
        width: size.width,
        height: size.height
      ))

    elif ':' in format[0]:
      proc parseRatio(ratio: string): tuple[width, height: int] =
        let parts = try: ratio.split(":", maxsplit = 1).map(parseInt)
        except ValueError:
          @[0]

        if parts.len != 2:
          sizeErr()
        if parts[0] == parts[1]:
          sizeErr()

        if parts[0] > parts[1]:
          result.width = g.width * parts[0] div parts[1]
          result.height = result.width * parts[1] div parts[0]
        else:
          result.height = g.height * parts[0] div parts[1]
          result.width = result.height * parts[1] div parts[0]

      let size = parseRatio(format[0])

      wtp(Geometry(
        x: g.x,
        y: g.y,
        width: size.width,
        height: size.height
      ))

    else:
      sizeErr()

  saveGeometry(g)

proc size*(size, orientation: string) =
  size(@[size, orientation])

proc size*(size: string) =
  size(@[size])

proc spread*(args: seq[string]) =
  runvArgs("window", "spread", args, 1, 6)

proc swap*(args: seq[string]) =
  runvArgs("window", "swap", args, 1, 1)

proc standard*(args: seq[string]) =
  runvArgs("window", "standard", args, 2, 3)

proc await*(args: seq[string]) =
  runvArgs("window", "await", args, 1, 2)

proc tile*(args: seq[string]) =
  requireArgs("window tile", args, 1, 6)

  let g = query.geometry()
  let s = screenGeometry()

  proc tileErr(detail: string = "") =
    quit(
      "invalid window tile position: " &
      args[0] &
      (if args.len > 1: " " & args[1 .. ^1].join(" ") else: "") &
      (if detail.len > 0: " (" & detail & ")" else: "")
    )

  var
    columns = 0
    column = -1
    rows = 1
    row = 1
    i = 0

  while i < args.len:
    case args[i]
    of Left, Right:
      if args.len > 1:
        tileErr()

      inc i

    of "--rows":
      rows = try: parseInt(args[i + 1])
      except ValueError:
        0
      i += 2

    of "--row":
      row = try: parseInt(args[i + 1])
      except ValueError:
        0
      i += 2

    else:
      if columns == 0:
        columns = try: parseInt(args[i])
        except ValueError:
          0
      elif column == 0:
        column = try: parseInt(args[i])
        except ValueError:
          0
      else:
        tileErr()

      inc i  # defaults unless overwritten

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
    if columns < 1:
      tileErr("columns must be >= 1")

    if column == -1:
      column = columns
    elif column < 1 or column > columns:
      tileErr("column out of range")

    if rows < 1:
      tileErr("rows must be >= 1")

    if row < 1 or row > rows:
      tileErr("row out of range")

    let tileWidth =
      (s.width - (columns - 1) * s.gap) div columns

    let tileHeight =
      (s.height - (rows - 1) * s.gap) div rows

    let x =
      tileWidth * (column - 1) +
      s.margin +
      (column - 1) * s.gap

    let y =
      tileHeight * (row - 1) +
      s.top +
      (row - 1) * s.gap

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
    requireArgs("window geometry", rest, 0, 1)

    let g =
      if rest.len == 0:
        query.geometry()
      else:
        query.geometry(rest[0])

    echo "X=" & $g.x
    echo "Y=" & $g.y
    echo "WIDTH=" & $g.width
    echo "HEIGHT=" & $g.height

  of "group":
    let parsed = parseArgs(rest)

    rejectUnsupported(
      parsed,
      allowedFlags = ["--teleport"]
    )

    group(rest)

  of "hide":
    hide(rest)
  of "ids":
    echo ids(rest)
  of "restore":
    restore(rest)
  of "rotate":
    rotate(rest)
  of "shift":
    shift(rest)
  of "size":
    let parsed = parseArgs(rest)

    rejectUnsupported(
      parsed,
      allowedFlags = ["--", "--larger", "--smaller", "--rotate"]
    )

    let larger = hasFlag(parsed, "--larger")
    let smaller = hasFlag(parsed, "--smaller")

    if parsed.positionals.len > 0 and
       parsed.positionals[0] in ["paper", "video"]:
      if larger == smaller:
        quit("window size " & parsed.positionals[0] &
             " requires exactly one of --larger or --smaller")

    size(rest)

  of "snap":
    snap(rest)

  of "spread", "tile":
    validateOptions(
      rest,
      # `window -- <verb> ...` preserves prior window geometry SEE: nimctlr.nim
      valueOptions = ["--", "--rows", "--row"],
      allowedOptions = ["--", "--rows", "--row"]
    )

    case verb
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
