import std/[os, osproc, strutils, unittest, options]

import ../wm/cliargs

const GridArguments = [
  ArgColumns,
  ArgColumn,
  ArgColumnName,
  ArgRows,
  ArgRow,
  ArgRowName,
  ArgPosition
]

proc parseGridArguments(args: seq[string]): Arguments =
  parseArguments("grid probe", args, GridArguments)

if paramCount() > 0 and paramStr(1) == "--parse-probe":
  discard parseGridArguments(commandLineParams()[1 .. ^1])
  quit(0)

suite "grid argument presence and validation":
  test "omitted numeric grid fields remain absent":
    let args = parseGridArguments(@["3"])
    check args.columns == some(3)
    check args.rows.isNone
    check args.column.isNone
    check args.row.isNone
    check args.position.isNone

  test "numeric fields retain positive values":
    let args = parseGridArguments(@["3", "2", "--rows", "4", "--row", "3", "--position", "7"])
    check args.columns == some(3)
    check args.column == some(2)
    check args.rows == some(4)
    check args.row == some(3)
    check args.position == some(7)

  test "one is the minimum valid value for every numeric field":
    let args = parseGridArguments(@["1", "1", "--rows", "1", "--row", "1", "--position", "1"])
    check args.columns == some(1)
    check args.column == some(1)
    check args.rows == some(1)
    check args.row == some(1)
    check args.position == some(1)

  test "numeric row and named row preserve parser compatibility":
    let args = parseGridArguments(@["3", "2", "--rows", "2", "--row", "2", "bottom"])
    check args.columns == some(3)
    check args.column == some(2)
    check args.rows == some(2)
    check args.row == some(2)
    check args.rowName == "bottom"

  test "named column selection leaves numeric optionals absent":
    let args = parseGridArguments(@["left"])
    check args.columns.isNone
    check args.column.isNone
    check args.columnName == "left"
    check args.rows.isNone
    check args.row.isNone
    check args.rowName == ""

  test "the parser retains accepted numeric and named column combinations":
    let args = parseGridArguments(@["left", "2"])
    check args.columnName == "left"
    check args.column == some(2)

  test "positive values have no parser-level maximum":
    let args = parseGridArguments(@["1000", "999", "--rows", "800", "--row", "799", "--position", "100000"])
    check args.columns == some(1000)
    check args.column == some(999)
    check args.rows == some(800)
    check args.row == some(799)
    check args.position == some(100000)

  test "zero, negative and malformed numeric values remain rejected":
    for invalid in [
      @[@"0"], @[@"-2"], @[@"bad"],
      @[@"3", @"0"], @[@"3", @"-2"], @[@"3", @"bad"],
      @[@"3", @"--rows", @"0"], @[@"3", @"--rows", @"-2"], @[@"3", @"--rows", @"bad"],
      @[@"3", @"--row", @"0"], @[@"3", @"--row", @"-2"], @[@"3", @"--row", @"bad"],
      @[@"3", @"--position", @"0"], @[@"3", @"--position", @"-2"], @[@"3", @"--position", @"bad"]
    ]:
      let command = quoteShell(getAppFilename()) & " --parse-probe " & invalid.join(" ")
      let result = execCmdEx(command, options = {poStdErrToStdOut})
      check result.exitCode != 0

  test "duplicate options and invalid named alternatives remain rejected":
    for invalid in [
      @[@"3", @"--rows", @"2", @"--rows", @"3"],
      @[@"3", @"--row", @"2", @"--row", @"3"],
      @[@"3", @"--position", @"2", @"--position", @"3"],
      @[@"left", @"middle"],
      @[@"3", @"--rows", @"2", @"3"]
    ]:
      let command = quoteShell(getAppFilename()) & " --parse-probe " & invalid.join(" ")
      let result = execCmdEx(command, options = {poStdErrToStdOut})
      check result.exitCode != 0
