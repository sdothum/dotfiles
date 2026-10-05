import std/sequtils

import ../wm/types

proc spreadGrid*(count: int): Spread =
  result.columns = 1
  result.rows = 1

  case count
  of 1:
    return
  of 2:
    result.columns = 3
  of 3:
    result.columns = 4
  of 4:
    result.columns = 3
    result.rows = 2
  of 5 .. 9:
    result.columns = 4
    result.rows = 3
  else:
    result.columns = 5
    result.rows = 3

proc columnOrder*(columns, rows, position: int): int =
  let columnOrder =
    case columns
    of 1: @[1]
    of 2: @[2, 1]
    of 3: @[2, 3, 1]
    of 4: @[3, 4, 2, 1]
    of 5: @[3, 4, 5, 2, 1]
    else: toSeq(1 .. columns)

  result =
    if rows == 1:
      columnOrder[(position - 1) mod columns]
    else:
      columnOrder[((position - 1) div rows) mod columns]
