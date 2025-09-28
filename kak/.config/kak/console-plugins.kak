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
	addm %{ meta 1 : map global buffer + ': crosshairs<ret>'   -docstring "visual  -- crosshairs,column,line"  }
	addm %{ meta 2 : map global buffer | ': cursorcolumn<ret>' -docstring "visual  -- crosshairs,column,line" }
	addm %{ meta 3 : map global buffer _ ': cursorline<ret>'   -docstring "visual  -- crosshairs,column,line" }
	cursorline
}

# ........................................................................ fandt

bundle kakoune-fandt https://github.com/listentolist/kakoune-fandt.git %{
	require-module fandt
}

# ............................................................. find and replace

bundle kakoune-find https://github.com/occivink/kakoune-find.git %{
	# define-command c-ret-message %{ info-notifier %{find & replace} %{<ret>     goto buffer:line\n<c-ret>   buffer (user-mode) to replace} }
	define-command c-ret-message %{ nop %sh{ notify 30 critical "find & replace" "&lt;<b>ret</b>&gt;\tgoto buffer:line\n&lt;<b>c-^</b>&gt;\tcommit buffer edits\n&lt;<b>c-ret</b>&gt;\tbuffer (user-mode)" }}

	# NOTE: <ret> jumps to buffer line, <c-ret> for buffer user-mode (to apply replace)
	addm %{ alpha 5 : map global buffer f     ': c-ret-message<ret>: find ' -docstring "find    —— buffer:line,(commit buffer edits)" }
	addm %{ alpha 6 : map global buffer <c-^> ': find-apply-changes<ret>;'  -docstring "find    —— buffer:line,(commit buffer edits)" }
	map global normal <c-^> ': find-apply-changes<ret>;' -docstring "commit buffer edits"
}

# ............................................................. focus selections

bundle kakoune-focus https://github.com/caksoylar/kakoune-focus.git %{
	set-option global focus_context_lines 1
	# force uniform separator highlighting SEE: colors/duochrome
	set-option global focus_separator '{FocusSeparator}┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄'
	declare-option str focus "off"
	declare-option int focus_line 0

	# define-command focus-message %{ info-notifier %{focus selections} %{<a-n>,n   (deselect) then prev,next\n<a-N>,N   (select)   then prev,next} }
	define-command focus-message %{ nop %sh{ notify 20 critical "focus selections" "&lt;<b>a-n</b>&gt;,<b>n</b>\t(deselect) then prev,next\n&lt;<b>a-N</b>&gt;,<b>N</b>\t(select)   then prev,next" }}

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
			focus-message
			focus-enable
		}
	}

	addm %{ focus 0 : map global edit <space> ': toggle-focus<ret>' -docstring "focus selections" }
}

# .......................................................................... hop

bundle hop.kak https://github.com/hadronized/hop.kak.git %{
	evaluate-commands %sh{ hop-kak --init }
	declare-option str hop_keyset 'heatrsiyoudnmkplf'  # beakl wi layout

	define-command hop-kak %{
		evaluate-commands -no-hooks -- %sh{ hop-kak --keyset "$kak_opt_hop_keyset" --sels "$kak_selections_desc" }
	}

	define-command hop-kak-sel %{
		execute-keys 'gtGbxs<ret>'
		hop-kak
	}

	define-command hop-kak-words %{
		execute-keys 'gtGbxs\w+<ret>'
		hop-kak
	}

	addm %{ alpha : map global edit h ': hop-kak-sel<ret>'   -docstring 'hint      —— /register,words' }
	addm %{ alpha : map global edit H ': hop-kak-words<ret>' -docstring 'hint      —— /register,words' }
	map global normal <a-h> ': hop-kak-sel<ret>'   -docstring 'find selection (on page)'
	map global normal <a-H> ': hop-kak-words<ret>' -docstring 'find word (on page)'
} %{
	cargo install hop-kak
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

	# Usage: peneira '<input prompt>' %{ <shell command returning list> } %{ <command> %arg{1} }
	define-command buffers %{
		peneira-resync
		# peneira 'buffers: ' %{ printf '%s\n' $kak_quoted_buflist } %{ buffer %arg{1} }  # NOTE: documented usage assumes non-space filenames
		peneira 'buffers: ' %{ printf '%s\n' "$kak_quoted_buflist" | sed -e "s/' '/\n/g; s/^'//; s/'$//" } %{ buffer %arg{1} }
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

	addm %{ meta  0 : map global buffer <ret> ': buffers<ret>' -docstring 'buffers' }
	addm %{ alpha 5 : map global buffer e     ': files<ret>'   -docstring 'edit file' }
	addm %{ alpha   : map global edit   f     ': lines<ret>'   -docstring '*fuzzy match line' }
	addm %{ alpha   : map global edit   c     ': symbols<ret>' -docstring 'ctag symbols' }
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
