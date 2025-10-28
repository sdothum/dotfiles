# sdothum - 2016 (c) wtfpl

# Kakoune
# ══════════════════════════════════════════════════════════════════════════════

# Terminal $DISPLAY plugins
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# ...................................................................... kak-lsp

bundle kakoune-lsp https://github.com/kakoune-lsp/kakoune-lsp.git %{
	# diff kak-lsp.toml $HOME/.config/kak/kak-lsp/kak-lsp.toml.unmarksman
	set-option global lsp_snippet_support false
	nop evaluate-commands %sh{ kak-lsp -s $kak_session --kakoune }
	# set global lsp_debug true  # FOR: kak-lsp v18.x

	# set-option global lsp_cmd "kak-lsp -v -c $HOME/.config/kak-lsp/kak-lsp.toml -s %val{session} --log /tmp/kak-lsp.log"  # debug lsp with -vvv FOR: kak-lsp v17.x
	# set-option global lsp_cmd "kak-lsp --debug -c $HOME/.config/kak-lsp/kak-lsp.toml -s %val{session} --log /tmp/kak-lsp.log"  # FOR: kak-lsp v18.x
	set-option global lsp_cmd "kak-lsp -c $HOME/.config/kak-lsp/kak-lsp.toml -s %val{session} --log /tmp/kak-lsp.log"
	declare-option str linemark '►'                                      # diagnostic line marker
	set-option global lsp_diagnostic_line_error_sign   "%opt{linemark}"  # lsp glyph overrides
	set-option global lsp_diagnostic_line_hint_sign    "%opt{linemark}"
	set-option global lsp_diagnostic_line_info_sign    "%opt{linemark}"
	set-option global lsp_diagnostic_line_warning_sign "%opt{linemark}"
	set-option global lsp_inlay_diagnostic_sign        ''               # diagnostic fence meter (visual ticks replace ■'s)

	# define-command lsp-restart %{ lsp-stop; lsp-start } -docstring 'restart lsp server'  # NOTE: for kak-lsp v17.2.1

	hook global KakEnd .* lsp-exit

	hook global WinSetOption filetype=(sh|c|cpp|go|javascript|latex|lua|markdown|perl|python|ruby|rust|toml|typescript) %{
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

	addm %{ mode l : map global select L ': enter-user-mode lsp<ret>' -docstring "LSP mode" }
} %{
	# nop # NOTE: freezing kak-lsp at v17.2.1 for now due to change from TOML file for kak-lsp configuraton
	cargo install --locked --force --path .
	# cargo install kak-lsp
}

# ............................................................. kakoune-livedown

# (??) filenames with special characters "()" do not live update, requiring manual browser refresh

bundle kakoune-livedown https://github.com/Delapouite/kakoune-livedown.git %{
	declare-option str livedown ''
	set-option global livedown_browser "qutebrowser-instance"

	define-command livedown-enable %{
		if %{ [ ${kak_bufname##*.} != 'eml' ] } %{  # exclude mail compose
			set-option global livedown "%val{bufname}"
			# livedown-start-with-write-on-idle  # NOTE: InsertIdle hook forces char by char "undo" action, instead..
			livedown-start
			hook -group livedown-idle buffer NormalIdle .* %{ eval -no-hooks write }  # "normal" mode refresh
		}
	}

	define-command livedown-disable %{
		if %{ [ -n "$kak_opt_livedown" ] } %{
			set-option global livedown ''
			livedown-stop  # close browser instance
		}
	}

	hook -once global BufSetOption filetype=markdown livedown-enable
	hook       global BufClose     .*                livedown-disable
} %{
	sudo npm install -g livedown
}

# ........................................................................ popup

bundle popup.kak https://github.com/enricozb/popup.kak.git %{
	evaluate-commands %sh{ kak-popup init }
}

# ....................................................................... splash

bundle splash.kak https://github.com/Hjagu09/splash.kak.git

# kak: filetype=kak
