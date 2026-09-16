# sdothum - 2016 (c) wtfpl

# Kakoune
# ══════════════════════════════════════════════════════════════════════════════

# Terminal $DISPLAY plugins
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# ...................................................................... kak-lsp

# NOTE: bundle replaced by void xbps package and setup in autoload
nop evaluate-commands %sh{ kak-lsp -s $kak_session --kakoune }
set-option global lsp_snippet_support false
# set global lsp_debug true

declare-option str linemark '►'                                      # diagnostic line marker
set-option global lsp_diagnostic_line_error_sign   "%opt{linemark}"  # lsp glyph overrides
set-option global lsp_diagnostic_line_hint_sign    "%opt{linemark}"
set-option global lsp_diagnostic_line_info_sign    "%opt{linemark}"
set-option global lsp_diagnostic_line_warning_sign "%opt{linemark}"
set-option global lsp_inlay_diagnostic_sign        ''               # diagnostic fence meter (visual ticks replace ■'s)

hook global KakEnd .* lsp-exit

hook global WinSetOption filetype=(c|cpp|go|javascript|latex|lua|markdown|nim|perl|python|ruby|rust|toml|typescript) %{
	lsp-enable-window
	# lsp-inlay-diagnostics-enable global  # too visually noisy (and truncated at window width)
	lsp-auto-hover-buffer-enable
	colorscheme %opt{theme}  # WHY: restore Diagnostic faces (overwritten by kak-lsp injection above)

	map global object a     '<a-semicolon>lsp-object<ret>'                               -docstring 'LSP any symbol'
	map global object <a-a> '<a-semicolon>lsp-object<ret>'                               -docstring 'LSP any symbol'
	map global object e     '<a-semicolon>lsp-object Function Method<ret>'               -docstring 'LSP function or method'
	map global object k     '<a-semicolon>lsp-object Class Interface Struct<ret>'        -docstring 'LSP class interface or struct'
	map global object d     '<a-semicolon>lsp-diagnostic-object --include-warnings<ret>' -docstring 'LSP errors and warnings'
	map global object D     '<a-semicolon>lsp-diagnostic-object<ret>'                    -docstring 'LSP errors'
}

nop hook global WinSetOption filetype=(c|cpp|go|lua|perl|python|ruby|rust) %{
    hook window -group semantic-tokens BufReload            .* lsp-semantic-tokens
    hook window -group semantic-tokens NormalIdle           .* lsp-semantic-tokens
    hook window -group semantic-tokens InsertIdle           .* lsp-semantic-tokens
    hook window -once -always window WinSetOption filetype=.* %{
        remove-hooks window semantic-tokens
    }
}

addm %{ usermode l : map global select L ': enter-user-mode lsp<ret>' -docstring "LSP mode" }

# ............................................................. kakoune-livedown

# (??) filenames with special characters "()" do not live update, requiring manual browser refresh

bundle kakoune-livedown https://github.com/Delapouite/kakoune-livedown.git %{
	declare-option str livedown ''
	set-option global livedown_browser "qutebrowser-instance"

	define-command -hidden livedown-enable %{
		if %{ [ "${kak_bufname##*.}" != 'eml' ] && [ "${kak_bufname%/*}" != "$HOME/diary"] } %{  # exclude mail compose
			set-option global livedown "%val{bufname}"
			# livedown-start-with-write-on-idle  # NOTE: InsertIdle hook forces char by char "undo" action, instead..
			livedown-start
			hook -group livedown-idle buffer NormalIdle .* %{ evaluate-commands -no-hooks write }  # "normal" mode refresh
		}
	}

	define-command -hidden livedown-disable %{
		if %{ [ -n "$kak_opt_livedown" ] } %{
			set-option global livedown ''
			livedown-stop  # close browser instance
		}
	}

	define-command -hidden toggle-livedown %{
		if-else %{ [ -z "$kak_opt_livedown" ] } %{
			livedown-enable
		} %{
			livedown-disable
		}
	}

	addm %{ meta l : map global buffer l ': toggle-livedown<ret>' -docstring 'livedown' }

	hook -once global WinSetOption filetype=markdown livedown-enable
	hook       global BufClose     .*                livedown-disable
	hook       global KakEnd       .*                %{ nop %sh{ xdotool search -classname "livedown" windowkill }}  # close browser
} %{
	sudo npm install -g livedown
}

# ........................................................................ popup

bundle popup https://github.com/enricozb/popup.kak.git %{
	evaluate-commands %sh{ kak-popup init }
}

# ....................................................................... splash

bundle splash https://github.com/Hjagu09/splash.kak.git
# bundle texture.kak https://github.com/ftonneau/texture.kak.git

# kak: filetype=kak
