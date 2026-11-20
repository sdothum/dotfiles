## Narrow RandR observations. Monitor geometry and ownership are copied into
## Nim values; XCB reply and snapshot allocations stay within this module.

import ./bindings

{.passL: "-lxcb-randr".}
{.compile: "randr_bridge.c".}

type
  RandrMonitor* {.bycopy.} = object
    output*: uint32
    x*, y*: int16
    width*, height*: uint16
    active*: bool

proc rawInitialize(connection: ptr XcbConnection): cint
    {.importc: "cirrus_randr_initialize", cdecl.}
proc rawSelect(connection: ptr XcbConnection; root: uint32)
    {.importc: "cirrus_randr_select", cdecl.}
proc rawSnapshot(connection: ptr XcbConnection; root: uint32;
    monitors: ptr ptr RandrMonitor): cint
    {.importc: "cirrus_randr_snapshot", cdecl.}
proc rawFree(monitors: ptr RandrMonitor)
    {.importc: "cirrus_randr_free", cdecl.}

proc initializeRandr*(connection: ptr XcbConnection): cint =
  rawInitialize(connection)

proc selectRandrEvents*(connection: ptr XcbConnection; root: uint32) =
  rawSelect(connection, root)

proc queryRandrMonitors*(connection: ptr XcbConnection; root: uint32;
                         available: var bool): seq[RandrMonitor] =
  var raw: ptr RandrMonitor
  let count = rawSnapshot(connection, root, addr raw)
  if count < 0: return
  available = true
  if raw != nil:
    let values = cast[ptr UncheckedArray[RandrMonitor]](raw)
    for index in 0 ..< count:
      result.add(values[index])
    rawFree(raw)
