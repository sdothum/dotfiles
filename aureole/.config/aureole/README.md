# Aureole tree (supercedes prior file based dsl)

This DSL version stores its group/window states using a directory tree off
/dev/shm/aureole (versus /tmp) for maximum performance.

It provides a nicer at-a-glance profile of the session structure and simplifies
group/state management via its "pointer" structure, as well as,
maintenance/debugging of the code.

The architectural migration also benefitted the inevitable code cleanup, optimization and refactoring
of the codebase.

Essentially, shell

`echo >file`
`cat file`
`grep file`

statements/logic have been replaced with

`mkdir path`
`ls path`
`(glob) path or find path`

structures, simplifying group window management in particular.

Performance wise, it is mostly a wash, though, this will be system dependent
on hardware. The directory tree version of this Aureole dsl is best served
by utilizing the fast tmpfs of

`/dev/shm`

The *echo >file* is faster by a hair
technically than *mkdir path* (command execution, barely) but gains are made with group updates
on the tree structure data versus file content manipulation for the same.



This configuration is prepared and linked at ~/.config/aureole but is not
selected by ~/.windowmanager. The rc filename is aureolerc; Aureole-specific helpers use that name. ENV retains
the WM selection formula and AETHER/AETHER_TRACE compatibility keys, with
AETHER=aether. The aether/aetherd compatibility links now select installed
~/.local/bin/aether and aetherd. Copied persistent settings are in
~/.session/aureole; modeled after the original (c-lang) Cirrus configuration/settings.

Do not source ENV while the Aureole desktop is active: it initializes the
runtime state tree. Startup templates and exact activation/rollback commands
are in /home/shum/stow/caelwm/{config,BUILDING.md}. The inherited tvover helper
is unresolved in the inspection shell and must be available in the normal
X login PATH before activation. Old/new daemons retain the legacy socket
formula and must not serve it concurrently. No runtime validation is claimed.
