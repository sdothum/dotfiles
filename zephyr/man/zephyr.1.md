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
* `window hide` [<winid>]: Hide a window.
* `window ids` [<args>]: Print matching window IDs.
* `window restore` [<winid>]: Restore saved window geometry.
* `window rotate` [<winid>]: Swap the selected window's width and height.
* `window shift` <args>: Shift the selected window.
* `window size` <args>: Set or adjust the selected window's size.
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
* `layout fold` <args>: Fold matching windows into a grid.
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

### SYNC

* `sync window` [<args>]: Run the compatibility window synchronization command.
* `sync group` [<args>]: Run the compatibility group synchronization command.

These remain explicit compatibility commands; they are not the passive daemon
observation publisher.

## CHAINING

Commands can be sequenced with a period:

```
zephyr window move 10 10 0x01234567 . window size 800x600 0x01234567
```

## SEE ALSO

`sirocco`(1), `cirrus`(1), `ruler`(1)
