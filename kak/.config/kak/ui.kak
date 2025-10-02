# sdothum - 2016 (c) wtfpl

# Kakoune
# ══════════════════════════════════════════════════════════════════════════════

# Modal UI
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# .................................................................. Colorscheme

if-else %{ [ -n "$DISPLAY" ] } %{
	declare-option str theme 'duochrome'
	declare-option str mode  'normal'  # initial state
	declare-option str color ''        # force colorscheme initialization

	# NOTE: "echo" to clear statusline filename from caplock switching

	define-command normal-mode-colorscheme %{
		set-option window mode "normal"
		if %{ [ "$kak_opt_color" != "normal" ] } %{
			trace %{ normal-mode-colorscheme }
			set-option window color "normal"
			colorscheme %opt{theme}
			echo
		}
	}

	define-command insert-mode-colorscheme %{
		set-option window mode "insert"
		if %{ [ "$kak_opt_color" != "insert" ] } %{
			trace %{ insert-mode-colorscheme }
			set-option window color "insert"
			colorscheme %opt{theme}
			echo
		}
	}

	define-command capslock-colorscheme %{
		if %{ [ "$kak_opt_color" != "capslock" ] } %{
			trace %{ capslock-colorscheme }
			set-option window color "capslock"
			colorscheme %opt{theme}
			echo
		}
	}

	# (??) capslock colorscheme switching defers until the first keystroke HACK: see sxhkdrc for Caps_Lock trigger
	define-command capslock-check %{
		trace %{ capslock-check }
		if-else %{ capslock } %{
			capslock-colorscheme
		} %{
			if-else %{ [ "$kak_opt_mode" = "insert" ] } %{
				insert-mode-colorscheme
			} %{
				normal-mode-colorscheme
			}
		}
	}

	# window modal/capslock "duo"chrome
	hook global WinCreate .* %{
		normal-mode-colorscheme
		hook window ModeChange (push|pop):.*:insert insert-mode-colorscheme
		hook window ModeChange (push|pop):insert:.* normal-mode-colorscheme
		hook window InsertIdle .*                   capslock-check
		hook window NormalIdle .*                   capslock-check
		hook window PromptIdle .*                   capslock-check
	}
} %{
	declare-option str theme %sh{ echo "${COLORSCHEME:-dabruin}" }
	colorscheme %opt{theme}
}

# push %{ alpha : map global edit <space> ': normal-mode-colorscheme<ret>' -docstring "%opt{theme}" }

# Info notifier
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

define-command info-notifier -params 2 %{
	info -style modal -title %arg{1} %sh{ echo "$2" }
	nop %sh{ sleep 3 }
	info -style modal
}

# Cursor
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# .................................................................... Scrolling

# lines and columns displayed around the cursor (margins)
declare-option bool typewriter

define-command cursor-mode %{
	if-else %{ [ "$kak_opt_typewriter" = true ] } %{
		set-option global scrolloff %sh{ printf '%s,30' $(( $kak_window_height / 2 )) }  # centered cursor (row) for "freehand writing"
		set-option window typewriter false
	} %{
		set-option global scrolloff 5,15
		set-option window typewriter true
	}
}

addm %{ meta 4 : map global buffer T   ': cursor-mode<ret>'  -docstring "typewriter scroll" }

hook global WinSetOption filetype=markdown %{ set-option window typewriter true }
hook global WinDisplay .* %{ cursor-mode }

# UI
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# ....................................................................... Screen

# set-option global ui_options terminal_status_on_top=true terminal_assistant=cat
# set-option global ui_options terminal_status_on_top=true
set-option global ui_options terminal_assistant=none

# similar to goto g BUT: preserves selections
define-command scroll-home %{
	evaluate-commands %sh{ for i in $(seq 1 $(( $kak_cursor_line / $(tput lines) )) ) ;do echo "execute-keys <pageup>" ;done  }
}

# ................................................................. Line numbers

# modal line numbers
declare-option str ruler '│'
if %{ [ -n "$RULER" ] } %{ set-option global ruler %sh{ echo "$RULER" }}  # SEE: statusline and kak wrapper

# assign highlighter name "number-lines" for peneira compatibility
define-command margin -params ..1 %{ evaluate-commands add-highlighter -override window/number-lines number-lines -hlcursor -separator "'%opt{ruler}   '" %arg{@} }  # escape 'quotes' for eval

hook global WinCreate .* %{
	margin '-relative'  # on normal mode open
	hook window ModeChange (push|pop):.*:insert margin
	hook window ModeChange (push|pop):insert:.* %{ margin '-relative' }
}

# .................................................................... Line wrap

declare-option bool hardwrap false  # SEE: refold

define-command hardwrap -params 1 %{ autowrap-enable; set-option window hardwrap true; set-option window autowrap_column %arg{1} }
define-command softwrap -params ..1 %{ evaluate-commands add-highlighter -override window/wrap wrap -word -indent -marker "'  ↪ '" %arg{@} }  # escape 'quotes' for eval
define-command nowrap %{ remove-highlighter window/wrap }

hook global WinSetOption filetype=markdown %{ hardwrap '80' }
hook global WinSetOption filetype=json     %{ softwrap '-width 250' }
hook global WinSetOption filetype=(sh|c|cpp|fish|go|javascript|latex|lua|perl|python|ruby|rust|toml|typescript) softwrap
hook global WinSetOption .*(conf|config|log|rc|text|txt) softwrap

# ................................................................. Highlighting

add-highlighter global/ show-matching
add-highlighter global/ show-whitespaces -tab '┊' -tabpad ' ' -spc ' ' -lf ' '

# search matches
# add-highlighter global/ dynregex '%reg{/}' 0:+u
# add-highlighter global/ dynregex '%reg{/}' 0:SecondarySelection  # SEE: colors/duochrome add-highlighter window/

# highlight trailing whitespace
add-highlighter global/ regex \h+$ 0:Trailing

# Statusline
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# ..................................................................... Kak info

# a minimalist statusline of "mode - column [utf-8] - filename [context]"
declare-option str spacer ' '
if-else %{ [ "$kak_opt_ruler" = " " ] } %{
	declare-option str colsep ":"
} %{
	declare-option str colsep "%opt{ruler} "
}

# display utf-8 value for non-latin characters (except U+000a linefeed)
set-option global modelinefmt '%sh{ capslock && echo "—CAPS— " }{{mode_info}} %opt{spacer} %val{buf_line_count}%opt{colsep}%val{cursor_char_column}%sh{ [ "$kak_cursor_char_value" -lt 32 ] && [ "$kak_cursor_char_value" -ne 10 ] || [ "$kak_cursor_char_value" -gt 126 ] && printf " U+%04x" "$kak_cursor_char_value" } %opt{spacer} %val{bufname}{{context_info}} [%sh{ [ -z "$kak_opt_filetype" ] && echo "--" || echo "$kak_opt_filetype" }] %opt{spacer} %val{session}(%sh{ echo "$kak_client" | sed -r "s/[^0-9]*(.*)/\1/" })'

# kak: filetype=kak
