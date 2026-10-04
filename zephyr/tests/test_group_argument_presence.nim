import std/[options, os, osproc, unittest]

import ../wm/cliargs

proc parseGroup(args: seq[string]): Arguments =
  parseArguments("group probe", args, [ArgGroup])

if paramCount() > 0 and paramStr(1) == "--parse-probe":
  discard parseGroup(commandLineParams()[1 .. ^1])
  quit(0)

suite "group argument presence":
  test "absence and explicit reserved group zero are distinct":
    check parseGroup(@[]).group.isNone
    check parseGroup(@["0"]).group == some(0)

  test "positive public group numbers remain explicit values":
    check parseGroup(@["1"]).group == some(1)
    check parseGroup(@["7"]).group == some(7)

  test "negative and malformed group values remain rejected":
    for invalid in ["-1", "invalid"]:
      let command = quoteShell(getAppFilename()) & " --parse-probe " & invalid
      check execCmdEx(command).exitCode != 0
