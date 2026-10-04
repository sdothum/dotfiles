import std/os

import ../policy/rules
import ../zephyr_errors

let args = commandLineParams()
if args.len != 1:
  stderr.writeLine("usage: action_error_probe <winid>")
  quit(2)

try:
  applyRule("term", args[0])
  stderr.writeLine("expected term rule to fail")
  quit(1)
except ZephyrError as error:
  echo error.msg
  echo "HOST_SURVIVED"
