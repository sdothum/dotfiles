# zephyr development guidance

## Architecture

- windowchef is the primitive window-manager layer.
- zephyr is the policy, workflow, and geometry layer.
- sxhkd and ruler remain event sources.
- Legacy shell commands are temporary compatibility backends.
- Higher-level layouts, snapping, grids, and workflow policy belong in zephyr.

## Repositories

- window manager "cirrus" (alias "windowchef")
	- window manager C lang source code
		- /home/depot/CATLG/x11/cirrus/
- window manager client "sirocco" (alias "waitron")
	- window manager client C lang source code
		- /home/depot/CATLG/x11/cirrus/client.c
- zephyr frontend (under development)
	- nim source code
		- $HOME/stow/zephyr/
- backend scripts referenced by the nim frontend
	-  $HOME/.config/cirrus/

## Code style

- Prefer clear, explicit Nim.
- Prefer `case` for mutually exclusive branches.
- Avoid unnecessary macros, templates, and metaprogramming.
- Use two-space indentation.
- Keep dispatchers limited to command routing.
- Keep argument validation in the normalized `*vArgs` helpers.
- Use overloads to provide readable native Nim APIs over CLI-facing `seq[string]` procedures.
- Export symbols only when they form part of a module’s public interface.
- Keep backend command arity validation in normalized `*vArgs` helpers.
- Native policy dispatchers may validate their own public rule arguments.
-
## Vocabulary

- Use `group`, never `desktop`.
- Preserve the object/verb CLI grammar.
- Current domains include:
  - window
  - group
  - layout
  - display
  - screen
  - sync
  - rule

## Safety

- Do not change observable behaviour without explicit instruction.
- Do not redesign architecture unless explicitly requested.
- Do not commit changes.
- Compile after modifications and report all errors and warnings.
