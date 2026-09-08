import std/unittest
import std/strutils

import ../wm/x11_snapshot
import ../wm/window_query

suite "x11 snapshot response framing":
  test "strips the WM OK envelope":
    var body: string
    check snapshotBody("OK\nSNAPSHOT 1\nFOCUSED NONE\nCURRENT 4294967295\n", body)
    check body == "SNAPSHOT 1\nFOCUSED NONE\nCURRENT 4294967295"

  test "accepts snapshot v2 envelope":
    var body = ""
    check snapshotBody("OK\nSNAPSHOT 2\nFOCUSED NONE\nCURRENT 4294967295", body)
    check body.startsWith("SNAPSHOT 2\n")

  test "normalizes producer final newline for strict parser":
    var body: string
    check snapshotBody(
      "OK\nSNAPSHOT 1\nFOCUSED NONE\nCURRENT 4294967295\n", body)
    discard parseWmSnapshotChecked(body)

  test "rejects non-snapshot responses":
    var body: string
    check not snapshotBody("ERROR unavailable", body)
    check not snapshotBody("OK\nOTHER 2\n", body)
    check not snapshotBody("", body)

  test "normalizes generic OK and rejects WM errors":
    var body: string
    check okBody("OK", body)
    check body == ""
    check okBody("OK\n0x01234567 1 2 300 400\n", body)
    check body == "0x01234567 1 2 300 400\n"
    check not okBody("ERROR unknown window", body)

suite "window geometry parsing":
  test "parses signed coordinates and dimensions":
    let geometry = parseGeometryBody("X=-12\nY=34\nWIDTH=800\nHEIGHT=600")
    check geometry.x == -12
    check geometry.y == 34
    check geometry.width == 800
    check geometry.height == 600
