# sdothum - 2016 (c) wtfpl

# Kakoune
# ══════════════════════════════════════════════════════════════════════════════

# Ncurses console plugins
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# ................................................................... auto-pairs

bundle auto-pairs.kak https://github.com/alexherbo2/auto-pairs.kak.git %{
	enable-auto-pairs
}

# ............................................................. change-directory

if-else %{ [ -z "$DIFF" ] } %{
	# change-directory action fails diff-jump - within a "dirdiff" loop SEE: kakdiff
	bundle kakoune-cd  https://github.com/Delapouite/kakoune-cd.git %{
		hook global WinDisplay .* change-directory-current-buffer
		hook global FocusIn    .* change-directory-current-buffer  # BUG: fails on filename with leading dashes
	}
} %{
	define-command change-directory-current-buffer %{ nop }
}

# ................................................................... crosshairs

bundle kak-crosshairs https://github.com/insipx/kak-crosshairs.git %{
	push %{ focus h : map global user + ': crosshairs<ret>'   -docstring "crosshairs" }
	push %{ focus h : map global user ^ ': cursorcolumn<ret>' -docstring "cursor column" }
}

# ........................................................................ fandt

bundle kakoune-fandt https://github.com/listentolist/kakoune-fandt.git %{
	require-module fandt
}

# ............................................................. find and replace

bundle kakoune-find https://github.com/occivink/kakoune-find.git %{
	push %{ alpha 1 : map global buffer f ': find '                   -docstring "find THEN replace" }
	push %{ alpha 1 : map global buffer R ': find-apply-changes<ret>' -docstring "find THEN replace" }
}

# ............................................................. focus selections

bundle kakoune-focus https://github.com/caksoylar/kakoune-focus.git %{
	set-option global focus_context_lines 1
	# force uniform separator highlighting SEE: colors/duochrome
	set-option global focus_separator '{FocusSeparator}┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄'
	declare-option str focus "off"
	declare-option int focus_line 0

	# manage focus view to show maximum selections
	define-command toggle-focus %{
		if-else %{ [ "$kak_opt_focus" = "on" ] } %{
			set-option window focus "off"
			focus-disable
			margin '-relative'
			softwrap
			execute-keys "%opt{focus_line}g"
		} %{
			set-option window focus "on"
			set-option window focus_line %val{cursor_line}
			nowrap            # BECAUSE: softwrapped lines throw focus replace-range highlighter usage
			margin            # provide absolute line number referencing
			execute-keys ')'  # rotate to topmost selection NOTE: assumes no prior selection rotations made
			focus-enable
		}
	}

	push %{ focus f : map global user <space> ': toggle-focus<ret>' -docstring "focus selections" }
}

# .............................................................. lua interpreter

bundle luar https://github.com/gustavo-hms/luar.git %{
	require-module luar
	set-option global luar_interpreter luajit
}

# ................................................................... move lines

bundle kak-move-lines https://git.sr.ht/~raiguard/kak-move-lines %{
	map global normal <c-up>    ': move-lines-up %val{count}<ret>'   -docstring 'shift up'
	map global normal <c-down>  ': move-lines-down %val{count}<ret>' -docstring 'shift down'
	map global normal <c-left>  '<'                                  -docstring 'shift left'  # finger convenience :)
	map global normal <c-right> '>'                                  -docstring 'shift right'
}

# ....................................................... peneira (fuzzy finder)

bundle peneira https://github.com/gustavo-hms/peneira.git %{
	require-module luar
	require-module peneira
	set-option global peneira_files_command "rg --files --sort=path"  # single threaded --sort is fast enough for my folder organization

	# HACK: multi-client focus switching causes peneira to lose active client buffer directory
	define-command peneira-resync %{
		change-directory-current-buffer  # handled by hook FocusIn above, otherwise required
		buffer *debug*
		execute-keys ga
	}

	define-command buffers %{
		peneira-resync
		peneira 'buffers: ' %{ printf '%s\n' $kak_quoted_buflist } %{ buffer %arg{1} }
	}

	define-command files %{
		peneira-resync
		peneira-files -hide-opened
	}

	define-command lines %{
		peneira-resync
		peneira-lines
	}

	define-command symbols %{
		peneira-resync
		peneira-symbols
	}

	push %{ alpha 1 : map global buffer b ': buffers<ret>' -docstring 'buffers' }
	push %{ alpha 1 : map global buffer e ': files<ret>'   -docstring 'edit file' }
	push %{ alpha 1 : map global buffer l ': lines<ret>'   -docstring 'lines' }
	push %{ alpha   : map global user   C ': symbols<ret>' -docstring 'ctag symbols' }
}

# ............................................................ phantom selection

bundle kakoune-phantom-selection https://github.com/occivink/kakoune-phantom-selection.git %{
	push %{ alpha : map global user f     ": phantom-selection-add-selection<ret>"                       -docstring 'phantom add,clear' }
	push %{ alpha : map global user F     ": phantom-selection-select-all; phantom-selection-clear<ret>" -docstring 'phantom add,clear' }
	map global normal <a-f> ": phantom-selection-iterate-next<ret>"                        -docstring 'phantom next'
	map global normal <a-F> ": phantom-selection-iterate-prev<ret>"                        -docstring 'phantom previous'

	# this would be nice, but currrently doesn't work
	# see https://github.com/mawww/kakoune/issues/1916
	#map global insert <a-f> "<a-;>: phantom-selection-iterate-next<ret>"
	#map global insert <a-F> "<a-;>: phantom-selection-iterate-prev<ret>"
	# so instead, have an approximate version that uses 'i'
	map global insert <a-f> "<esc>: phantom-selection-iterate-next<ret>i"                  -docstring 'phantom next'
	map global insert <a-F> "<esc>: phantom-selection-iterate-prev<ret>i"                  -docstring 'phantom previous'
}

# .................................................................. search docs

bundle search-doc.kak https://github.com/jbomanson/search-doc.kak.git %{
	require-module search-doc
	alias global sd search-doc
}

# ..................................................................... smarttab

bundle smarttab.kak https://github.com/andreyorst/smarttab.kak.git %{
	require-module smarttab
	set-option global softtabstop 3

	hook global BufOpenFile .* smarttab
	hook global BufNewFile  .* smarttab
}

# ................................................................... sudo-write

bundle kakoune-sudo-write https://github.com/occivink/kakoune-sudo-write.git

# .................................................................. tree-sitter

bundle kak-tree-sitter https://github.com/phaazon/kak-tree-sitter.git %{
	nop evaluate-commands %sh{ kak-tree-sitter -d -k --init $kak_session -s }
} %{
	cargo install kak-tree-sitter
	cargo install ktsctl
}

# kak: filetype=kak
