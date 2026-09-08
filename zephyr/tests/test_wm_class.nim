import std/unittest

import ../wm/x11_snapshot

suite "WM_CLASS parser":
  test "parses instance and class":
    var instanceName, className: string
    check parseWmClassProperty("instance\0Class Name\0", instanceName, className)
    check instanceName == "instance"
    check className == "Class Name"

  test "rejects malformed property payloads":
    var instanceName, className: string
    check not parseWmClassProperty("instance\0Class Name", instanceName, className)
    check not parseWmClassProperty("instance", instanceName, className)
    check not parseWmClassProperty("", instanceName, className)

  test "permits empty components but preserves them":
    var instanceName, className: string
    check parseWmClassProperty("\0\0", instanceName, className)
    check instanceName == ""
    check className == ""
