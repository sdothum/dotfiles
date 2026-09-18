import std/[os, strutils, unittest]
import ../wm/[state, types, window_query]

suite "independent class fold transactions":
  test "class journals preserve the first generation and recover independently":
    let base = getTempDir() / ("zephyr-group-explode-state-" & $getCurrentProcessId())
    let winfo = base / "winfo"
    let a = base / "wme" / "layout" / "fold:class:Firefox"
    let b = base / "wme" / "layout" / "fold:class:Other"
    createDir(winfo)
    putEnv("WINFO", winfo)
    putEnv("WME", base / "wme")
    defer: removeDir(base)
    let token = parseClientToken("0123456789abcdef0123456789abcdef:0000000000000001")
    let old = Geometry(x: 10, y: 20, width: 200, height: 100)
    let changed = Geometry(x: 30, y: 40, width: 300, height: 150)
    let records: seq[IdentityExplodeStateRecord] = @[("0x00000001", token, old)]
    var first = beginExplodeStateIdentity(a, records)
    var second = beginExplodeStateIdentity(b, records)
    commitExplodeState(first)
    commitExplodeState(second)
    check loadStateEntries(a) == records
    check loadStateEntries(b) == records
    var refold = beginExplodeOperationIdentity(a,
      @[("0x00000002", token, changed)], @[("0x00000002", token, changed)],
      preserveOriginal = true)
    markExplodeGeometryApplied(refold)
    commitExplodeOperation(refold)
    check loadStateEntries(a) == records
    check loadGeometryForToken("0x00000002", token) == changed
    let newer: seq[IdentityExplodeStateRecord] = @[("0x00000001", token, changed)]
    var operation = beginExplodeOperationIdentity(a, newer, @[("0x00000001", token, changed)])
    markExplodeGeometryApplied(operation)
    # Simulate process death after geometry acknowledgement but before publication.
    for path in [base / "wme" / "layout" / ".fold:class:Firefox-operation.txn",
        base / "wme" / "layout" / ".fold:class:Firefox.txn", base / ".restore-all.txn"]:
      var lines = readFile(path).splitLines()
      lines[3] = "0"
      writeFile(path, lines.join("\n"))
    writeFile(base / "wme" / "layout" / ".fold:class:Firefox.lock" / "pid", "0\n")
    writeFile(base / ".restore-all.lock" / "pid", "0\n")
    recoverRestoreHistory(winfo)
    check loadStateEntries(a) == newer
    check loadStateEntries(b) == records
    check loadGeometryForToken("0x00000001", token) == changed
    recoverExplodeOperation(a)
    check loadStateEntries(a) == newer
