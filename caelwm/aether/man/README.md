# CaelWM manual pages

`aether.1` is adapted from `~/stow/zephyr/man/zephyr.1` and reconciled with
`aether/aether.nim`, `aether/aetherd.nim`, `aether/wm/` and `aether/policy/`.
`aetherd.1` documents the separate foreground daemon. These pages describe
source behavior; this documentation assignment did not run the components.
The original Zephyr manual is unchanged. Edit the roff files directly.

The root Makefile now installs all four executables and these four manuals.
See [BUILDING.md](../../BUILDING.md) for `make`, `sudo make install`, DESTDIR
staging and uninstall instructions. Its MANDIR defaults to `$(PREFIX)/share/man`
and pages are installed beneath `man1`, following the original manual convention.
The install target requires already-built executables and never rebuilds them.

For a manual-only user installation, retain the direct copy procedure below.
It does not install any executables. Use the user prefix `~/.local` for all four pages:

```sh
install -d "$HOME/.local/share/man/man1"
install -m 644 aether/man/aether.1 aether/man/aetherd.1 aureole/man/aureole.1 borealis/man/borealis.1 "$HOME/.local/share/man/man1/"
```

This host uses mandoc and does not search `~/.local/share/man` by default.
For lookup in the current shell, without changing any configuration file:

```sh
export MANPATH="$HOME/.local/share/man:${MANPATH:-:}"
man -w aureole
man aureole
man -w borealis
man borealis
man -w aether
man aether
man -w aetherd
man aetherd
```

Alternatively use `man -M "$HOME/.local/share/man" aether` (or `aetherd`).
After installing, index the user manual tree to avoid mandoc lookup warnings:

```sh
makewhatis "$HOME/.local/share/man"
```

No system installation, executable build or session activation is needed.

Formatting checks:

```sh
groff -ww -Tutf8 -man aether/man/aether.1 >/dev/null
groff -ww -Tutf8 -man aether/man/aetherd.1 >/dev/null
mandoc -Tlint aether/man/aether.1
mandoc -Tlint aether/man/aetherd.1
```

Known usage-text discrepancies resolved from the actual handlers: `sync group`
is not dispatched; `display dimensions`, `group tagcount`, `window layer` and
`layouts grid` are dispatched; `window move` accepts only two coordinates;
`group close` takes a group, not a window; `group reconcile` currently changes
nothing; `state restore` updates history and needs `window restore` to apply
geometry. The daemon endpoint intentionally retains `zephyr/zephyrd.sock`.


`aureole/man/aureole.1` and `borealis/man/borealis.1` describe the current
Nim entrypoints and their production handlers. Their cross-references use
all four installed names. The Aureole session description was checked against
`config/aureole-session.sh`, `config/xinitrc.aureole`, and the prepared
`~/stow/aureole/.config/aureole/{aureolerc,ENV}` without sourcing them.

Validate each new source with the same tools:

```sh
groff -ww -Tutf8 -man aureole/man/aureole.1 >/dev/null
groff -ww -Tutf8 -man borealis/man/borealis.1 >/dev/null
mandoc -Tlint aureole/man/aureole.1
mandoc -Tlint borealis/man/borealis.1
cmp aureole/man/aureole.1 "$HOME/.local/share/man/man1/aureole.1"
cmp borealis/man/borealis.1 "$HOME/.local/share/man/man1/borealis.1"
```

Source distinctions: Borealis transmits group IDs without rebasing. Public
controller groups are 1 through count minus 1, while low-level group actions
also accept slot 0; the ungrouped sentinel is 4294967295. Group activation
does not imply focus. Borealis has no relative-group navigation verbs.
Aureole restart exits 75; the supplied xinitrc supervisor chooses to relaunch
it. Source inspection and manual rendering do not validate session behavior.
