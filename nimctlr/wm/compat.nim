import std/[os, osproc, strutils]

#
# Configuration
#

let TraceEnabled =
  getEnv("NIMCTLR_TRACE").toLowerAscii() notin ["", "0", "false"]

#
# Tracing
#

proc argvText(cmd: string, args: openArray[string]): string =
  result = cmd

  if args.len > 0:
    result.add(" ")
    result.add(args.join(" "))

proc traceCommand(cmd: string, args: openArray[string]) =
  if TraceEnabled:
    stderr.writeLine("nimctlr: " & argvText(cmd, args))

proc traceStatus(cmd: string, args: openArray[string], code: int) =
  if TraceEnabled:
    stderr.writeLine(
      "nimctlr: " & argvText(cmd, args) & " -> " & $code
    )

proc traceOutput(output: string) =
  if TraceEnabled:
    stderr.writeLine("nimctlr: stdout: " & output)

#
# Validation
#

proc requireNoArgs*(verb: string, args: seq[string]) =
  if args.len != 0:
    quit(verb & " expects no args")

proc requireArgCount*(
  cmd: string,
  verb: string,
  args: seq[string],
  minLen: int,
  maxLen: int
) =
  if args.len < minLen or args.len > maxLen:
    let name = cmd & " " & verb

    if minLen == maxLen:
      quit(name & " expects " & $minLen & " argument(s)")

    quit(
      name & " expects " &
      $minLen & ".." & $maxLen & " arguments"
    )

proc requireArgs*(
  command: string,
  args: seq[string],
  minArgs, maxArgs: int
) =
  if args.len < minArgs or args.len > maxArgs:
    quit(command & " expects " & $minArgs & ".." & $maxArgs & " arguments")

#
# Process execution
#

proc statusv(
  cmd: string,
  args: openArray[string]
): int =
  traceCommand(cmd, args)

  let process = startProcess(
    cmd,
    args = args,
    options = {poUsePath, poParentStreams}
  )

  result = waitForExit(process)
  close(process)

  traceStatus(cmd, args, result)

proc runv(
  cmd: string,
  args: openArray[string]
) =
  let code = statusv(cmd, args)

  if code != 0:
    quit(
      argvText(cmd, args) & " failed: " & $code,
      code
    )

proc shv*(
  cmd: string,
  args: openArray[string]
): string =
  traceCommand(cmd, args)

  result = execProcess(
    cmd,
    args = args,
    options = {poUsePath}
  ).strip()

  traceOutput(result)

#
# Validated argv helpers
#

proc commandArgs(verb: string, args: seq[string]): seq[string] =
  @[verb] & args

proc shvArgs*(
  cmd: string,
  verb: string,
  args: seq[string],
  minLen = 0,
  maxLen = high(int)
): string =
  requireArgCount(cmd, verb, args, minLen, maxLen)
  result = shv(cmd, commandArgs(verb, args))

proc runvArgs*(
  cmd: string,
  verb: string,
  args: seq[string],
  minLen = 0,
  maxLen = high(int)
) =
  requireArgCount(cmd, verb, args, minLen, maxLen)
  runv(cmd, commandArgs(verb, args))

proc statusvArgs*(
  cmd: string,
  verb: string,
  args: seq[string],
  minLen = 0,
  maxLen = high(int)
): int =
  requireArgCount(cmd, verb, args, minLen, maxLen)
  result = statusv(cmd, commandArgs(verb, args))

#
# Templates
#

template defineCommandProc*(
   name: untyped,
   namespace: static[string],
   command: static[string]
) =
   proc name*(args: seq[string]): int =
      runvArgs(namespace, command, args)

   proc name*(args: varargs[string]): int =
      name(@args)
