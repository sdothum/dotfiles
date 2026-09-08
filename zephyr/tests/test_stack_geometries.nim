import std/unittest

import ../wm/window_query

suite "stack geometry parser":
  test "parses ordered records and signed coordinates":
    let entries = parseStackGeometries(
      "0x01234567 -10 20 800 600\n0x89abcdef 0 -5 1024 768")
    check entries.len == 2
    check entries[0].winid == "0x01234567"
    check entries[0].geometry.x == -10
    check entries[0].geometry.height == 600
    check entries[1].winid == "0x89abcdef"
    check entries[1].geometry.width == 1024
