# sdothum - 2016 (c) wtfpl

# Kakoune
# ══════════════════════════════════════════════════════════════════════════════

# Modal UI
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# ............................................................. Te.kakrm colorscheme

bundle-theme duochrome https://github.com/sdothum/duochrome.kak.git
# modal colorscheme switcher
bundle colorscheme https://github.com/sdothum/colorscheme.kak.git

# Info notifier
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

define-command -hidden info-notifier -params 2 %{
	info -style modal -title %arg{1} %sh{ echo "$2" }
	nop %sh{ sleep 3 }
	info -style modal
}

# Cursor
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# .................................................................... Scrolling

# lines and columns displayed around the cursor (margins)
declare-option bool typewriter

define-command -hidden cursor-mode %{
	if-else %{ [ "$kak_opt_typewriter" = true ] } %{
		set-option global scrolloff %sh{ printf '%s,30' $(( $kak_window_height / 2 )) }  # centered cursor (row) for "freehand writing"
		set-option window typewriter false
	} %{
		set-option global scrolloff 5,15
		set-option window typewriter true
	}
}

# more granular scrolling than <c-d> and <c-u> while holding visual cursor position within screen
map global normal <up>   'vkk' -docstring 'scroll up one row'  # sort of a toss whether to use cursor keys or "kj"
map global normal <down> 'vjj' -docstring 'scroll down one row'

addm %{ focus t : map global select t   ': cursor-mode<ret>'  -docstring "typewriter scroll" }

hook global WinSetOption filetype=markdown %{ set-option window typewriter true }
hook global WinDisplay .* %{ cursor-mode }

# UI
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# ....................................................................... Screen

# set-option global ui_options terminal_status_on_top=true terminal_assistant=cat
# set-option global ui_options terminal_status_on_top=true
set-option global ui_options terminal_assistant=none

# ................................................................. Line numbers

# modal line numbers
declare-option str ruler '│'

if %{ [ -n "$RULER" ] } %{ set-option global ruler %sh{ echo "$RULER" }}  # SEE: statusline and kak wrapper

# assign highlighter name "number-lines" for peneira compatibility
define-command -hidden margin -params ..1 %{ evaluate-commands add-highlighter -override window/number-lines number-lines -hlcursor -separator "'%opt{ruler}   '" %arg{@} }  # escape 'quotes' for eval

hook global WinCreate .* %{
	margin '-relative'  # on normal mode open
	hook window ModeChange (push|pop):.*:insert margin
	hook window ModeChange (push|pop):insert:.* %{ margin '-relative' }
}

# .................................................................... Line wrap

declare-option bool hardwrap false  # SEE: refold

define-command hardwrap -params 1 %{ autowrap-enable; set-option window hardwrap true; set-option window autowrap_column %arg{1} }
define-command softwrap -params ..1 %{ autowrap-disable; evaluate-commands add-highlighter -override window/wrap wrap -word -indent -marker "'  ↪ '" %arg{@} }  # escape 'quotes' for eval
define-command nowrap %{ remove-highlighter window/wrap }

hook global WinSetOption filetype=markdown %{ hardwrap '80' }
hook global WinSetOption filetype=json     %{ softwrap '-width 275' }
hook global WinSetOption filetype=(sh|c|cpp|fish|go|javascript|latex|lua|perl|python|ruby|rust|toml|typescript) softwrap
hook global WinSetOption .*(conf|config|log|rc|text|txt) softwrap

# ................................................................. Highlighting

add-highlighter global/ show-matching
add-highlighter global/ show-whitespaces -tab '┊' -tabpad ' ' -spc ' ' -lf ' ' -indent ' '  # NOTE: default -indent '│' overridden for find.kak columnar "source : text" view

# search matches
# add-highlighter global/ dynregex '%reg{/}' 0:+u
# add-highlighter global/ dynregex '%reg{/}' 0:SecondarySelection  # SEE: colors/duochrome add-highlighter window/

# highlight trailing whitespace
add-highlighter global/ regex \h+$ 0:Trailing

# Statusline
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# ..................................................................... Kak info

# a minimalist statusline of "mode - column [utf-8] - filename [context]"
declare-option str spacer '  '
if-else %{ [ "$kak_opt_ruler" = " " ] } %{
	declare-option str colsep ":"
} %{
	declare-option str colsep "%opt{ruler} "
}

# display utf-8 value for non-latin characters (except U+000a linefeed) NOTE: continuation lines insert a space into the modeline
set-option global modelinefmt '
%sh{ capslock && echo "—CAPS— ${kak_opt_spacer}" }
{{mode_info}}
%opt{spacer}
%val{buf_line_count}%opt{colsep}%val{cursor_char_column}%sh{ [ "$kak_cursor_char_value" -lt 32 ] && [ "$kak_cursor_char_value" -ne 10 ] || [ "$kak_cursor_char_value" -gt 126 ] && printf " U+%04x" "$kak_cursor_char_value" }
%opt{spacer}
%val{bufname}{{context_info}}
[%sh{ [ -z "$kak_opt_filetype" ] && echo "--" || echo "$kak_opt_filetype" }]
%opt{spacer}
%val{session}(%sh{ echo "$kak_client" | sed -r "s/[^0-9]*(.*)/\1/" })
'

# kak: filetype=kak
