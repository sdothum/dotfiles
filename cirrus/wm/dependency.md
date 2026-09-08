## dependency rule

- events/ipc_handlers orchestrate.
- subsystems should avoid calling events/ipc_handlers.
- infrastructure should call nothing higher-level.

## subystem dependency map

wm
├─ setup
│  ├─ atoms
│  ├─ monitor
│  ├─ input
│  ├─ ipc_handlers
│  └─ events
├─ events
│  ├─ clients
│  ├─ window
│  ├─ focus
│  ├─ groups
│  ├─ monitor
│  ├─ ewmh
│  ├─ border
│  └─ input
├─ ipc_handlers
│  ├─ window
│  ├─ groups
│  ├─ focus
│  ├─ monitor
│  ├─ stack
│  └─ ewmh
├─ clients
│  ├─ border
│  ├─ list
│  └─ helpers
├─ window
│  ├─ clients
│  ├─ border
│  ├─ focus
│  ├─ monitor
│  └─ ewmh
├─ focus
│  ├─ clients
│  ├─ border
│  └─ input
├─ groups
│  ├─ clients
│  ├─ focus
│  ├─ list
│  └─ ewmh
├─ monitor
│  ├─ list
│  └─ helpers
├─ stack
│  ├─ clients
│  └─ geometry
├─ geometry
│  └─ clients
├─ border
│  └─ clients
└─ infrastructure
   ├─ list
   ├─ helpers
   ├─ atoms
   ├─ xutil
   └─ wm_state

Infrastructure:
  list, helpers, atoms, xutil, wm_state

State/domain:
  clients, monitor, groups

Behavior:
  window, focus, stack, geometry, border, input, ewmh

Interfaces:
  events, ipc_handlers

Orchestrator:
  wm, setup

