# Design


## Charter

1. Every command has an object.

2. Every command has an explicit verb.

3. Objects expose semantic operations, not implementation details.

4. The DSL models window management, not shell commands.

5. Backward compatibility is temporary.


## Style guide

Objects:
    lowercase
    window
    group
    layout
    display
    screen
    sync

Verbs:
    lowercase
    snap
    size
    focus
    current
    count

Enum values:
    PascalCase
    Eq
    Ge
    Left
    Bottom
    Center
    Monocle

Identifiers:
    user-defined strings
    COMM
    Firefox
    term
    yazi
