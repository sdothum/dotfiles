import std/re
import std/sequtils
import std/strutils

import constants

type
  OptionValue* = tuple
    name: string
    value: string

  ParsedArgs* = object
    positionals*: seq[string]
    flags*: seq[string]
    options*: seq[OptionValue]

proc parseArgs*(
  args: seq[string],
  valueOptions: openArray[string] = []
): ParsedArgs =
  var i = 0

  while i < args.len:
    let arg = args[i]

    if arg in valueOptions:
      if i + 1 >= args.len:
        quit(arg & " requires a value")

      result.options.add((
        name: arg,
        value: args[i + 1]
      ))

      inc i

    elif arg.startsWith("--"):
      result.flags.add(arg)

    else:
      result.positionals.add(arg)

    inc i

proc hasFlag*(args: ParsedArgs, name: string): bool =
  name in args.flags

proc optionValue*(
  args: ParsedArgs,
  name: string,
  default: string = ""
): string =
  for option in args.options:
    if option.name == name:
      return option.value

  default

proc rejectUnsupported*(
  args: ParsedArgs,
  allowedFlags: openArray[string] = [],
  allowedOptions: openArray[string] = []
) =
  for flag in args.flags:
    if flag notin allowedFlags:
      quit("unsupported option: " & flag)

  for option in args.options:
    if option.name notin allowedOptions:
      quit("unsupported option: " & option.name)

proc validateOptions*(
  rest: seq[string],
  valueOptions: openArray[string] = [],
  allowedFlags: openArray[string] = [],
  allowedOptions: openArray[string] = []
) =
  let parsed = parseArgs(rest, valueOptions)

  rejectUnsupported(
    parsed,
    allowedFlags,
    allowedOptions
  )

type
  ArgumentKind* = enum
    ArgAll,
    ArgAspect,
    ArgAxis,
    ArgCardinal,
    ArgClassname,
    ArgColumn,
    ArgColumnName,
    ArgColumns,
    ArgDelay,
    ArgDirection,
    ArgGroup,
    ArgGroupName,
    ArgLayer,
    ArgName,
    ArgPosition,
    ArgPreset,
    ArgRotate,
    ArgRow,
    ArgRowName,
    ArgRows,
    ArgSide,
    ArgSize,
    ArgSpread,
    ArgTeleport,
    ArgUndo,
    ArgWinid,
    ArgZoom

  Arguments* = object
    all*: bool
    aspect*: tuple[width, height: int]
    axis*: string
    cardinal*: string
    classname*: string
    column*: int
    columnName*: string
    columns*: int
    delay*: float
    direction*: string
    group*: int
    groupName*: string
    layer*: string
    name*: string
    position*: int
    preset*: string
    rotate*: bool
    row*: int
    rowName*: string
    rows*: int
    side*: string
    size*: tuple[width, height: int]
    spread*: bool
    teleport*: bool
    undo*: bool 
    winid*: string
    zoom*: string

proc parseArguments*(
  command: string,
  args: seq[string],
  allowed: openArray[ArgumentKind]
): Arguments =

  result.all = false
  result.aspect = (0, 0)
  result.axis = ""
  result.cardinal = ""
  result.classname = ""
  result.column = -1
  result.columnName = ""
  result.columns = -1
  result.delay = -1.0
  result.direction = ""
  result.group = -1
  result.groupName = ""
  result.name = ""
  result.position = -1
  result.preset = ""
  result.rotate = false
  result.row = -1
  result.rowName = ""
  result.rows = -1
  result.side = ""
  result.size = (0, 0)
  result.spread = false
  result.teleport = false
  result.undo = false
  result.winid = ""
  result.zoom = ""

  proc fail(error: string) =
    quit(command & ": " & error)

  var i = 0

  proc parseValue(
    value: int,
    kind: ArgumentKind,
    allowed: openArray[ArgumentKind]
  ): int =
    if kind notin allowed:
      fail(args[i] & " not allowed")

    if value != -1:
      fail(args[i] & " already specified")

    if i + 1 >= args.len:
      fail(args[i] & " requires a value")

    result =
      try: parseInt(args[i + 1])
      except ValueError: 0

    if result < 1:
      fail(args[i] & " must be > 0")

  proc parseSwitch(
    value: bool,
    kind: ArgumentKind,
    allowed: openArray[ArgumentKind]
  ): bool =
    if kind notin allowed:
      fail(args[i] & " is not supported (switch)")

    if value:
      fail(args[i] & " already specified")

    result = true

  proc parseArgument(
    value: string,
    kind: ArgumentKind,
    allowed: openArray[ArgumentKind]
  ): string =
    if kind notin allowed:
      fail(args[i] & " is not supported (argument)")

    if value != "":
      fail(value & " already specified")

    result = args[i]

  proc parseName(
    value: string,
    kind: ArgumentKind,
    allowed: openArray[ArgumentKind]
  ): string =
    if kind notin allowed:
      fail(args[i] & " not allowed")

    if value != "":
      fail(args[i] & " already specified")

    if i + 1 >= args.len:
      fail(args[i] & " requires a value")

    result = args[i + 1]

  proc parseDelay(
    value: float,
    kind: ArgumentKind,
    allowed: openArray[ArgumentKind]
  ): float =
    if kind notin allowed:
      fail(args[i] & " is not supported (delay)")

    if value != -1.0:
      fail($value & " already specified")

    result =
      try: parseFloat(args[i])
      except ValueError: 0.0

    if result == 0.0:
      fail("invalid delay value " & args[i])

  proc parsePair(
    separator: string,
    kind: ArgumentKind,
    allowed: openArray[ArgumentKind]
  ): tuple[width, height: int] =
    if kind notin allowed:
      fail(args[i] & " is not supported (pair)")

    let xy =
      try: args[i].split(separator, maxsplit = 1).map(parseInt)
      except ValueError: @[0]

    if xy.len != 2 or xy[0] < 1 or xy[1] < 1:
      fail("invalid {width}" & separator & "{height} specification")

    result = (xy[0], xy[1])

  while i < args.len:
    case args[i]
    of "--all":
      result.all = parseSwitch(result.all, ArgAll, allowed)

    of "--name":
      result.name = parseName(result.name, ArgName, allowed)
      inc i

    of "--rows":
      result.rows = parseValue(result.rows, ArgRows, allowed)
      inc i

    of "--row":
      result.row = parseValue(result.row, ArgRow, allowed)
      inc i

    of "paper", "video", A3, B4, A4, B5, A5, B6, A6, B7, "480p", "720p", "1080p", Viewport, Terminal:
      result.preset = parseArgument(result.preset, ArgPreset, allowed)

    of "--position":
      result.position = parseValue(result.position, ArgPosition, allowed)
      inc i

    of "--rotate":
      result.rotate = parseSwitch(result.rotate, ArgRotate, allowed)

    of "--smaller", "--larger":
      result.zoom = parseArgument(result.zoom, ArgZoom, allowed)

    of "--spread":
      result.spread = parseSwitch(result.spread, ArgSpread, allowed)

    of "--teleport":
      result.teleport = parseSwitch(result.teleport, ArgTeleport, allowed)

    of "--undo":
      result.undo = parseSwitch(result.undo, ArgUndo, allowed)

    # first option must be a group, columns, direction/cardinal direction, classname (with --all or --name) or size directive {X}x{Y} or {X}:{Y}
    elif i == 0:

      if ArgLayer in allowed:
        if args[i] notin [Normal, Above, Overlay, "normal", "above", "overlay"]:
          fail("layer must be normal, above or overlay")
        result.layer = parseArgument(result.layer, ArgLayer, allowed)

      elif args[i].match(re(r"^0x........$")):
        if result.winid != "" or ArgWinid notin allowed:
          fail("invalid winid")
        if not args[i].match(re(r"^0x[0-9a-fA-F]{8}$")):
          fail("invalid winid")

        result.winid = args[i]

      elif args[i].match(re(r"^[0-9]+x[0-9]+$")):
        result.size = parsePair("x", ArgSize, allowed)

      elif ':' in args[i]:
        result.aspect = parsePair(":", ArgAspect, allowed)

        if result.aspect.width == result.aspect.height:
          fail("1:1 aspect ratio")

      elif args[i].match(re(r"^[0-9.]+$")) and ArgDelay in allowed:
        result.delay = parseDelay(result.delay, ArgDelay, allowed)

      else:
        if ArgGroup in allowed or
            ArgGroupName in allowed or
            ArgColumns in allowed or
            ArgCardinal in allowed or
            ArgDirection in allowed or
            (ArgClassname in allowed and ArgAll in allowed) or
            (ArgClassname in allowed and ArgName in allowed):

          try:
            let value = parseInt(args[i])

            if ArgGroup in allowed:
              if value < 0:
                fail("group must be >= 0")

              result.group = value

            # columns
            else:
              if value < 1:
                fail("columns must be > 0")

              result.columns = value

          # group name, columns, cardinal directive or classname (with --all or --name)
          except ValueError:
            if ArgGroupName in allowed and
                result.groupName == "":

              result.groupName = args[i]

            elif ArgColumnName in allowed and
                result.columnName == "" and
                args[i] in [Left, Right, Center]:

              result.columnName = args[i]

            elif ArgCardinal in allowed and
                result.cardinal == "" and
                args[i] in [Left, Up, Right, Down, North, East, South, West]:

              result.cardinal = args[i]

            elif ArgDirection in allowed and
                result.direction == "" and
                args[i] in [Left, Top, Right, Bottom, Center, Near, Far]:

              result.direction = args[i]

            elif ArgClassname in allowed and
                result.classname == "":

              result.classname = args[i]

            else:
              fail("invalid first argument")

        else:
          fail("invalid first argument")

    # inner argument qualifiers
    elif args[i] == "":
      return  # NOTE: handle positional (blank) winid as last argument

    elif ArgWinid in allowed and
        result.winid == "" and
        args[i].match(re(r"^0x........$")):

      if not args[i].match(re(r"^0x[0-9a-fA-F]{8}$")):
        fail("invalid winid")

      result.winid = args[i]

    elif ArgColumn in allowed and
        result.column == -1:

      if i != 1:
        fail("column must be second option")

      result.column =
        try: parseInt(args[i])
        except ValueError: 0

      if result.column < 1:
        fail("column must be > 0")

    elif ArgRowName in allowed and
        result.rowName == "":

      if args[i] notin [Top, Bottom]:
        fail("invalid row specification")

      result.rowName = args[i]

    elif ArgAxis in allowed and
        result.axis == "":

      if args[i] notin [Left, Right, Horizontal, Vertical]:
        fail("invalid axis")

      result.axis = args[i]

    elif ArgSide in allowed and
        result.side == "":

      if args[i] notin [Left, Right]:
        fail("invalid side")

      result.side = args[i]

    elif ArgClassname in allowed and
        result.classname == "":

      result.classname = args[i]

    else:
      fail("undefined option")

    inc i
