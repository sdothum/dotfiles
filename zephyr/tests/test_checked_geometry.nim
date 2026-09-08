import std/unittest

import ../wm/types
import ../wm/window
import ../wm/window_query

suite "checked geometry requests":
  test "serializes identity with each geometry entry":
    let token = parseClientToken(
      "0123456789abcdef0123456789abcdef:0000000000000001")
    let body = serializeCheckedGeometries(@[
      ("0x00000001", token, Geometry(x: -4, y: 8, width: 640, height: 480)),
      ("0x00000002", token, Geometry(x: 12, y: -3, width: 800, height: 600))])
    check body ==
      "0x00000001 " & $token & " -4 8 640 480\n" &
      "0x00000002 " & $token & " 12 -3 800 600\n"
