# Migration finalization review

Date: 2026-11-20. Scope: read-only inspection and this report only.

## 1. Production baseline — PARTIALLY_VERIFIED

The configured startup chain is observable; the running desktop is **UNVERIFIED**.
`ps -eo pid,ppid,stat,etime,comm` exposed only sandbox-local codex/bash/ps
(PIDs 1/2/3), so no production WM/daemon PID, parent, executable mapping or
start time could be established. Do not infer that the desktop is absent or
replace this limitation with a historical experiment's identity.

Observed configuration:

- `~/.windowmanager` contains `cirrus`.
- `~/.xinitrc` resolves to `~/stow/X11/.xinitrc` (through the existing motu path).
  Its `ci*)` branch prepends `~/.config/cirrus` and its `bin`, sources
  `ENV`, starts `zephyrd`, selects Cirrus hotkeys and invokes
  `xexec cirrus -c "$HOME/.config/cirrus/cirrusrc"`.
- `xexec` preserves the existing exit-75 restart loop. Keep that behavior.
- `~/.config/cirrus -> ../stow/cirrus/.config/cirrus`.
  Its `ENV` sets `ZEPHYR=zephyr`, `WME=/dev/shm/$WM`,
  `WMSE=$HOME/.session/$WM`, and related state paths.
- Shell lookup resolves the following files; this is not live-process proof.

| Role | Resolved installed executable | Static identity |
| --- | --- | --- |
| WM | /usr/local/bin/cirrus | C WM: ELF symbol table contains wm.c; no NimMain match |
| Client | /usr/local/bin/sirocco | NimMain/NimMainModule present |
| Controller | /home/shum/stow/zephyr/zephyr | Nim runtime symbols; reached through ~/.config/cirrus/zephyr symlink |
| Daemon | /home/shum/stow/zephyr/zephyrd | Nim runtime symbols; reached through ~/.config/cirrus/zephyrd symlink |

Observed SHA-256 values, in the same order:

```text
cirrus   d350002eaab449c40c7fce43d756a21aa3a1f099ecd6cc8ec80668c9c90a1acb
sirocco  9670291d7589319a6f864eed74f6204246c26439f5d5ef381d024ad952d9e5d2
zephyr   f40293de26fc1c7fc8e14b8f4c9a689ef0ea74322167f68ea30ece722ff75857
zephyrd  9056e0c826b74e5f9492a7287f7d70b3553ddf8e04b24d9fa01a2b755a16df2d
```

Cirrus/Sirocco ELF comments include GCC 14.2.1 20250405 and GCC 13.2.0
(the latter also appears in startup-object debug information); these do not
establish complete build provenance. Controller files are dated October 21;
installed Cirrus September 14 and Sirocco November 7. Exact source revisions
and compiler invocations for these installed files were not established.

The separate `~/stow/cirrus/wm/cirrus_nim/main` hashes to
`1057710c9210fda5003813e57f3098e0499d8ac7eb06e6825388f813ecf58c2c`.
It differs from installed Cirrus and is not selected by the inspected startup.
README's historical corrected candidate hash is a third identity, not evidence
of current production. The owner's functioning Nim migration and the observed
C startup target must therefore be distinguished until host process observation
resolves the discrepancy.

## 2. Source layout — inspected, build completeness UNVERIFIED

All intended production directories and four actual entrypoints exist:

| Output | Entrypoint | Local implementation |
| --- | --- | --- |
| build/aureole | aureole/aureole.nim | model/, runtime/, startup/, x11/ |
| build/borealis | borealis/borealis.nim | protocol.nim, xcb_compat.nim, borealis.nim.cfg |
| build/aether | aether/aether.nim | wm/, policy/, zephyr_errors.nim |
| build/aetherd | aether/aetherd.nim | same controller modules |

The inspected import paths and native bridge files are present; no dependency
on experiments or old absolute source paths was found in these component trees
or Makefile. This is source inspection, not compiler resolution or functional
completeness. Include ignored files when searching: ordinary rg omitted the
existing aureole/runtime directory and some configuration helpers.

`shared/` is empty and has no observed consumers. Keep component-local protocol
and FFI modules; consolidation is unnecessary.

Root Makefile already builds all four correctly named outputs, with no install
target. It includes runtime Nim/C source prerequisites. Dependencies are Nim 2.x,
a C compiler, XCB headers/libraries (xcb, render, randr, keysyms), X11 keysym
headers, libc/POSIX regex, and PCRE loaded by controller std/re. No third-party
Nim package dependency was found. BUILDING.md records historical Nim 2.2.12;
`/usr/lib/nim/bin/nim` exists but its current version was not executed/verified.
Preserve current component flags, project config and memory manager; do not add
test defines or change ORC/default memory management.

No build/ directory exists. The renamed tree's compilation and runtime status
remain UNVERIFIED.

## 3. Remaining naming and configuration work

**Required integration changes:**

1. Add an explicit Aureole branch to `~/stow/X11/.xinitrc`, retaining the Cirrus
   branch for rollback. Select the Aureole config/PATH and hotkeys, start
   `aetherd`, and invoke `aureole -c "$HOME/.config/aureole/cirrusrc"` through
   the existing restart wrapper. Use the new session's autostart marker and log
   paths. Replace the legacy daemon process check in the new branch. Do not
   blindly unlink a potentially served daemon socket.
2. Install the four new names together into `~/.local/bin`, ensuring that
   directory is in the desktop PATH. None currently resolves in the inspection
   shell. Leave old installed names intact.
3. Finish `~/stow/aureole/.config/aureole`, then explicitly link/select it:
   `~/.config/aureole` is currently absent. Most command calls already use
   borealis/aether, and `ENV` already sets `ZEPHYR=aether`. Its top-level
   `zephyr` and `zephyrd` symlinks still point to old binaries: exclude these
   from the selected new config, preserving the original Cirrus links.
4. Provision `~/.session/aureole` by copying the existing persistent Cirrus
   settings, preserving the original. It is absent today; settings include
   UI/theme values and autostart entries. Inspect copied executable command
   entries for obsolete invocations. Do not copy transient /dev/shm state.
5. Reconcile the copied configuration with current selected helpers before
   choosing it. For example, functions/draw/{clock,desktop,music,panel,system}
   differ, and selected Cirrus files have November 16 edits newer than the copy.
   Do not overwrite those behavior changes with the older preparation.
   `ENV` removes/recreates WME: never source it as an inspection or smoke check.

**Preserve for compatibility:** CIRRUS_* atoms/opcodes, daemon socket formula
`$XDG_RUNTIME_DIR/zephyr/zephyrd.sock` (fallback `$WME/zephyrd.sock`),
ZEPHYR/ZEPHYR_TRACE keys, zephyr_errors/ZephyrError, C bridge symbol prefixes,
LegacyVersion and the cirrusrc filename. These are real implementation contracts,
not missing executable renames. Old daemon diagnostic text may remain to preserve
error contracts. The helper aurora uses /tmp/cirrus:aurora; retain it for this
single-session migration. New and old daemons must not serve the same endpoint
concurrently.

Comments, licenses, menu history, .deprecated content and historical build records
do not require renaming. No required production Nim module or executable-target
rename was identified.

## 4. Experimental scaffolding disposition

| Material | Disposition |
| --- | --- |
| aureole/runtime and x11 bridges | Required production source despite experimental-origin comments/hooks; keep |
| aether/tests | Useful existing focused tests; keep outside build inputs |
| experiments/stage22-fixture-recovery and experiments/stage-fixture-recovery | Historical reference; VM/package/fixture machinery obsolete for this finalization |
| caelwm-kernel-transfer-* and top-level STAGE22* reports | Historical acquisition artifacts/reports; not production dependencies |
| Old cirrus_nim and ~/stow/zephyr/experiments/nim-cirrus | Historical source/reference and possible later reuse; not selected production builds |

Keep the existing production directories and Makefile as the build boundary.
Leave experiments and authenticated evidence in place and explicitly outside
that boundary. Document them as archived/inactive; physical relocation, deletion
or mass renaming is unnecessary and could break historical references.
No archive move or new evidence hierarchy is needed.

## 5. Minimal implementation order

1. Complete the local config/helper reconciliation and persistent-settings plan;
   update README/BUILDING to describe current finalization instead of requiring
   another historical qualification program. Preserve historical findings.
2. Run entrypoint checks and build the existing four targets in a fresh build
   directory; fix only observed migration/build defects.
3. Run the existing focused controller tests and non-session CLI checks below.
4. Prepare backups and install the four new executable names; prepare the new
   startup branch/config/settings. Keep the old branch and executables available.
5. In a separately authorized normal desktop session transition, observe actual
   host process executable paths, select Aureole, and perform the short manual
   smoke test. Do not hot-replace the current WM.

The next assignment should implement these changes and compile, not resume Stage
22 or create infrastructure. Installation/session activation need explicit scope.

## 6. Proposed build and smoke commands — NOT_EXECUTED

From /home/shum/stow/caelwm, after build/test authorization:

```sh
/usr/lib/nim/bin/nim --version
/usr/lib/nim/bin/nim check --hints:off --path:aureole aureole/aureole.nim
/usr/lib/nim/bin/nim check --hints:off --path:borealis borealis/borealis.nim
/usr/lib/nim/bin/nim check --hints:off --path:aether aether/aether.nim
/usr/lib/nim/bin/nim check --hints:off --path:aether aether/aetherd.nim
# Use a fresh, absent BUILD_DIR; Makefile preserves each component's flags.
make all BUILD_DIR=build-finalization NIM=/usr/lib/nim/bin/nim
python3 aether/tests/test_group_navigation_source.py
/usr/lib/nim/bin/nim c -r --hints:off --path:aether --nimcache:build-finalization/nimcache/group-navigation --out:build-finalization/test_group_navigation aether/tests/test_group_navigation.nim
build-finalization/aureole -h
build-finalization/aureole -v
build-finalization/borealis -h
build-finalization/borealis -v
build-finalization/aether
```

Aether with no arguments prints usage and exits **1** by source inspection;
the four -h/-v calls should exit 0. Record actual diagnostics/status. Do not
start aetherd as a help probe; its entrypoint initializes runtime services.

After an authorized normal login into the new session, with correct inherited
environment and installed new PATH:

```sh
command -v aureole borealis aether aetherd
aether daemon await
borealis window focused
aether group current
aether display dimensions
```

From the host session, also record WM/daemon PIDs and read their /proc/PID/exe
symlinks. On a disposable terminal, manually check focus, move/resize, border
appearance, group switch/return, hide/restore, and one fold/unfold and
explode/unexplode cycle with geometry restored. Confirm panel and autostart
behavior. Observe results rather than infer success from request submission.
No VM, Xvfb, containers or historical parity suite is part of this procedure.

## 7. Replacement and rollback

Before any installation, copy the selector, resolved .xinitrc, relevant config
links/files, persistent settings, and any pre-existing new-name executables into
one dated rollback directory. Record symlink targets and executable hashes.
Refuse unexpected destination symlinks. Stage new executable files beside their
destinations, compare hashes, then rename into place; never truncate running
executables. Leave /usr/local/bin/cirrus, sirocco and the Zephyr binaries intact.

Activate only at an agreed logout/login. If the new session fails, use a text
console to restore the saved selector (currently cirrus), .xinitrc and config
links; restore any replaced new-name files. End the failed session normally,
ensure its daemon has exited, and start the preserved Cirrus branch. Do not
delete a socket served by a running process. Keep old persistent settings
untouched so rollback does not depend on reversing a data migration.

## 8. Blocking issues and verification record

There is no observed need for another migration verification program.
Immediate implementation can proceed. Activation is blocked by unfinished
config/settings integration and unobserved host process identity; compilation
may reveal additional concrete defects. Exact installed-binary source provenance
remains uncertain and is not a prerequisite for building new named outputs.

**Executed:** read-only cat/sed/rg (including --hidden/--no-ignore), ls/readlink,
shell type, ps, sha256sum, file, readelf and diff. Successful observations are
reported above. Expected negative results included missing new config/settings/
executables/build directory and absent guessed compiler metadata locations;
diff returned 1 for differing helpers; broad searches/listings sometimes returned
1/2 for absent matches/paths. No project program, compiler, make recipe or test
was executed. No runtime validation or production activation was performed.

Only this report was created. No source/config/binary changes, deletion,
network access, VM/container work, historical testing, commits or publishing.
Status: **PARTIALLY_VERIFIED** documentary review, ready for independent review;
implementation, compilation and smoke testing remain **NOT_EXECUTED**.

## FINALIZATION_IMPLEMENTATION_PLAN

Step 2, 2026-11-20. **PARTIALLY_VERIFIED** by read-only inspection.
This section refines the earlier recommendations; it authorizes no implementation.

### Identity reconciliation

| Identity | Observation and limit |
| --- | --- |
| Configured command | /home/shum/.windowmanager = cirrus; /home/shum/stow/X11/.xinitrc invokes cirrus through its existing restart wrapper |
| Installed WM file | /usr/local/bin/cirrus still has SHA-256 d350002eaab449c40c7fce43d756a21aa3a1f099ecd6cc8ec80668c9c90a1acb and ELF wm.c symbols; this identifies the C file on disk |
| Existing Nim WM source | /home/shum/stow/cirrus/wm/cirrus_nim/main.nim; its separate main executable hashes to 1057710c9210fda5003813e57f3098e0499d8ac7eb06e6825388f813ecf58c2c |
| Consolidated Nim WM source | /home/shum/stow/caelwm/aureole/aureole.nim; comparison with the preceding main.nim shows only three executable/diagnostic-label changes in that entrypoint, not a new WM implementation |
| Another preserved Nim executable | /home/shum/stow/zephyr/experiments/nim-cirrus/runtime_candidates/nim_cirrus_normal hashes to 0f310bd90c2d13839cc73637bc9727a91667ea0cac0b5b1359ccd49a895a6a54, matching that workspace's WORKSPACE.md; neither this document nor the hash proves it is running |
| Actual production process | **UNVERIFIED**: ps again exposed only sandbox-local codex/bash/ps. No host PID or /proc/PID/exe could be associated with any of these files |

The owner's established working Nim implementation is not contradicted by an
older installed C executable. Startup configuration describes a launch path;
a process might have been started differently or predate a file replacement.
Neither explanation was verified. The particular Nim binary/source revision
serving the desktop remains unresolved. Before activation, obtain host WM and
daemon PIDs, parent/command lines, resolved /proc/PID/exe and hashes of those
process executables (including any deleted executable mapping). Preserve that
actual rollback binary. Do not assume that reverting to the configured Cirrus
branch restores the owner's working Nim session.

### Already completed — do not repeat

- /home/shum/stow/caelwm/aureole/aureole.nim,
  /home/shum/stow/caelwm/borealis/borealis.nim,
  /home/shum/stow/caelwm/aether/aether.nim and
  /home/shum/stow/caelwm/aether/aetherd.nim already exist with local module trees.
- /home/shum/stow/caelwm/Makefile already targets all four final executable names
  and local source/bridge dependencies. No target/source-directory rename needed.
- Aureole already advertises aureole and defaults to the aureole config directory.
  Borealis already has its correctly named .nim.cfg.
- /home/shum/stow/aureole/.config/aureole already contains migrated command calls,
  ZEPHYR=aether, Aureole menu/config paths and the CaelWM source-menu entry.
  Do not recopy/rewrite the entire configuration.
- Keep shared/ empty. Preserve CIRRUS protocol atoms, wire formats, daemon socket
  names, cirrusrc, zephyr_errors, C bridge symbols and trace environment keys.
  Remaining old diagnostic text/comments do not require a behavior-changing rename.

### Smallest proposed change set

1. **Configuration helper consistency:** let the destination root be
   /home/shum/stow/aureole/.config/aureole and the read-only reference root be
   /home/shum/stow/cirrus/.config/cirrus. Port the current behavior for these exact
   relative paths, retaining the destination's final executable names:
   draw; bin/blackboard; functions/draw/clock; functions/draw/desktop;
   functions/draw/music; functions/draw/panel; functions/draw/system;
   functions/toggle/contrast; functions/toggle/panel.
   Add destination bin/statusbar from reference bin/statusbar.
   This is one dependent helper update: newer panels call panelcolor/sep defined
   in draw, blackboard hide requires the newer blackboard helper, and blackboard/
   panel toggling requires statusbar. Contrast now sends FIFO refresh messages.
   Do not copy just the panel files. Preserve unrelated menu/history differences;
   for example functions/menu/media's changed media list is outside this patch.
2. **Legacy executable links in the inactive copy:** retarget
   /home/shum/stow/aureole/.config/aureole/zephyr and
   /home/shum/stow/aureole/.config/aureole/zephyrd to
   /home/shum/.local/bin/aether and /home/shum/.local/bin/aetherd respectively,
   as compatibility aliases after those outputs are installed. Record the old
   targets; leave the original Cirrus config links untouched. This refines the
   earlier suggestion to exclude the copied links without deleting them.
3. **Documentation only in the source tree:** update
   /home/shum/stow/caelwm/README.md and /home/shum/stow/caelwm/BUILDING.md with the
   normal four-target workflow and the implementation/activation boundary.
   Preserve historical provenance as historical. No mandatory Nim-source or
   Makefile change is identified; fix a build defect only if one is observed.
4. **Installation and session integration, separately authorized:** install
   /home/shum/stow/caelwm/build-finalization/{aureole,borealis,aether,aetherd}
   as /home/shum/.local/bin/{aureole,borealis,aether,aetherd}, preserving existing
   destinations and rejecting unexpected links. Add an explicit aureole case to
   /home/shum/stow/X11/.xinitrc, leaving ci*) intact. Ensure ~/.local/bin and the
   Aureole config/bin paths take precedence; source that config's ENV only during
   the authorized new session; start aetherd; use the Aureole hotkeys/config,
   log and autostart marker; retain xexec's exit-75 restart semantics.
   Do not reproduce blind socket unlinking from the old branch.
5. Link /home/shum/.config/aureole to
   /home/shum/stow/aureole/.config/aureole. Copy settings from
   /home/shum/.session/cirrus into a new /home/shum/.session/aureole, without
   overwriting an existing destination or copying transient /dev/shm state.
   Inspect copied autostart command entries for legacy executable invocations.
   Change /home/shum/.windowmanager to aureole only at the authorized transition.

Both new config/settings destinations are still absent. The new four executable
names still do not resolve in this shell. The current four legacy installed
hashes match section 1. No installed/source-to-running-process binding is claimed.

### Production versus historical material

The active build boundary is /home/shum/stow/caelwm/Makefile plus aureole/,
borealis/ and aether/, including the local C bridges. Inspection with
--no-ignore found no experiment/old absolute source dependency. Keep
/home/shum/stow/caelwm/experiments/,
/home/shum/stow/caelwm/caelwm-kernel-transfer-* and the existing STAGE22 reports
unchanged and outside the build. Preserve
/home/shum/stow/zephyr/experiments/nim-cirrus and
/home/shum/stow/cirrus/wm/cirrus_nim as references until production identity is
resolved; do not equate historical classification with permission to remove
possibly useful rollback artifacts. No move, cleanup or new hierarchy needed.

### Build, smoke and rollback sequence

After explicit implementation/build/test authorization, apply items 1–3 and use
section 6's four entrypoint nim check commands, then:

```sh
cd /home/shum/stow/caelwm
make all BUILD_DIR=build-finalization NIM=/usr/lib/nim/bin/nim
python3 aether/tests/test_group_navigation_source.py
/usr/lib/nim/bin/nim c -r --hints:off --path:aether --nimcache:build-finalization/nimcache/group-navigation --out:build-finalization/test_group_navigation aether/tests/test_group_navigation.nim
build-finalization/aureole -h
build-finalization/aureole -v
build-finalization/borealis -h
build-finalization/borealis -v
build-finalization/aether
```

Use an absent build-finalization directory; preserve existing compiler settings,
VERSION and memory management. Record statuses/warnings; Aether's no-argument
usage exits 1. Check edited shell helpers with dash -n, without sourcing them.
No daemon launch or live-display trial belongs to this build step.

After owner-authorized installation and a normal session transition, confirm host
WM/daemon executable paths and run section 6's command-v/readiness/query checks.
Use a disposable terminal for the short focus/geometry/group/hide/restore and
fold/explode smoke test; confirm panel contrast/hide behavior. No new test program.

Before changing installed files or selection, back up the **observed working
process executable**, launcher/arguments, selector, resolved .xinitrc, config links,
settings and any existing destination binaries. Use one ordinary dated backup
directory. Install through sibling temporary files and rename, verifying hashes;
retain legacy executables. Roll back from a text console by restoring the saved
actual working launcher/selector/config and any replaced files, ending the failed
session normally and ensuring its daemon exits before starting the saved session.
Do not assume C Cirrus is the correct Nim rollback target or unlink served sockets.

### Authorization and outcome

Current authorization covers inspection and this report update only.
**Owner authorization still required:** source/config-copy edits, builds/static
checks/tests and CLI execution; executable installation/replacement and link/
settings provisioning; live startup/selector edits and any session transition or
WM/daemon restart. These scopes can be approved together or separately; no
hypothetical additional certification gate is proposed.

Step 2 executed only read-only cat/sed/rg/ls/readlink/type/ps/sha256sum/readelf/diff
and a Python standard-library text comparison. diff status 1 means differences;
missing paths and unmatched globs were observed, not repaired. No compiler,
project binary, test, startup script or daemon was executed. Only this report
was updated. Plan ready for owner review; implementation/build/smoke/activation
**NOT_EXECUTED**. Unresolved host process identity blocks choosing the correct
rollback/activation baseline, not preparing or building the final sources.

## OFFLINE_IMPLEMENTATION_RESULTS

2026-11-20. This section supersedes the earlier unresolved WM-language/identity
discussion and NOT_EXECUTED build status. Earlier sections remain the historical
record of their respective assignments.

### Running implementation identity — VERIFIED artifact match

The owner identifies the running executable as /usr/local/bin/cirrus with
SHA-256 d350002eaab449c40c7fce43d756a21aa3a1f099ecd6cc8ec80668c9c90a1acb.
Recomputed hashes match exactly for:

- /usr/local/bin/cirrus
- /home/shum/stow/cirrus/wm/cirrus
- /home/depot/CATLG/x11/cirrus/cirrus

The latter artifacts belong to the C WM build: the inspected Makefile links
wm.o, geometry.o, clients.o, focus.o, setup.o and the other C WM units. The
matching executable's ELF symbol table contains those source-unit names and no
NimMain match. The two inspected separate Nim artifacts instead hash to
1057710c9210fda5003813e57f3098e0499d8ac7eb06e6825388f813ecf58c2c
(cirrus_nim/main) and
0f310bd90c2d13839cc73637bc9727a91667ea0cac0b5b1359ccd49a895a6a54
(runtime_candidates/nim_cirrus_normal). Thus the supplied running binary is
the existing **C Cirrus implementation**, not either inspected Nim WM artifact.
This conclusion uses artifact hashes/build structure/symbols, not GCC metadata.
Host process identity is owner-supplied; this sandbox has not independently
observed the production PID or executable mapping. Exact historical build
invocation/revision remains unestablished and is unnecessary for this change.

### Completed offline changes

- Kept the four already consolidated Nim entrypoints, internal compatibility
  identifiers, wire contracts and existing build flags. No Nim source edits,
  directory recopy or architectural change was necessary.
- /home/shum/stow/caelwm/Makefile: replaced its stale preparation-only comment;
  targets/recipes are unchanged.
- /home/shum/stow/caelwm/config/aureole-session.sh: added an inactive startup
  fragment using the final component names, Aureole config and persistent
  marker, existing restart wrapper, and prior-session process checks; no blind
  socket removal.
- /home/shum/stow/caelwm/config/xinitrc.aureole: prepared the selected .xinitrc
  plus one Aureole case sourcing that fragment. Original startup remains intact.
- /home/shum/stow/caelwm/README.md and BUILDING.md: documented the actual build,
  active/historical source boundary and exact controlled switchover/rollback.
- Updated only these inactive helpers beneath
  /home/shum/stow/aureole/.config/aureole from the current Cirrus config:
  draw, bin/blackboard, functions/draw/clock, functions/draw/desktop,
  functions/draw/music, functions/draw/panel, functions/draw/system,
  functions/toggle/contrast, functions/toggle/panel; added bin/statusbar.
  Kept final command names, existing unrelated menus/history and all originals.

### Checks and build results — VERIFIED offline

Compiler: /usr/lib/nim/bin/nim --version exited 0, reporting Nim 2.4.2 Linux
amd64 (compiled November 16). This differs from historical 2.2.12 documentation;
no toolchain installation or memory-manager change was performed. The build
uses ORC, also visible in generated Aureole runtime C references to system/orc.nim.
Compiler boot danger/release settings were not passed to these programs.

All four nim check --hints:off invocations exited 0, with their own component
--path and project-local --nimcache. make all BUILD_DIR=build-finalization
NIM=/usr/lib/nim/bin/nim exited 0. No Warning:/Error: diagnostics were emitted
in the captured logs. Exact commands are in BUILDING.md; logs are
build-finalization/check-{aureole,borealis,aether,aetherd}.log and
build-finalization/build.log. All four output ELF files contain NimMain.

| Project-local output | SHA-256 |
| --- | --- |
| build-finalization/aureole | fa7eb884feaaab4e3b512417e2f5fb8f50817deb468624007aa6aeb6a375944c |
| build-finalization/borealis | f0930b3a7a90e0cc638c88cc31c0283ef5f097dec7887f85eb9f002bdf89fc81 |
| build-finalization/aether | a60154ef82a172462a164b2bf47d015bb7f1ec0d03c1049ea5e295386b7e1df0 |
| build-finalization/aetherd | f4fc991f2890fd5e2f90c19b049f1c2c93cb88f8c4bdc7806ab4fe332cee1593 |

dash -n exited 0 for all ten updated helpers and both prepared startup files.
The startup diff contains only the new three-line case arm. Runtime CLI probes,
unit tests, X11 smoke tests and daemon startup were **NOT_EXECUTED**: this
assignment permits safe offline build checks only. Compilation does not
establish focus/group/snapshot or presentation correctness.

### Remaining installation and configuration

The exact future commands and backup/rollback sequence are in
[BUILDING.md](BUILDING.md#controlled-switchover--instructions-only-not_executed).
They require owner authorization before execution. They install all four
new names in /home/shum/.local/bin without replacing legacy binaries,
retarget the inactive template's legacy daemon/controller aliases, copy
/home/shum/.session/cirrus to a new /home/shum/.session/aureole, link the new
configuration, install the prepared startup, then select aureole for a normal
session transition. Existing-target checks and the current .xinitrc hash guard
prevent silently overwriting later changes. Autostart command directory entries
were inspected and contained no direct legacy component invocation.

Rollback restores the backed-up startup and selector from a text console after
the failed session/daemon exits, then uses the untouched old binaries/config/
settings. The owner-supplied matching C Cirrus executable is now the known
rollback WM. New binaries/config can remain inactive; deletion is unnecessary.

### Boundary and review status

Post-build hashes of installed Cirrus/Sirocco and both Zephyr executables still
match section 1. The active .xinitrc hash remains
c3cd0f6aa5dcb204354baed04bdd827c5484e90a1389acaf6d0ecb9f0bda41df;
.windowmanager still hashes to
ac2de95fd2fbac0c035a3593d2a3f6469fa5632901026bcf4523cf70b96c4529
and selects cirrus. No new config link or persistent-settings directory was
created. Legacy aliases in the inactive config still point to the old binaries,
pending authorized installation. No historical file was deleted, moved or
rewritten; no network, VM, container, historical testing or new test framework
was used. No installation, activation, restart, commit or publishing occurred.

**PARTIALLY_VERIFIED overall:** offline implementation, static checks and builds
complete and ready for independent review; production installation and runtime
smoke validation remain NOT_EXECUTED. There is no observed offline build blocker.

## PRODUCTION_INSTALLATION_READINESS

2026-11-20. **PARTIALLY_VERIFIED overall; ready for owner review of installation.**
This assignment performed preparation only. No installation or activation command
below or in BUILDING.md has been executed.

Read-only reinspection confirmed:

- All four build-finalization outputs are executable ELF files and still match
  the hashes in OFFLINE_IMPLEMENTATION_RESULTS.
- /home/shum/.local/bin exists; aureole, borealis, aether and aetherd destinations
  are absent, including shell command lookup. The new config link and persistent
  settings directory are also absent.
- The old Cirrus/Sirocco and Zephyr executable hashes, selected startup hash and
  selector hash remain unchanged. Original controller/config symlinks still
  target /home/shum/stow/zephyr/{zephyr,zephyrd}.
- Inspected ELF NEEDED dependencies (XCB, render, RandR, keysyms, libc/libm),
  ELF loader and the controller's dynamically loaded PCRE library are present.
  This is file inspection, not runtime loader or X11 validation.
- The prepared startup differs only by its Aureole branch. The new config already
  uses borealis/aether and ZEPHYR=aether; its two legacy-name aliases still point
  to old controller binaries until the separate activation preparation retargets
  them. The original config must retain its own Zephyr links.
- Old/new daemons retain the same legacy endpoint formula. Installing unused
  new-name files creates no endpoint conflict; activation must end the old
  session/controller before starting the new pair.

Only /home/shum/stow/caelwm/BUILDING.md and this report were changed.
BUILDING.md now separates exact commands into:
(1) binary installation under new names, (2) separately authorized configuration/
session activation, and (3) rollback. Installation verifies source hashes, refuses
existing/new symlink destinations, publishes without replacement, and checks all
four old executable hashes before/after. It changes no startup, settings or PATH.

Before first activation, separately back up both controllers, C Cirrus, Sirocco,
the full original config tree/link, persistent settings, selector and resolved
startup; provision only the new config/settings; retain the original ci*) branch.
Rollback explicitly checks all old executables, the original config tree and
controller links, and persistent settings, then restores the config link/startup/
selector and returns to the old zephyr/zephyrd environment. It no longer relies
on the ineffective standalone ! pgrep guard under set -e: an explicit if/exit
guard refuses rollback while a WM/controller remains. Drift is reported rather
than silently overwriting unrelated state.

Verification: read-only hashes, destination/link listings, command lookup, ELF
dependency inspection, startup diff and configuration/source inspection;
documentation shell blocks checked with bash -n (exit 0). No binary execution,
build, process start/stop, settings change, live-config edit, history deletion,
network, VM or new testing infrastructure. Installation, activation and runtime
smoke checks remain **NOT_EXECUTED**. No observed blocker to separate new-name
installation; first-session configuration and runtime smoke checks remain pending.

## FINAL_ACTIVATION_PREPARATION

2026-11-20. **PARTIALLY_VERIFIED; prepared without activation.**

Prepared paths:

- /home/shum/.config/aureole ->
  /home/shum/stow/aureole/.config/aureole (new inactive config link).
- /home/shum/.session/aureole: independent copy of
  /home/shum/.session/cirrus, 391 entries at copy time; no source symlinks,
  original-path aliases or legacy command names in autostart directory entries.
- /home/shum/stow/aureole/.config/aureole/{zephyr,zephyrd}: compatibility aliases
  now target /home/shum/.local/bin/{aether,aetherd}. Original Cirrus aliases were
  not changed.
- /home/shum/stow/caelwm/config/xinitrc.aureole: prepared complete startup copy,
  whose Aureole case sources config/aureole-session.sh and uses the existing
  setpath/xexec functions and exit-75 restart wrapper. Neither is active.

Aether has no separate configuration file in the inspected implementation.
It consumes the shared Aureole ENV/settings: ZEPHYR=aether,
WMSE=~/.session/aureole, WME=/dev/shm/aureole, GROUP/HIDDEN/WINFO/FIFO derived
from WME. No invented ~/.config/aether or duplicate settings tree was added.
Borealis config calls and Aether/Aetherd references resolve to the installed
new-name executables; wire atoms, trace keys and daemon endpoint names remain
compatible.

Verification executed: dash -n for 67 active config shell scripts and both
startup templates, exit 0; static configuration/reference/library checks;
installed/build hashes; settings source/copy comparison; original config/settings
content snapshots before/after preparation. The originals were unchanged by the
copy/link operations. All installed binaries still match the recorded hashes.
Active .xinitrc and .windowmanager remain at the recorded baseline and select
cirrus; original config links remain selected. No ENV or startup script was
sourced, and no project binary/process was executed or started/stopped.

**Unresolved inherited dependency:** tvover is not found by command lookup in
this inspection shell or the inspected ~/bin paths. Its command/3440x14440
argument are inherited from the current startup and were not silently corrected.
Verify the helper in the normal X login PATH before activation; BUILDING.md now
contains a command-availability guard that stops the transition if it is absent.
Other checked core libraries and parent/recipe/sxhkd/setsid references are
present; actual X/display/audio/autostart behavior remains NOT_EXECUTED.
The preserved Zephyr/Aether daemon socket formula also requires old/new
controller processes not to overlap. Prepared settings are a snapshot; review
any changes to the old settings before the next session, rather than overwriting
either tree automatically.

Updated BUILDING.md separates completed installation/preparation from the
remaining exact activation commands. Its next-session block validates the
prepared config/settings/aliases, saves one ordinary backup of the original
WM/client/controllers/config/settings/startup/selector, installs only the startup
copy and selects aureole. Rollback restores the old config link/startup/selector,
verifies all old binaries/controller links/settings and returns to the original
Zephyr environment. Neither block was executed. All documented shell blocks
pass bash -n.

Documentation changes: BUILDING.md, repository README.md, this report, and the
inactive Aureole README.md. No change to active startup/selection, original
binaries/config/settings, running processes or historical experiments. No VM,
runtime test, certification stage or new testing infrastructure. Review-ready
preparation; activation remains **NOT_EXECUTED**, with the inherited display-helper
availability to resolve before switching.

## XINITRC_AUREOLE_INTEGRATION

2026-11-20. Startup integration is **VERIFIED by static checks**; the inherited
display-helper definition remains **UNVERIFIED/unresolved**.

Changed /home/shum/stow/X11/.xinitrc (the resolved ~/.xinitrc target) by adding
only an au*) case that sources
/home/shum/stow/caelwm/config/aureole-session.sh. Removing that new case reproduces
the owner's entire supplied current script byte-for-byte. This preserves every
previous WM branch, the Cirrus branch's already-corrected 3440x1440 call, and all
global initialization, setpath/xexec cleanup and exit-75 restart behavior.
config/xinitrc.aureole is synchronized to the integrated script;
config/xinitrc.before-au is an ordinary source backup of the owner's input.

Updated the Aureole helper's resolution argument from 3440x14440 to 3440x1440
and added a display-helper availability check before ENV/runtime initialization,
daemon or hotkey launch. Initialization is not duplicated in the new case: it
only sources the helper. Installed component references and prepared
config/settings are retained; no project executable was run.

tvover trace: login .bashrc/.bash_profile/.profile, Fish configuration,
~/bin/userpaths.sh, user_login/console_login, original Cirrus ENV and inspected
script/profile directories contain PATH initialization or startup calls but no
actual definition/executable. userpaths.sh adds non-deprecated ~/bin directories;
the original ENV does not define/source tvover. This does not resolve the
dependency. A request for the actual path/definition was sent to the owner.
No guessed replacement or overscan behavior was introduced. The helper will
refuse Aureole initialization if the command is unavailable.

Checks: dash -n for integrated ~/.xinitrc, synchronized startup copy and changed
helper exited 0. Static comparison confirms every original startup byte outside
the new case is unchanged. Configuration links and installed/build executable
hashes were checked without running binaries. .windowmanager remains cirrus at
SHA-256 ac2de95fd2fbac0c035a3593d2a3f6469fa5632901026bcf4523cf70b96c4529.
No running WM/controller, Xorg, original binary/config/settings or historical
experiment was changed or restarted. BUILDING.md and README.md now document
the integrated branch, corrected Aureole argument, unresolved helper, and the
single selector commands for a future Aureole/Cirrus session.

The exact next-session Aureole/Cirrus selector commands are in BUILDING.md.
Use the Aureole selection only after resolving the real display-helper dependency.
Neither selector command was executed.
Overall **PARTIALLY_VERIFIED**; runtime/production activation remains
**NOT_EXECUTED**. No new testing infrastructure or staged evidence package.
