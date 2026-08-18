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
    ArgGroup,
    ArgColumns,
    ArgColumn,
    ArgColumnName,
    ArgRows,
    ArgRow,
    ArgRowName,
    ArgPosition,
    ArgClassname,
    ArgSpread,
    ArgTeleport,
    ArgPreset,
    ArgRotate,
    ArgZoom,
    ArgSize,
    ArgAspect,
    ArgUndo

  Arguments* = object
    group*: int
    columns*: int
    column*: int
    columnName*: string
    rows*: int
    row*: int
    rowName*: string
    position*: int
    classname*: string
    spread*: bool
    teleport*: bool
    preset*: string
    rotate*: bool
    zoom*: string
    size*: tuple[width, height: int]
    aspect*: tuple[width, height: int]
    undo*: bool 

proc parseArguments*(
  command: string,
  args: seq[string],
  allowed: openArray[ArgumentKind]
): Arguments =

  result.columns = -1
  result.column = -1
  result.columnName = ""
  result.rows = -1
  result.row = -1
  result.rowName = ""
  result.position = -1
  result.classname = ""
  result.spread = false
  result.teleport = false
  result.preset = ""
  result.rotate = false
  result.zoom = ""
  result.size = (0, 0)
  result.aspect= (0, 0)
  result.undo = false

  proc fail(error: string) =
    quit(command & ": " & error)

  var i = 0

  proc parseValue(
    kind: ArgumentKind,
    allowed: openArray[ArgumentKind]
  ): int =
    if kind notin allowed:
      fail(args[i] & " not allowed")

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
      fail(args[i] & " is not supported")

    if value:
      fail(args[i] & " already specified")

    result = true

  proc parseArgument(
    value: string,
    kind: ArgumentKind,
    allowed: openArray[ArgumentKind]
  ): string =
    if kind notin allowed:
      fail(args[i] & " is not supported")

    if value != "":
      fail(value & " already specified")

    result = args[i]

  while i < args.len:
    case args[i]
    of "--rows":
      result.rows = parseValue(ArgRows, allowed)
      i += 2

    of "--row":
      result.row = parseValue(ArgRow, allowed)
      i += 2

    of "--position":
      result.position = parseValue(ArgPosition, allowed)
      i += 2

    of "--spread":
      result.spread = parseSwitch(result.spread, ArgSpread, allowed)
      inc i

    of "--teleport":
      result.teleport = parseSwitch(result.teleport, ArgTeleport, allowed)
      inc i

    of "paper", "video", A3, B4, A4, B5, A5, B6, A6, B7, "480p", "720p", "1080p", Monocle, Terminal:
      result.preset = parseArgument(result.preset, ArgPreset, allowed)
      inc i

    of "--rotate":
      result.rotate = parseSwitch(result.rotate, ArgRotate, allowed)
      inc i

    of "--smaller", "--larger":
      result.zoom = parseArgument(result.zoom, ArgZoom, allowed)
      inc i

    of "--undo":
      result.undo = parseSwitch(result.undo, ArgUndo, allowed)
      inc i

    else:
      # if not a preset formatting instruction..
      # first option must be a group, columns or size directive {X}x{Y} or {X}:{Y}
      if i == 0:

        proc parsePair(
          separator: string,
          kind: ArgumentKind,
          allowed: openArray[ArgumentKind]
        ): tuple[width, height: int] =
          if kind notin allowed:
            fail(args[i] & " is not supported")

          let xy =
            try: args[i].split(separator, maxsplit = 1).map(parseInt)
            except ValueError: @[0]

          if xy.len != 2 or xy[0] < 1 or xy[1] < 1:
            fail("invalid {width}" & separator & "{height} specification")

          result = (xy[0], xy[1])

        if 'x' in args[0]:
          result.size = parsePair("x", ArgSize, allowed)

        elif ':' in args[0]:
          result.aspect = parsePair(":", ArgAspect, allowed)

          if result.aspect.width == result.aspect.height:
            fail("1:1 aspect ratio")

        else:
          # group or columns
          if ArgGroup in allowed or ArgColumns in allowed:
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

            except ValueError:
              if ArgColumnName in allowed and
                 args[i] in [Left, Right, Center]:
                result.columnName = args[i]
              else:
                fail("invalid column specification")

          else:
            fail("invalid first argument")

      elif result.column == -1 and ArgColumn in allowed:
        if i != 1:
          fail("column must be second option")

        result.column =
          try: parseInt(args[i])
          except ValueError: 0

        if result.column < 1:
          fail("column must be > 0")

      elif result.rowName == "" and ArgRowName in allowed:
        if args[i] in [Top, Bottom]:
          result.rowName = args[i]
        else:
          fail("invalid row specification")

      elif result.classname == "":
        if ArgClassname notin allowed:
          fail("classname is not supported")

        result.classname = args[i]

      else:
        fail("undefined option")

      inc i
