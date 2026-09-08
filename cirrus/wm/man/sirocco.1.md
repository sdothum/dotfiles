sirocco(1) -- A client for cirrus(1)
==========================================

## SYNOPSIS

`sirocco` [-hv] <command> [<args>..] [ . <command> [<args>..] ]*

## DESCRIPTION

`sirocco` is the client for cirrus(1). It sends a given command to
cirrus(1) as an X client message. Mutation commands don't print anything on
`stdout`. Read-only queries print their result on `stdout`.

## OPTIONS

* `-h`:
	Print usage.

* `-v`:
	Print version information.

* `. (dot)` <command> [<args>..]:
	Chain sirocco command

## COMMON DEFINITIONS

* `POSITION`:
	topleft | topright | bottomleft | bottomright | middle

* `BOOL`:
	true values: `true` | `t` | `yes` | `y` | `1`

	false values: `false` | `f` | `no` | `n` | `0`

* `DIRECTION`:
	`up` | `down` | `left` | `right` | `north` | `south` | `west` | `east`

* `POINTER_ACTION`:
	`nothing` | `focus` | `move` | `resize_corner` | `resize_side`

* `POINTER_MODIFIER`:
	`alt` | `super`

* `MOUSE_BUTTON`:
	`any` | `none` | `left` | `middle` | `centre` | `center` | `right`

	`middle`, `centre`, and `center` are synonyms and have the same behaviour.

## COMMANDS

* `window move` <x> <y> [<winid>]:
	Move the selected window to the absolute position given by <x> and <y>.

* `window move --relative` <x> <y> [<winid>]:
	Move the selected window by the relative pixel values <x> and <y>.

* `window resize` <width> <height> [<winid>]:
	Resize the selected window to <width> and <height>.

* `window resize --relative` <width> <height> [<winid>]:
	Resize the selected window by the relative pixel values <width> and <height>.

* `window apply-geometries` <XID> <x> <y> <width> <height> [...]:
	Apply one or more absolute geometries to explicit window IDs. Each record has
	exactly five fields: `XID X Y WIDTH HEIGHT`. All records are validated before
	any geometry is applied; malformed, duplicate, unknown, or unmanaged IDs
	cause the request to fail without applying it. Valid records are applied in
	argument order and the command waits for the window manager acknowledgement.
	This operation does not select targets through focus or center the pointer.

* `window reset` [<winid>]:
	Restore the selected window to the geometry saved by the window manager,
	clear its special state, restore its borders, and update `_NET_WM_STATE`.

* `window maximize` [<winid>]:
	Hide the border and maximize the selected window on the current monitor.
	Execute it again after maximizing to revert the state of the window.

* `window maximize --horizontal` [<winid>]:
	Horizontally maximize the selected window on the current monitor, preserving
	its <y> component. Leaves a gap at the left and right of the monitor that
	can be configured. Execute it again after maximizing to revert the state of the window.

* `window maximize --vertical` [<winid>]:
	Vertically maximize the selected window on the current monitor, preserving
	its <x> component. Leaves a gap at the top and bottom of the monitor whose
	width can be configured. Execute it again after maximizing to revert the state of the window.

* `window monocle` [<winid>]:
	Puts the selected window in the "monocled" state: full screen but with borders
	visible. Monocle mode respects gaps.

* `window close` [<winid>]:
	Closes the selected window.

* `window cycle`:
	Cycle through mapped windows.

* `window cycle --reverse`:
	Reverse cycle through mapped windows.

* `window cycle --group`:
	Cycle through mapped windows that belong to the same group as the
	focused window.

* `window cycle --group --reverse`:
	Reverse cycle through mapped windows that belong to the same group as the
	focused window.

* `window focus` <winid>:
	Focus window by <id>. The <id> can be found using pfw(1) or lsw(1) from
	[wmutils](https://github.com/wmutils/core/).

* `window focus --last`:
	Focus the window that was focused before the currently focused window.

* `window focus --cardinal` <DIRECTION>:
	Focus the closest window in a direction, relative to the currently
	focused window. Does nothing if there is no window focused.

* `window hide` [<winid>]:
	Hide (unmap) the selected window. The <winid> can be found using pfw(1) or lsw(1) from
	[wmutils](https://github.com/wmutils/core/).

* `group add` <group_nr> [<winid>]:
	Add the selected window to the <group_nr> group.

	Group numbers start from 1 and end at <GROUPS_NO>.

* `group remove` [<winid>]:
	Remove the selected window from its current group.

* `group clear` <group_nr>:
	Remove all windows from the <group_nr> group.

* `group activate` <group_nr>:
	Map all windows that belong to the <group_nr> group without changing focus
	or stacking order.

* `group deactivate` <group_nr>:
	Unmap all windows that belong to the <group_nr> group without selecting a
	replacement focused window.

* `wm quit` <exit_status>:
	Quit cirrus with exit_status <exit_status>.

* `wm config` <key> [<values>...]:
	See [CONFIGURING][].

## QUERYING

* `window focused`:
	Print the currently focused managed window ID in `0x%08x` format. If no
	managed window is focused, print an error and exit with a nonzero status.
	The query also exits nonzero if cirrus does not respond within two seconds.

* `window ids` [--all] [<classname>] [--name <name>]:
	Print managed window IDs, one per line. Without `--all`, only mapped windows
	are included; `--all` includes all managed windows. An optional classname or
	name restricts the result.

* `window count` [--all] [<classname>] [--name <name>]:
	Print the number of windows selected by the same collection options as
	`window ids`.

* `window classname`:
	Print the focused managed window's class name.

* `window stack` [<winid>]:
	Print the connected transitive overlap cluster containing the selected window,
	one window ID per line in actual X stacking order from bottom to top.

* `window stack-geometries` [<winid>]:
	Print the connected transitive overlap cluster containing the selected window,
	one record per line in stack order. Each record is `XID X Y WIDTH HEIGHT`,
	using the same geometry convention as `window geometry`. Membership and
	geometry are captured by one window-manager query.

* `window geometry` [<winid>]:
	Print the selected managed window's geometry as `X=`, `Y=`, `WIDTH=`, and
	`HEIGHT=` records. An explicit ID is addressed directly; without one, the
	focused managed window is selected.

* `window group` <winid>:
	Print the public one-based group number for the explicit managed window ID.
	Prints `4294967295` when the window has no group.

* `window groups --all`:
	Print every managed window and its public one-based group as `XID GROUP`,
	including unmapped windows. `4294967295` denotes the null group.

* `window snapshot`:
	Print the normalized version-1 managed-window snapshot:

	```
	SNAPSHOT 1
	FOCUSED XID|NONE
	CURRENT GROUP|4294967295
	CLIENT XID GROUP MAPPED
	```

	Groups are public one-based values. `MAPPED` is `0` or `1`, and
	`4294967295` is the null-group sentinel. This is a read-only observation.

* `window stack cycle` [<winid>]:
	Focus and raise the selected window if it is not already the topmost member of
	its canonical stack. If it is topmost, focus and raise the bottommost member.
	A single-member stack is left unchanged.

Information about the current state of cirrus is available through
X properties of the root window. Example:

```
xprop -root CIRRUS_ACTIVE_GROUPS
```

Information about the current state of each managed window is available
through X properties of the window. Example:

```
xprop -id 0x02c00009 CIRRUS_STATUS
```

Here is a list of exposed properties:

* `CIRRUS_ACTIVE_GROUPS`:
	On the root window. An integer list of currently active groups.
* `CIRRUS_STATUS`:
	On each managed window. Contains information about the window.
	Notable properties:
	`group` is -1 if the window is not in a group.
	`state` can have one of the following values: `normal`, `maxed`, `vmaxed`,
	`hmaxed`, `monocled`.

## CONFIGURING

Configuring is done using the `wm config` command. Possible configuration keys
are:

* `outer_border_width` <width>:
	Sets the outer border width to <width> pixels.

* `outer_color_focused`, `outer_color_unfocused` <outer_color>:
	Sets the outer border color to <outer_color> for the focused and unfocused
	state respectively.
	<outer_color> is a hexadecimal value that may or may not start with `0x`
	prefix. Example: `0x1234ef`.

* `inner_border_width` <width>:
	Make the first <width> pixels from the interior to the exterior of the
	inner border use another color, so you get inner and outer borders.
	The width of the outer border is `outer_border_width -
	inner_border_width`.

* `inner_color_focused`, `inner_color_unfocused` <inner_color>:
	Like `outer_color_focused` and `outer_color_unfocused`, but for the inner
	border. <inner_color> uses the same hexadecimal format as <outer_color>.

The legacy `border_width`, `color_focused`, `color_unfocused`,
`internal_border_width`, `internal_color_focused`, and
`internal_color_unfocused` configuration keys remain accepted with the same
arguments and behavior.

* `gap_width` <POSITION> <width>:
	Sets the window gap at <POSITION> to <width>. <POSITION> can be equal to
	`all` to set all gaps to <POSITION>.

* `cursor_position` <POSITION>:
	Sets the position of the cursor when moving or resizing windows.

* `groups_nr` <nr>:
	Sets the number of groups to <nr>. If <nr> is less than the current number
	of groups, window that belong to groups whose numbers are greater than <nr>
	will be mapped to screen and assigned to the null group.

* `enable_resize_hints` <BOOL>:
	If true, `cirrus` will respect window resize hints as defined by ICCCM.
	Most terminal emulators should have this feature.

* `enable_sloppy_focus` <BOOL>:
	Enable sloppy focus.

* `sticky_windows` <BOOL>:
	If <sticky_windows> is true, new windows will be assigned to the last
	activated group automatically. Recommended for people who like using
	workspaces over groups.

* `enable_borders` <BOOL>:
	If true, the border will be fully managed by the window manager. Border colors will
	be set each time a window gets/loses focus. Setting it to false lets
	the user manage the border of every window using external
	tools.
	(example: `chwb2` from wmutils).

* `enable_last_window_focusing` <BOOL>:
	If true, when the currently focused window is unmapped or closed, `cirrus` will focus the
	previously focused window. See the `window focus --last` command.

* `apply_settings` <BOOL>:
	If true, some settings will be applied on all windows instead of newly created windows.
	True by default.

* `replay_click_on_focus` <BOOL>:
	If true, when clicking on an unfocused with the intent to focus it, cirrus will also send
	the click event to the target window. If false, the window will receive the click event only
	if it's already focused.

* `pointer_actions` <POINTER_ACTION> <POINTER_ACTION> <POINTER_ACTION>:
	Sets the action that should be done whenever the modifier key and the corresponding button
	are clicked at the same time on the window. There are 3 actions for three mouse buttons:
	left, middle and right.

* `pointer_modifier` <POINTER_MODIFIER>:
	Set the modifier for pointer actions.

* `click_to_focus` <MOUSE_BUTTON>:
	Set the mouse button that focuses the hovered window when clicked.
## SEE ALSO

cirrus(1), sxhkd(1), wmutils(1), pfw(1), lsw(1), chwb2(1), lemonbar(1)

## REPORTING BUGS

`cirrus` issue tracker: https://github.com/tudurom/cirrus/issues

## AUTHOR

Tudor Roman `<tudurom at gmail dot com>`
