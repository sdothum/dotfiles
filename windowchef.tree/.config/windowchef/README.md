# Windowchef tree (supercedes prior file based dsl)

This DSL version stores its group/window states using a directory tree off
/tmp/windowchef.

It provides a nicer at-a-glance profile of the session structure and simplifies
some group/state management via its "pointer" structure.

Essentially, shell

`echo >file`
`cat file`

statements have been replaced with

`mkdir path`
`ls path`

statements, simplifying group window management in particular.

Performance wise, it is mostly a wash, though, this will be system dependent
on hardware. The directory tree version of this Windowchef dsl is best served
by utilizing the fast tmpfs of

`/dev/shm`

The *echo >file* is faster by a hair
technically than *mkdir path* (barely) but gains are made with group updates
on the tree structure data versus file content manipulation for the same.

On slower systems, the original flat file implementation will yield better
results.
