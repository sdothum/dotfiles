import std/strutils

type
  LegacyStartupAction* = enum
    lsaContinue, lsaHelp, lsaVersion
  LegacyStartupOptions* = object
    action*: LegacyStartupAction
    configPath*: string
    remainingArgs*: seq[string]
    diagnostics*: seq[string]
    earlyOutput*: string

const
  LegacyVersion* {.strdefine.} = "0.5.2"
  InternalOptions = ["--test-events", "--test-state", "--test-lifecycle",
      "--test-pause-before-effects", "--test-stage4", "--test-stage5",
      "--test-stage6", "--test-private-effects", "--abi"]

proc usageOutput*(executable: string): string =
  "Usage: " & executable & " [-h|-v|-c CONFIG_PATH]\n"

proc versionOutput*(): string =
  "cirrus " & LegacyVersion & "\n" &
      "Copyright (c) 2016-2019 Tudor Ioan Roman\n" &
      "Released under the ISC License\n"

proc parseLegacyStartupOptions*(args: openArray[string];
                                executable: string): LegacyStartupOptions =
  var index = 0
  var optionsEnded = false
  while index < args.len:
    let arg = args[index]
    if optionsEnded:
      inc index
      continue
    if arg == "--":
      optionsEnded = true
      inc index
      continue
    if arg in InternalOptions:
      result.remainingArgs.add(arg)
      inc index
      continue
    if arg == "-c":
      if index + 1 < args.len:
        result.configPath = args[index + 1]
        index += 2
      else:
        result.diagnostics.add(executable & ": option requires an argument -- 'c'")
        inc index
      continue
    if arg.startsWith("--"):
      result.diagnostics.add(executable & ": unrecognized option '" & arg & "'")
      inc index
      continue
    if arg.len > 1 and arg[0] == '-':
      var optionIndex = 1
      while optionIndex < arg.len:
        case arg[optionIndex]
        of 'h':
          result.action = lsaHelp
          result.earlyOutput = usageOutput(executable)
          return
        of 'v':
          result.action = lsaVersion
          result.earlyOutput = versionOutput()
          return
        of 'c':
          if optionIndex + 1 < arg.len:
            result.configPath = arg[optionIndex + 1 .. ^1]
            optionIndex = arg.len
          elif index + 1 < args.len:
            result.configPath = args[index + 1]
            index += 1
            optionIndex = arg.len
          else:
            result.diagnostics.add(executable & ": option requires an argument -- 'c'")
            optionIndex = arg.len
        else:
          result.diagnostics.add(executable & ": invalid option -- '" &
              arg[optionIndex] & "'")
          inc optionIndex
      inc index
      continue
    # C getopt ignores positional arguments after permuting options.
    inc index
