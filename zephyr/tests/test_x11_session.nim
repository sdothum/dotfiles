# Include the implementation to inspect private reset state without exposing
# production introspection or fault-injection APIs.
include ../wm/x11_snapshot
import std/[os, unittest]

suite "XCB session reset":
  test "close clears partial initialization without a connection":
    var query = X11SnapshotQuery(root: 1, commandAtom: 2, responseAtom: 3,
      requestAtom: 4, replyWindow: 5, lastResponse: "OK old response")
    query.close()
    check query.connection == nil
    check query.root == 0 and query.replyWindow == 0
    check query.commandAtom == 0 and query.responseAtom == 0 and query.requestAtom == 0
    check query.lastResponse == ""
    check not query.isOpen()
    query.close() # idempotent

  test "ambiguous reply IDs stay retired across complete session resets":
    var query = X11SnapshotQuery(replyWindow: 0x00100001)
    check not query.requestFailed("TIMEOUT (completion unknown)")
    check query.replyWindow == 0
    check XcbWindow(0x00100001) in retiredReplyWindows
    query.replyWindow = 0x00100002
    check not query.requestFailed("CONNECTION_LOST")
    query.close()
    check XcbWindow(0x00100001) in retiredReplyWindows
    check XcbWindow(0x00100002) in retiredReplyWindows

  test "failed connection clears all resources and retains a diagnostic":
    let original = getEnv("DISPLAY")
    let hadDisplay = existsEnv("DISPLAY")
    putEnv("DISPLAY", ":65534")
    defer:
      if hadDisplay: putEnv("DISPLAY", original)
      else: delEnv("DISPLAY")
    var query = X11SnapshotQuery(commandAtom: 2, lastResponse: "OK old response")
    check not query.open()
    check query.connection == nil
    check query.root == 0 and query.replyWindow == 0
    check query.commandAtom == 0 and query.responseAtom == 0 and query.requestAtom == 0
    check query.lastResponse == ""
    check query.lastFailure == "CONNECT"
