import std/strutils

import x11_snapshot
import window_query

proc tryWmSnapshotDirect*(query: var X11SnapshotQuery,
  snapshot: var WmSnapshot, timeoutMs = 2000): bool =
  var output: string
  if not query.trySnapshotWithTimeout(output, timeoutMs):
    return false
  try:
    snapshot = parseWmSnapshotChecked(output)
    result = true
  except CatchableError as error:
    var tail = ""
    let start = if output.len > 48: output.len - 48 else: 0
    for index in start ..< output.len:
      let value = ord(output[index])
      case value
      of 10: tail.add("\\n")
      of 13: tail.add("\\r")
      of 0: tail.add("\\0")
      else:
        if value >= 32 and value <= 126:
          tail.add(output[index])
        else:
          tail.add("\\x" & toHex(value, 2))
    stderr.writeLine("SNAPSHOT_PARSE_DETAIL length=" & $output.len &
      " tail=" & tail & " reason=" & error.msg)
    query.lastFailure = "SNAPSHOT_PARSE"
    result = false
