import std/[os, osproc, streams, strutils]
import ../zephyr_errors

#
# Configuration
#

let TraceEnabled =
  getEnv("ZEPHYR_TRACE").toLowerAscii() notin ["", "0", "false"]

#
# Tracing
#


# Formats a command and its arguments for diagnostics without shell quoting.

proc argvText(cmd: string, args: openArray[string]): string =
  result = cmd

  if args.len > 0:
    result.add(" ")
    result.add(args.join(" "))


# Logs the command text to stderr when controller tracing is enabled.

proc traceCommand(cmd: string, args: openArray[string]) =
  if TraceEnabled:
    stderr.writeLine("aether: " & argvText(cmd, args))


# Logs command text and exit status when controller tracing is enabled.

proc traceStatus(cmd: string, args: openArray[string], code: int) =
  if TraceEnabled:
    stderr.writeLine(
      "aether: " & argvText(cmd, args) & " -> " & $code
    )


# Logs captured output when controller tracing is enabled.

proc traceOutput(output: string) =
  if TraceEnabled:
    stderr.writeLine("aether: stdout: " & output)

#
# Validation
#


# Checks a command verb's argument bounds and raises the established arity diagnostic.

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
      raiseZephyrError(name & " expects " & $minLen & " argument(s)")

    raiseZephyrError(
      name & " expects " &
      $minLen & ".." & $maxLen & " arguments"
    )


# Checks inclusive argument-count bounds and raises a controller error on mismatch.

proc requireArgs*(
  command: string,
  args: seq[string],
  minArgs, maxArgs: int
) =
  if args.len < minArgs or args.len > maxArgs:
    raiseZephyrError(command & " expects " & $minArgs & ".." & $maxArgs & " arguments")


# Requires an exact argument count and raises a controller error on mismatch.

proc requireArgs*(
  command: string,
  args: seq[string],
  minArgs: int
) =
  if args.len != minArgs:
    raiseZephyrError(command & " expects " & $minArgs & " args")


# Rejects any arguments for a command that expects none.

proc requireNoArgs*(command: string, args: seq[string]) =
  requireArgs(command, args, 0)

#
# Process execution
#


# Runs an argv command with inherited streams, waits for exit and returns its status.

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


# Runs an argv command and terminates the controller with its nonzero exit status.

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


# Captures and strips command output using PATH lookup, with optional tracing.

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


# Captures stripped command output and exit status, then closes the process handle.

proc shvStatus*(
  cmd: string,
  args: openArray[string]
): tuple[output: string, status: int] =
  traceCommand(cmd, args)

  let process = startProcess(
    cmd,
    args = args,
    options = {poUsePath}
  )

  result.output = process.outputStream.readAll().strip()
  result.status = waitForExit(process)
  close(process)
  traceStatus(cmd, args, result.status)
  traceOutput(result.output)

#
# Validated argv helpers
#


# Prepends the verb to the argument sequence passed to a subprocess.

proc commandArgs(verb: string, args: seq[string]): seq[string] =
  @[verb] & args


# Validates verb arity before capturing stripped subprocess output.

proc shvArgs*(
  cmd: string,
  verb: string,
  args: seq[string],
  minLen = 0,
  maxLen = high(int)
): string =
  requireArgCount(cmd, verb, args, minLen, maxLen)
  result = shv(cmd, commandArgs(verb, args))


# Validates verb arity before executing a subprocess with inherited streams.

proc runvArgs*(
  cmd: string,
  verb: string,
  args: seq[string],
  minLen = 0,
  maxLen = high(int)
) =
  requireArgCount(cmd, verb, args, minLen, maxLen)
  runv(cmd, commandArgs(verb, args))


# Validates verb arity before returning the subprocess exit status.

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


# Generates sequence and varargs command wrappers that use the validated process helper.

template defineCommandProc*(
  name: untyped,
  namespace: static[string],
  command: static[string]
) =
  proc name*(args: seq[string]): int =
    runvArgs(namespace, command, args)

  proc name*(args: varargs[string]): int =
    name(@args)
