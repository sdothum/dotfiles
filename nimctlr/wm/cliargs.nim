import strutils

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
