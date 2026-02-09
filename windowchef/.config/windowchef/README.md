# Windowchef tree (supercedes prior file based dsl)

This DSL version stores its group/window states using a directory tree off
/dev/shm/windowchef (versus /tmp) for maximum performance.

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
on hardware. The directory tree version of this Windowchef dsl is best served
by utilizing the fast tmpfs of

`/dev/shm`

The *echo >file* is faster by a hair
technically than *mkdir path* (command execution, barely) but gains are made with group updates
on the tree structure data versus file content manipulation for the same.

