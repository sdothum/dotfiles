## Windowchef dsl wrapper

This codebase is now superceeded by windowchef.tree in this repository.

Functionally, both were initially identical but window.tree has since added
additional window manipulation functionality (and concurrent updates to the
sxhkdrc keybinds) and, more importantly, cleanup of the issues introduced
into the flat file version during its extensions, cut abruptly in favour of the tree structure
deployment.

The move to using a /dev/shm (for maximum performance) located tree structure
was done purely as an exercise to simplify some of the group/window management
processes -- a directory tree versus flat files of content, being more easily
inspected for (debugging and tuning) the wm's operating state.

As the flat file codebase lost focus to the tree codebase, it drifted out of functional alignment
-- though, at departure, the group/windowing functionality had already been
stable for quite some time. Changes were more frequently concerned with
personal workflow application rules and hotkey bindings.
