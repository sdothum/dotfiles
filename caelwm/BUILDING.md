# Offline build and controlled switchover

## Build

Run from /home/shum/stow/caelwm. Installation and activation are separate
operations. Use the existing Nim 2.x toolchain and component flags; do not add
test defines, change the memory manager or invoke the C repository's install
target. The observed installed compiler is Nim 2.4.2, replacing the historically
documented 2.2.12. Its boot release/danger switches describe the compiler itself;
no danger flag was added to these programs.

```sh
/usr/lib/nim/bin/nim --version
/usr/lib/nim/bin/nim check --hints:off --path:aureole --nimcache:build-finalization/nimcache/check-aureole aureole/aureole.nim
/usr/lib/nim/bin/nim check --hints:off --path:borealis --nimcache:build-finalization/nimcache/check-borealis borealis/borealis.nim
/usr/lib/nim/bin/nim check --hints:off --path:aether --nimcache:build-finalization/nimcache/check-aether aether/aether.nim
/usr/lib/nim/bin/nim check --hints:off --path:aether --nimcache:build-finalization/nimcache/check-aetherd aether/aetherd.nim
make all BUILD_DIR=build-finalization NIM=/usr/lib/nim/bin/nim
dash -n config/aureole-session.sh
dash -n config/xinitrc.aureole
```

build-finalization already contains the successful finalization build; use another
fresh project-local BUILD_DIR/cache for a clean rebuild. The Makefile retains
normal Aureole compilation (no release/test define); Borealis uses release,
noSignalHandler and clientVersion=0.5.2; both controllers use release.
LegacyVersion=0.5.2 remains the WM define. The release component summaries confirm
ORC; no memory-manager override was introduced.

Dependencies: Nim/stdlib and a C compiler; XCB/X11 development headers; libxcb,
xcb-render, xcb-randr and xcb-keysyms for Aureole; libxcb for Borealis and the
controllers; libc/POSIX regex for the local selector bridge; PCRE dynamically
loaded by controller std/re. libpcre.so and libpcre.so.1 are present on this host.
No third-party Nim package or historical experiment is a build input.
Native compile pragmas retain aureole/runtime/selector_regex.c and
aureole/x11/randr_bridge.c. Do not add original C WM translation units.

Observed results and hashes are in MIGRATION_FINALIZATION_REVIEW.md. Static-check
logs and build.log are directly under build-finalization/. No runtime program,
CLI smoke probe, unit test or daemon was executed by this assignment. The
historical source-to-binary claims in earlier reports remain historical; a
successful new build does not establish runtime equivalence.

## Prepared configuration

The inactive root /home/shum/stow/aureole/.config/aureole already uses borealis,
aether and ZEPHYR=aether. Its draw, blackboard, five panel generators, contrast/
panel toggles and added statusbar helper preserve the current selected helpers'
behavior. Existing unrelated menu/history files were retained.

The existing ~/.xinitrc now has a minimal au*) case sourcing
config/aureole-session.sh. config/xinitrc.aureole is synchronized with that
integrated script; config/xinitrc.before-au preserves the owner's pre-integration
script. Every previous branch, including Cirrus, and the setpath/xexec definitions
are unchanged. Global X initialization stays in .xinitrc; the new case only
sources the helper, which performs Aureole-specific initialization once.
Aureole's display call now uses 3440x1440.

The actual tvover definition has not been found. The trace covered userpaths.sh,
login profiles, Fish configuration, original/config ENV and inspected script
directories; these provide PATH or calls, not a definition. No replacement was
invented. The helper checks command availability before sourcing ENV, resetting
runtime state, starting aetherd or launching hotkeys. Supply the actual definition
or make the existing executable available in the X startup environment before
using the new branch. A Fish-only abbreviation/function would not by itself
define a command in the /usr/bin/dash startup script.

The selector still contains cirrus. Do not source the helper or ENV in the current
session; no Aureole process has been activated.

## Controlled switchover — instructions only, NOT_EXECUTED

Current authorization permits preparation only. The commands below are for a
later owner-authorized installation/activation. None has been executed.

Readiness: all four outputs and installed new-name binaries match the recorded
Nim 2.4.2 build hashes. Configuration and copied persistent settings are prepared. The inspected ELF dependencies and PCRE library
are present. Installed Cirrus/Sirocco and Zephyr binaries, active startup/config
links and selector still match the recorded baseline. Runtime smoke testing is
NOT_EXECUTED. Binary installation is complete. Activation is NOT_EXECUTED and requires the
normal-session transition below, after the actual display helper is resolved.

### 1. Install the four new names only

This phase was completed with owner authorization. Do not rerun the block:
its absent-destination guards now intentionally fail. It is retained as the
recorded installation procedure.
It installs only ~/.local/bin/{aureole,borealis,aether,aetherd}. It does not launch
anything, change PATH, retarget aliases, copy settings, edit startup or select a
WM. No sudo, system install target or old binary replacement is involved.

Run the whole block in Bash. It checks hashes and rejects existing destination
files, directories and symlinks, including dangling ones. Hard-link publication
within ~/.local/bin refuses to replace a destination that appears after the
preflight; unlink removes only the newly created temporary installation name.
If interrupted, review partial new-name installation rather than rerunning over it.

```sh
(
set -eu
cd /home/shum/stow/caelwm
test -d "$HOME/.local/bin"
sha256sum -c <<'CAELWM_BUILDS'
fa7eb884feaaab4e3b512417e2f5fb8f50817deb468624007aa6aeb6a375944c  build-finalization/aureole
f0930b3a7a90e0cc638c88cc31c0283ef5f097dec7887f85eb9f002bdf89fc81  build-finalization/borealis
a60154ef82a172462a164b2bf47d015bb7f1ec0d03c1049ea5e295386b7e1df0  build-finalization/aether
f4fc991f2890fd5e2f90c19b049f1c2c93cb88f8c4bdc7806ab4fe332cee1593  build-finalization/aetherd
CAELWM_BUILDS
caelwm_check_legacy() {
    sha256sum -c <<'CAELWM_LEGACY'
d350002eaab449c40c7fce43d756a21aa3a1f099ecd6cc8ec80668c9c90a1acb  /usr/local/bin/cirrus
9670291d7589319a6f864eed74f6204246c26439f5d5ef381d024ad952d9e5d2  /usr/local/bin/sirocco
f40293de26fc1c7fc8e14b8f4c9a689ef0ea74322167f68ea30ece722ff75857  /home/shum/stow/zephyr/zephyr
9056e0c826b74e5f9492a7287f7d70b3553ddf8e04b24d9fa01a2b755a16df2d  /home/shum/stow/zephyr/zephyrd
CAELWM_LEGACY
}
caelwm_check_legacy
for name in aureole borealis aether aetherd; do
    test -x "build-finalization/$name"
    test ! -e "$HOME/.local/bin/$name"
    test ! -L "$HOME/.local/bin/$name"
    test ! -e "$HOME/.local/bin/.$name.caelwm-new"
    test ! -L "$HOME/.local/bin/.$name.caelwm-new"
done
for name in aureole borealis aether aetherd; do
    install -m 0755 "build-finalization/$name" "$HOME/.local/bin/.$name.caelwm-new"
    cmp "build-finalization/$name" "$HOME/.local/bin/.$name.caelwm-new"
    ln "$HOME/.local/bin/.$name.caelwm-new" "$HOME/.local/bin/$name"
    unlink "$HOME/.local/bin/.$name.caelwm-new"
    cmp "build-finalization/$name" "$HOME/.local/bin/$name"
done
caelwm_check_legacy
)
```

Stop here if only installation was authorized. Installation-only rollback needs
no desktop action: the original command names and configuration remain selected.
Leave the four unused new names in place for review; do not delete history or
retarget old executable names.

### 2. Select Aureole for the next normal X session

Startup integration is complete. Do not reinstall the old prepared .xinitrc or
repeat binary installation/configuration provisioning. The prepared resources
are:

- ~/.local/bin/{aureole,borealis,aether,aetherd}.
- ~/.config/aureole -> ~/stow/aureole/.config/aureole, with compatibility aliases
  zephyr/zephyrd selecting installed aether/aetherd.
- ~/.session/aureole copied from the original Cirrus settings.
- The au*) branch in ~/.xinitrc, sourcing
  ~/stow/caelwm/config/aureole-session.sh.

Aether uses the shared ENV/settings; there is no separate config-file path.
ENV exports ZEPHYR=aether and state paths under /dev/shm/aureole and
~/.session/aureole. The startup helper preserves the existing xexec behavior,
including cleanup and exit-75 restart. It checks installed binaries, prepared
config/settings, display-helper availability and prior-session WM/controller
processes before initialization. It does not remove shared daemon sockets.

**Pending dependency:** resolve the actual tvover definition/executable for the
dash X-startup environment. No definition was found in the inspected current
startup/login/helper sources, and the request for its path/definition remains
unanswered. Do not substitute guessed overscan settings or remove the availability
guard to claim this is resolved. Runtime/display behavior is NOT_EXECUTED.

After resolving that dependency, the single selector command for a subsequent
normal X session is:

```sh
printf '%s\n' aureole > "$HOME/.windowmanager"
```

This command was not executed by the integration assignment. It does not start
or stop anything. End the current session through its normal lifecycle and use
the existing login/startx route; do not run .xinitrc inside the active desktop.
Old/new controller daemons retain the same endpoint formula and must not overlap.
If a previous WM/controller remains, the helper refuses startup; arrange its
normal exit through an authorized owner operation rather than bypassing the guard.

Prepared settings are a snapshot. Review later differences from
~/.session/cirrus before switching; never overwrite the original settings.
No additional startup initialization or separate daemon command is needed in the
au*) branch.

## Rollback — select the original C environment

For the next normal X session, select Cirrus:

```sh
printf '%s\n' cirrus > "$HOME/.windowmanager"
```

The original ci*) branch, C Cirrus, Sirocco, Zephyr/Zephyrd executables,
~/.config/cirrus (including controller links/ENV/hotkeys/cirrusrc), and
~/.session/cirrus are intact. That branch supplies the original PATH and
ZEPHYR=zephyr environment and uses the unchanged xexec wrapper.
The integrated au*) branch can remain available; removing it is unnecessary.

The selector command does not terminate an already running Nim session.
Return through the normal session lifecycle and ensure its controller has exited
before starting the old environment. No WM/controller start/stop command was
executed by this assignment. config/xinitrc.before-au is a source backup if a
separately authorized restoration of the entire pre-integration startup is ever
needed. Do not overwrite later owner edits or delete either environment.
