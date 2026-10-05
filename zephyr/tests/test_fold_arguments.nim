import std/unittest

import ../wm/cliargs
import ../zephyr_errors

const FoldArguments = [
  ArgColumns,
  ArgRows,
  ArgClassname,
  ArgGroupNo,
  ArgSpread,
  ArgRecord
]

suite "layout fold record option":
  test "record is an explicit opt-in switch":
    check not parseArguments("layout fold", @["5", "term"],
      FoldArguments).record
    check parseArguments("layout fold", @["5", "term", "--record"],
      FoldArguments).record

  test "duplicate record option is rejected":
    expect ZephyrError:
      discard parseArguments("layout fold",
        @["5", "term", "--record", "--record"], FoldArguments)
