## Neutral command-side boundary for the existing XCB WM IPC transport.
## The low-level implementation remains shared with zephyrd's snapshot path.

import x11_snapshot

type X11Ipc* = object
  transport*: X11SnapshotQuery

proc open*(ipc: var X11Ipc): bool =
  ipc.transport.open()

proc close*(ipc: var X11Ipc) =
  ipc.transport.close()

proc isOpen*(ipc: X11Ipc): bool =
  ipc.transport.isOpen()

proc rootGeometry*(ipc: var X11Ipc, width, height: var int): bool =
  ipc.transport.tryRootGeometry(width, height)

proc lastFailure*(ipc: X11Ipc): string =
  ipc.transport.lastFailure

proc stackGeometries*(ipc: var X11Ipc, winid: uint32,
    explicit: bool, body: var string): bool =
  ipc.transport.tryStackGeometries(winid, explicit, body)

proc geometry*(ipc: var X11Ipc, winid: uint32, explicit: bool,
    body: var string): bool =
  ipc.transport.tryGeometry(winid, explicit, body)

proc applyGeometries*(ipc: var X11Ipc, body: string): bool =
  ipc.transport.tryApplyGeometries(body)

proc applyGeometriesChecked*(ipc: var X11Ipc, body: string): bool =
  ipc.transport.tryApplyGeometriesChecked(body)
