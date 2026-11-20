# CaelWM

CaelWM's consolidated Nim components are:

| Component | Entrypoint | Role |
| --- | --- | --- |
| aureole | aureole/aureole.nim | X11 window manager |
| borealis | borealis/borealis.nim | Command-line client |
| aether | aether/aether.nim | Controller |
| aetherd | aether/aetherd.nim | Controller daemon |

Run `make all BUILD_DIR=build-finalization` for an offline build. Preserve an
existing build directory when changing toolchains; choose a fresh project-local
BUILD_DIR instead. See [BUILDING.md](BUILDING.md) for checks, dependencies,
controlled switchover commands and rollback. There is deliberately no install
target. Building does not install or activate anything.

The finalization build passed four entrypoint static checks and compiled all
four outputs with installed Nim 2.4.2. Runtime behavior has not been smoke-tested
in this assignment. Installed Cirrus remains untouched: the owner-supplied running
hash matches the existing C artifact, rather than the inspected Nim WM artifacts.
See [MIGRATION_FINALIZATION_REVIEW.md](MIGRATION_FINALIZATION_REVIEW.md) for results.

The production build consumes only aureole/, borealis/ and aether/, including
their local native bridges. shared/ is empty; no consolidation into it is needed.
experiments/, kernel-transfer artifacts and Stage 22 reports are preserved
historical material, outside the build.

The inactive configuration is /home/shum/stow/aureole/.config/aureole.
Its dependent panel helpers are reconciled with the current Cirrus configuration.
The existing ~/.xinitrc now includes an au* branch sourcing
config/aureole-session.sh; config/xinitrc.aureole is synchronized with it.
The selector still chooses Cirrus, so Aureole has not been activated.
Do not source ENV in the running session: it reinitializes
the runtime state tree. The inactive compatibility links now target the installed
Aether binaries, and ~/.session/aureole contains copied settings. The current
selector still chooses Cirrus; see BUILDING.md for the remaining activation and
rollback commands, including the inherited tvover availability check.

Protocol atoms, schemas, opcodes, daemon endpoint names, trace keys, internal
zephyr_errors and C bridge symbols remain compatible. The rc basename remains
cirrusrc under the aureole configuration directory. The new daemon retains
the legacy endpoint formula, so old/new controller daemons must not serve the
same endpoint concurrently. The startup fragment checks for prior-session
WM/controller processes and delegates socket probing to the existing daemon.

Historical provenance: the original corrected candidate SHA-256 was
71916b09ef11a45d8ea3f9a554f093729db43526c0c148efceb067eee3241c93 and its
59-file source identity was
a4db277542cc74bb11ce2318540af9eb621a2e3498e6391b7025c3f5e98f979b.
These describe preserved original artifacts, not the renamed tree, this build
or the running desktop. Historical manifests and licenses remain unchanged.
