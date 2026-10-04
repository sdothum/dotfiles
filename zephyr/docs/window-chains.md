# Fluent window action chains

Zephyr's Nim modules expose `WindowChain` for immediate, target-stable window
operations. Capturing a target records its managed XID and client identity
token; later actions continue to address that client even if focus changes.

```nim
import constants
import group as groups
import wm/window as window

discard window.target()
  .size("A4")
  .snap("Center")
  .layer(window.Above)
  .focus()
```

Chains also support target-aware group assignment and the single-window
`spread` and `tile` actions. Their arguments use the same constants and
conventions as the existing window API, including typed forms such as
`.size(A4, Rotate)` and `.snap(Center, Vertical)`.

```nim
proc luakit() =
  discard window.target()
    .group(GroupComm)
    .size("690x1080")
    .snap(Center, Vertical)
    .spread(Left)
```

Group assignment does not activate the destination group. Desktop-wide actions
remain separate:

```nim
proc btop() =
  discard window.target()
    .group(GroupUtil)
    .snap(Center)

  groups.focus(GroupDesk)
```

Use `window.target(winid)` to capture an explicit managed window. Both
constructors are read-only: capturing a target does not focus or raise it.
Actions run immediately and return the same chain value. `.focus()` is the
explicit focus operation. Fluent geometry actions preserve the focus that was
active when each action began, including when pointer/sloppy focus reacts to a
geometry change.

If the captured XID is no longer managed or now identifies a different client,
the next chain action fails with a target identity error rather than following
the currently focused window. The chain uses Zephyr's existing WM snapshot
tokens and native cirrus IPC; it does not queue or batch commands.

The chain operations are `group`, `size`, `snap`, `move`, `shift`, `layer`,
`spread`, `tile` and `focus`. Group-wide layout operations and desktop focus
remain separate. Existing command-line grammar and `.` command chaining are
unchanged.
