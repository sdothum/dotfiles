zephyr(1) -- Nim policy and workflow controller
=================================================

## SYNOPSIS

`zephyr` <domain> <action> [<args>...]

Commands may be chained with ` . `.

## DESCRIPTION

`zephyr` is the policy, workflow, geometry, and filesystem helper layer for
Cirrus. It provides higher-level window, group, layout, rule, and state
operations while preserving explicit window IDs for action targeting.

## COMMANDS

### DISPLAY

* `display height`: Print display height.
* `display width`: Print display width.
* `display width_test` <args>: Test the configured display width.

### SCREEN

* `screen gap`: Print the configured gap.
* `screen indent`: Print the configured indentation.
* `screen margin`: Print the configured margin.
* `screen panel`: Print panel height/position information.
* `screen top`: Print the configured top offset.
* `screen bottom`: Print the configured bottom offset.

### GROUP

* `group add` <group> [<winid>]: Add a window to a public group.
* `group remove` [<winid>]: Remove a window from its group.
* `group close` [<winid>]: Close the selected group/window workflow target.
* `group count`: Print the configured group count.
* `group current`: Print the selected filesystem/current group.
* `group desktop` <args>: Run the desktop compatibility workflow.
* `group focus` <args>: Navigate to a group.
* `group id` <name>: Print a group's public numeric ID.
* `group last`: Run the previous-group workflow.
* `group name` [<group>]: Print a group name.
* `group reconcile` <group>: Reconcile the filesystem current-group mirror.
* `group restore`: Restore the saved group state.
* `group toggle` <args>: Toggle group visibility/selection.

Public group IDs are one-based. `0` is not a public group argument.

### WINDOW

* `window await` <selector> [<property>]: Wait for a matching window/property.
* `window classname`: Print the focused window class.
* `window count` [<selector>]: Count matching windows.
* `window extend` <args>: Extend the selected window toward a direction/side.
* `window geometry` [<winid>]: Print geometry for an explicit or focused window.
* `window group` <group> [--teleport]: Assign the focused window to a public
  group; `--teleport` additionally applies the existing teleport workflow.
* `window layer` <normal|above|overlay> [<winid>]: Set a persistent WM stacking
  layer without changing focus. `overlay` stays above `above`, which stays above
  `normal`. The target defaults to the focused window; normal restores ordinary
  stacking. An explicit assignment overrides EWMH defaults until the managed
  client is destroyed/unmanaged, including across hide/remap. Title-case layer
  names remain accepted. Docks and EWMH ABOVE windows automatically participate
  in the WM above tier without zephyr or zephyrd rules.
* `window hide` [<winid>]: Hide a window.
* `window ids` [--all] [<classname>] [--name <name>] [--group <group>]:
  Print matching window IDs through the daemon cache. `--group` narrows the
  existing visibility and class/name filters without implying `--all`. Group
  IDs match `sirocco group add` directly; zero is invalid. Membership is refreshed
  by the existing WM snapshot/invalidation path, including after daemon restart.
* `window restore` [<winid>]: Restore saved window geometry.
* `window rotate` [<winid>]: Swap the selected window's width and height.
* `window shift` <args>: Shift the selected window.
* `window size` <args>: Set or adjust the selected window's size.
* `window move <args>: Move the selected window by X Y pixels.
* `window snap` <args>: Snap the selected window to a screen position.
* `window spread` <args>: Spread the selected window across a region.
* `window stack` [<winid>]: Print the overlap-connected stack for a window.
* `window swap` <args>: Swap window geometry/state as requested.
* `window tile` <args>: Tile the selected window.
* `window toggle` <args>: Toggle matching windows.
* `window wm-group` <winid>: Print the WM-reported group for an explicit ID.
* `window wm-groups`: Print WM groups for managed windows.
* `window snapshot`: Print the normalized WM snapshot.

`wm-group`, `wm-groups`, and `snapshot` are read-only observations. The
`window stack-geometries` and `window apply-geometries` commands are Sirocco
commands; they are not zephyr public actions.

### LAYOUT

* `layout explode`: Capture the current overlap-connected stack, save original
  geometry, and arrange those windows according to the existing layout rule.
* `layout unexplode`: Restore saved geometry for surviving exploded windows.
* `layout explode --group` <group>: Place visible group members using the fold
  grid engine and save a dedicated identity-bearing explode operation under
  `$WME/layout/explode:group:N`. Each group retains independent state.
* `layout unexplode --group` <group>: Restore that recorded operation, including
  surviving clients that changed groups or became hidden. New members and
  reused XIDs with different identity tokens are not restored. Preserve current
  focus and remove the saved operation after restoration.
* `layout fold` <args>: Fold matching windows into a grid, then raise participants
  in placement order within their effective stacking bands while preserving focus.
  Repeating an unchanged fold still raises the selected set. Group explode shares
  this stacking behavior without sharing fold transaction ownership.
* `layout level` <args>: Level windows vertically.
* `layout restore` [<args>]: Restore layout state.
* `layout spread` <args>: Spread windows across a grid.
* `layout tile` <args>: Tile windows into a grid.

`unexplode` ignores disappeared saved XIDs and preserves the current focus.

### RULE

* `rule` <name>: Apply a configured application rule. Rule names are the
  names implemented by the current rule dispatcher.

### STATE

* `state snapshot` [<winid>]: Save a window geometry snapshot.
* `state restore` [<winid>]: Restore a saved window geometry snapshot.

`zephyrd` removes `$WINFO/<winid>` after receiving an actual X11
`DestroyNotify` and confirming that the window no longer exists. Hidden,
unmapped, and inactive-group windows retain their state. Startup and X11
reconnection also reconcile stale WINFO directories, including windows that
died while the daemon was stopped. Uncertain X11 errors preserve state.

The same lifecycle handler reconciles `$HIDDEN/<winid>` on `MapNotify` and
`DestroyNotify`, checking current X visibility before removing an entry.
Visible or destroyed windows lose hidden metadata; genuinely unmapped windows
retain it. Startup/reconnection scans both trees, including hidden entries
without WINFO records. No particular focus or restore command is required.

WINFO cleanup waits for active restore-history transactions and retries deferred
work; HIDDEN cleanup proceeds independently. Group membership and focus records
remain owned by WM snapshot reconciliation. Correctness does not require an
explicit `zephyr group close` before closing an application.

## CHAINING

Commands can be sequenced with a period:

```
zephyr window move 10 10 0x01234567 . window size 800x600 0x01234567
```

## SEE ALSO

`sirocco`(1), `cirrus`(1), `ruler`(1)
