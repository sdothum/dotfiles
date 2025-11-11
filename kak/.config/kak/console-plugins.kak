# sdothum - 2016 (c) wtfpl

# Kakoune
# ══════════════════════════════════════════════════════════════════════════════

# WHEN: unloaded plugin testing renders these commnads unavaileble elsewhere SEE: ux.kak
define-command console-plugins %{ nop }  # USAGE: try %{ console-plugins } catch %{ define-command <command> %{ nop }}

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
	define-command -hidden change-directory-current-buffer %{ nop }
}

# ................................................................... crosshairs

bundle kak-crosshairs https://github.com/insipx/kak-crosshairs.git %{
	addm %{ focus x1 : map global select + ': crosshairs<ret>'   -docstring "visual     —— crosshairs,column,line" }
	addm %{ focus x2 : map global select | ': cursorcolumn<ret>' -docstring "visual     —— crosshairs,column,line" }
	addm %{ focus x3 : map global select _ ': cursorline<ret>'   -docstring "visual     —— crosshairs,column,line" }
	cursorline
}

# ........................................................................ fandt

nop bundle kakoune-fandt https://github.com/listentolist/kakoune-fandt.git %{
	require-module fandt
}

# ............................................................. find and replace

bundle kakoune-search https://github.com/sdothum/kakoune-search.git %{
	define-command -hidden commit-edits %{
		if-else %{ [ "$kak_bufname" = '*search*' ] } %{
			search-apply-changes
		} %{
			buffer '*search*'
			echo  # clear any buffer error message
			if %{ [ "$kak_bufname" = '*search*' ] } %{ info 'redo "<space> &" to commit edits' }
		}
	}

	# NOTE: <ret> jumps to buffer line
	addm %{ goto   z  : map global buffer '\' ': search '           -docstring "search buffers" }
	addm %{ search z1 : map global select '\' ': search '           -docstring "search     —— buffers,commit edits" }
	addm %{ search z2 : map global select &   ': commit-edits<ret>' -docstring "search     —— buffers,commit edits" }
	map global normal '\' ': search ' -docstring "search buffers"
}

# ............................................................. focus selections

bundle kakoune-focus https://github.com/caksoylar/kakoune-focus.git %{
	declare-option -hidden str focus_sep '━'
	# force uniform separator highlighting SEE: colors/duochrome
	evaluate-commands %sh{ printf "set-option global focus_separator '{FocusSeparator}"; for i in $(seq 1 132) ;do printf "${kak_opt_focus_sep}" ;done; printf "'" }

	set-option global focus_context_lines 1
	declare-option str focus "off"
	declare-option int focus_line 0

	define-command -hidden focus-message %{
		nop %sh{ notify 20 critical "focus selections" "&lt;<b>a-n</b>&gt;,<b>n</b>\t(deselect) then prev,next\n&lt;<b>a-N</b>&gt;,<b>N</b>\t(select)   then prev,next" }
	}

	# manage focus view to show maximum selections
	define-command -hidden toggle-focus %{
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

	addm %{ focus 0 : map global select <space> ': toggle-focus<ret>' -docstring "focus selections" }
}

# .......................................................................... hop

bundle hop.kak https://github.com/hadronized/hop.kak.git %{
	evaluate-commands %sh{ hop-kak --init }
	declare-option str hop_keyset 'heatrsiyoudnmkplf'  # beakl wi layout

	define-command -hidden hop-kak %{
		evaluate-commands -no-hooks -- %sh{ hop-kak --keyset "$kak_opt_hop_keyset" --sels "$kak_selections_desc" }
	}

	define-command -hidden hop-kak-sel %{
		execute-keys 'gtGbxs<ret>'
		hop-kak
	}

	define-command -hidden hop-kak-words %{
		execute-keys 'gtGbxs\w+<ret>'
		hop-kak
	}

	addm %{ goto h1 : map global buffer h '*: hop-kak-sel<ret>' -docstring 'hint *selection,/register' }
	addm %{ goto h2 : map global buffer H ': hop-kak-sel<ret>'  -docstring 'hint *selection,/register' }
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
	define-command -hidden peneira-resync %{
		change-directory-current-buffer  # handled by hook FocusIn above, otherwise required
		buffer *debug*
		execute-keys ga
	}

	# Usage: peneira '<input prompt>' %{ <shell command returning list> } %{ <command> %arg{1} }
	define-command -hidden buffers %{
		peneira-resync
		# peneira 'buffers: ' %{ printf '%s\n' $kak_quoted_buflist } %{ buffer %arg{1} }  # NOTE: documented usage assumes non-space filenames
		peneira 'buffers: ' %{ printf '%s\n' "$kak_quoted_buflist" | sed -e "s/' '/\n/g; s/^'//; s/'$//" } %{ buffer %arg{1} }
	}

	define-command -hidden files %{
		peneira-resync
		peneira-files -hide-opened
	}

	define-command -hidden lines %{
		peneira-resync
		peneira-lines
	}

	define-command -hidden symbols %{
		peneira-resync
		peneira-symbols
	}

	addm %{ meta b : map global buffer <ret> ': buffers<ret>' -docstring 'buffers'      }
	addm %{ goto c : map global buffer c     ': symbols<ret>' -docstring 'ctag symbols' }
	addm %{ goto g : map global buffer g     ': lines<ret>'   -docstring 'fuzzy goto'   }
	addm %{ file 1 : map global buffer e     ': files<ret>'   -docstring 'edit file'    }
}

# ...................................................................... kakpipe

bundle kakpipe https://github.com/eburghar/kakpipe.git %{
	require-module kakpipe

	# HACK: using alpha subsort to overcome "P,p" sort order (cause unknown)
	addm %{ test p1 : map global buffer p ': kakpipe '    -docstring "pipe      —— *scratch*,(background)" }
	addm %{ test p2 : map global buffer P ': kakpipe-bg ' -docstring "pipe      —— *scratch*,(background)" }
} %{
	cargo install --path . --root ~/.local
}

# .................................................................. Reasymotion

bundle reasymotion https://github.com/astaugaard/reasymotion.git %{
	evaluate-commands %sh{ rkak_easymotion start }

	addm %{ goto m1 : map global buffer m ': reasymotion-on-letter-to-word<ret>'          -docstring 'ezmotion  —— to word,letter'   }
	addm %{ goto m2 : map global buffer M ': reasymotion-on-letter-to-letter<ret>'        -docstring 'ezmotion  —— to word,letter'   }
	addm %{ goto m3 : map global buffer n ': reasymotion-on-letter-to-word-expand<ret>'   -docstring '⠀         —— expand to word,letter' }
	addm %{ goto m4 : map global buffer N ': reasymotion-on-letter-to-letter-expand<ret>' -docstring '⠀         —— expand to word,letter' }
} %{
	cargo install --path .
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
