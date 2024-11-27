# sdothum - 2016 (c) wtfpl

# Kakoune
# ══════════════════════════════════════════════════════════════════════════════

# Terminal $DISPLAY plugins
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# ......................................................... kakboard (clipboard)

bundle kakboard https://github.com/lePerdu/kakboard.git %{
	# HISTORY: cb replaces "xclip {-in, -out} -selection clipboard"
	set global kakboard_copy_cmd 'cb copy'
	set global kakboard_paste_cmd 'cb paste'
	hook global WinCreate .* %{ kakboard-enable }

	catch %{ alpha : map global user y ': kakboard-with-push-clipboard y<ret>' -docstring 'cb yank' }
	catch %{ alpha : map global user c ': kakboard-with-push-clipboard d<ret>' -docstring 'cb cut' }
	catch %{ alpha : map global user p ': kakboard-with-pull-clipboard p<ret>' -docstring 'cb put after,before' }
	catch %{ alpha : map global user P ': kakboard-with-pull-clipboard P<ret>' -docstring 'cb put after,before' }
	catch %{ alpha : map global user R ': kakboard-with-pull-clipboard R<ret>' -docstring 'cb replace' }
}

# ...................................................................... kak-lsp

bundle kakoune-lsp https://github.com/kakoune-lsp/kakoune-lsp.git %{
	# diff kak-lsp.toml $HOME/.config/kak/kak-lsp/kak-lsp.toml.unmarksman
	nop evaluate-commands %sh{ kak-lsp -s $kak_session --kakoune }

	set-option global lsp_cmd "kak-lsp -v -c $HOME/.config/kak-lsp/kak-lsp.toml -s %val{session} --log /tmp/kak-lsp.log"  # debug lsp with -vvv
	declare-option str linemark '►'                                      # diagnostic line marker
	set-option global lsp_diagnostic_line_error_sign   "%opt{linemark}"  # lsp glyph overrides
	set-option global lsp_diagnostic_line_hint_sign    "%opt{linemark}"
	set-option global lsp_diagnostic_line_info_sign    "%opt{linemark}"
	set-option global lsp_diagnostic_line_warning_sign "%opt{linemark}"
	set-option global lsp_inlay_diagnostic_sign        ''               # diagnostic fence meter (visual ticks replace ■'s)

	# define-command lsp-restart %{ lsp-stop; lsp-start } -docstring 'restart lsp server'

	hook global KakEnd .* lsp-exit

	hook global WinSetOption filetype=(sh|c|cpp|go|javascript|latex|lua|markdown|perl|python|ruby|rust|toml|typescript) %{
		lsp-enable-window
		lsp-auto-hover-enable
		lsp-inlay-diagnostics-enable global
		colorscheme %opt{theme}  # WHY: restore Diagnostic faces (overwritten by kak-lsp injection above)

		map global object a     '<a-semicolon>lsp-object<ret>'                               -docstring 'LSP any symbol'
		map global object <a-a> '<a-semicolon>lsp-object<ret>'                               -docstring 'LSP any symbol'
		map global object e     '<a-semicolon>lsp-object Function Method<ret>'               -docstring 'LSP function or method'
		map global object k     '<a-semicolon>lsp-object Class Interface Struct<ret>'        -docstring 'LSP class interface or struct'
		map global object d     '<a-semicolon>lsp-diagnostic-object --include-warnings<ret>' -docstring 'LSP errors and warnings'
		map global object D     '<a-semicolon>lsp-diagnostic-object<ret>'                    -docstring 'LSP errors'
		map global insert <tab> '<a-;>:try lsp-snippets-select-next-placeholders catch %{ execute-keys -with-hooks <lt>tab> }<ret>' -docstring 'Select next snippet placeholder'

	}

	catch %{ alpha : map global user l ': enter-user-mode lsp<ret>' -docstring "LSP mode" }
} %{
	# cargo install --locked --force --path .
	cargo install kak-lsp
}

# ............................................................. kakoune-livedown

bundle kakoune-livedown https://github.com/Delapouite/kakoune-livedown.git %{
	declare-option str livedown ''
	set-option global livedown_browser "qutebrowser-instance"

	define-command enable-livedown %{
		if %{ [ ${kak_bufname##*.} != 'eml' ] } %{  # exclude mail compose
			set-option global livedown "%val{bufname}"
			livedown-start-with-write-on-idle
		}
	}

	define-command disable-livedown %{
		if %{ [ -n "$kak_opt_livedown" ] } %{
			set-option global livedown ''
			livedown-stop  # close browser instance
		}
	}

	hook -once global BufSetOption filetype=markdown enable-livedown
	hook       global BufClose     .*                disable-livedown
} %{
	sudo npm install -g livedown
}

# ...................................................................... kakpipe

bundle kakpipe https://github.com/eburghar/kakpipe.git %{
	require-module kakpipe

	# HACK: using alpha subsort to overcome "P,p" sort order (cause unknown)
	catch %{ alpha 5 : map global buffer p ': kakpipe '    -docstring "kakpipe FIFO / bg" }
	catch %{ alpha 6 : map global buffer P ': kakpipe-bg ' -docstring "kakpipe FIFO / bg" }
} %{
	cargo install --path . --root ~/.local
}

# ........................................................................ popup

bundle popup.kak https://github.com/enricozb/popup.kak.git %{
	evaluate-commands %sh{ kak-popup init }
}

# ....................................................................... splash

# bundle splash.kak https://github.com/ftonneau/splash.kak.git
bundle splash.kak https://github.com/Hjagu09/splash.kak.git

# kak: filetype=kak
