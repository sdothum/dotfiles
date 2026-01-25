## Windowchef dsl wrapper

This codebase is now superceeded by windowchef.tree in this repository.

Functionally, both are identical (as of this writing, the migration just
completed).

The move to using a /dev/shm (for maximum performance) located tree structure
was done purely as an exercise to simplify some of the group/window management
processes -- a directory tree versus flat files of content, being more easily
inspected for (debugging and tuning) the wm's operating state.

Over time, the flat file codebase may drift out of functional alignment with the tree
structure codebase -- though, at present, the group/windowing functionality has
been stable for quite some time. Changes are more frequently concerned with
personal workflow application rules and hotkey bindings.
