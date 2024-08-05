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
	push %{ alpha : map global user f ': find ' -docstring "find and replace" }
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

	define-command symbols %{
		peneira-resync
		peneira-symbols
	}

	push %{ buffer  : map global buffer <ret> ': buffers<ret>' -docstring 'buffers' }
	push %{ alpha 1 : map global buffer f     ': files<ret>'   -docstring 'files' }
	push %{ alpha   : map global user   C     ': symbols<ret>' -docstring 'ctag symbols' }
}

# ............................................................ phantom selection

bundle kakoune-phantom-selection https://github.com/occivink/kakoune-phantom-selection.git

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

# ..................................................................... snippets

bundle kakoune-snippets https://github.com/occivink/kakoune-snippets.git %{
	set-option global snippets_auto_expand true

	hook -once global BufSetOption .* %{
		set buffer snippets %opt{snippets}  # keep any global snippets
	}

	hook -once global BufSetOption filetype=sh %{
		set -add buffer snippets 'usage:'     '%us' %{ snippets-insert %{usage() { usage: "$(basename $0) ${1:options}"; exit 1; } }}
		set -add buffer snippets 'usage:pipe' '%up' %{ snippets-insert %{usage() { usage: "$(basename $0) ${1:options}" | usage:pipe
		exit 1
	} }}
	}

	hook -once global BufSetOption filetype=markdown %{
		set -add buffer snippets 'date'   '%da' %{ snippets-insert %sh{ date '+## %A, %d %B %Y' | tr '[:upper:]' '[:lower:]' }}
		set -add buffer snippets 'img'    '%im' %{ snippets-insert %{![${1:heading}](/images/${2:file}.jpg) }}
		set -add buffer snippets 'search' '%se' %{ snippets-insert %{[${1:description}](http://thedarnedestthing.com/search?query=${2:query}) }}
	}

	push %{ snippet : map global user '%' ': snippets ' -docstring 'snippets' }
}

# ................................................................... sudo-write

bundle kakoune-sudo-write https://github.com/occivink/kakoune-sudo-write.git

# .................................................................. tree-sitter
bundle-install-hook kak-tree-sitter %{
	cargo install kak-tree-sitter
	cargo install ktsctl
}

bundle kak-tree-sitter https://github.com/phaazon/kak-tree-sitter.git %{
	nop evaluate-commands %sh{ kak-tree-sitter -d -k --init $kak_session -s }
}

# kak: filetype=kak
