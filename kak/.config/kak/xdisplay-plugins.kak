# sdothum - 2016 (c) wtfpl

# Kakoune
# ══════════════════════════════════════════════════════════════════════════════

# Terminal $DISPLAY plugins
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# .......................................................................... hop
bundle-install-hook hop.kak %{
	cargo install hop-kak
}

bundle hop.kak https://github.com/hadronized/hop.kak.git %{
	nop evaluate-commands %sh{ hop-kak --init }
	declare-option str keyset 'heatrskplfyoudnm'

	define-command -override hop-kak %{
		exec ': evaluate-commands -no-hooks -- %sh{ hop-kak --keyset "$kak_opt_keyset" --sels "$kak_selections_desc" }<ret>'
	}

	define-command -override hop-kak-words %{
		exec 'gtGbxs\w+<ret>: evaluate-commands -no-hooks -- %sh{ hop-kak --keyset "$kak_opt_keyset" --sels "$kak_selections_desc" }<ret>'
	}

	defer %{ alpha : map global user h ': hop-kak<ret>'       -docstring 'hop selection,word' }
	defer %{ alpha : map global user H ': hop-kak-words<ret>' -docstring 'hop selection,word' }
}

# ......................................................... kakboard (clipboard)

bundle kakboard https://github.com/lePerdu/kakboard.git %{
	# HISTORY: cb replaces "xclip {-in, -out} -selection clipboard"
	set global kakboard_copy_cmd 'cb copy'
	set global kakboard_paste_cmd 'cb paste'
	hook global WinCreate .* %{ kakboard-enable }

	defer %{ alpha : map global user y ': kakboard-with-push-clipboard y<ret>' -docstring 'cb yank' }
	defer %{ alpha : map global user c ': kakboard-with-push-clipboard d<ret>' -docstring 'cb cut' }
	defer %{ alpha : map global user p ': kakboard-with-pull-clipboard p<ret>' -docstring 'cb put after,before' }
	defer %{ alpha : map global user P ': kakboard-with-pull-clipboard P<ret>' -docstring 'cb put after,before' }
	defer %{ alpha : map global user R ': kakboard-with-pull-clipboard R<ret>' -docstring 'cb replace' }
}

# ...................................................................... kak-lsp
bundle-install-hook kakoune-lsp %{
	# cargo install --locked --force --path .
	cargo install kak-lsp
}

bundle kakoune-lsp https://github.com/kakoune-lsp/kakoune-lsp.git %{
	# currently running commit 36f99810bdcc060617479d6c5405e868584ef0ff BUG: lsp-inlay-diagnostics-enable command option
	# cargo install --locked --force --path .
	# diff kak-lsp.toml $HOME/.config/kak/kak-lsp/kak-lsp.toml.unmarksman
	nop evaluate-commands %sh{ kak-lsp -s $kak_session --kakoune }

	set-option global lsp_cmd "kak-lsp -v -c $HOME/.config/kak-lsp/kak-lsp.toml -s %val{session} --log /tmp/kak-lsp.log"  # debug lsp with -vvv
	declare-option str linemark '►'                                      # diagnostic line marker
	set-option global lsp_diagnostic_line_error_sign   "%opt{linemark}"  # lsp glyph overrides
	set-option global lsp_diagnostic_line_hint_sign    "%opt{linemark}"
	set-option global lsp_diagnostic_line_info_sign    "%opt{linemark}"
	set-option global lsp_diagnostic_line_warning_sign "%opt{linemark}"
	set-option global lsp_inlay_diagnostic_sign        ''               # diagnostic fence meter (visual ticks replace ■'s)

	define-command lsp-restart %{ lsp-stop; lsp-start } -docstring 'restart lsp server'

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

	defer %{ alpha : map global user l ': enter-user-mode lsp<ret>' -docstring "LSP mode" }
}

# ............................................................. kakoune-livedown
bundle-install-hook kakoune-livedown %{
	sudo npm install -g livedown
}

bundle kakoune-livedown https://github.com/Delapouite/kakoune-livedown.git %{
	declare-option str livedown ''
	set-option global livedown_browser "qutebrowser-instance"

	define-command enable-livedown %{
		set-option global livedown "%val{bufname}"
		livedown-start-with-write-on-idle
	}

	define-command disable-livedown %{
		if %{ [ -n "$kak_opt_livedown" ] } %{
			set-option global livedown ''
			livedown-stop  # close browser instance
		}
	}

	hook -once global BufSetOption filetype=markdown enable-livedown
	hook       global BufClose     .*                disable-livedown
}

# ...................................................................... kakpipe
bundle-install-hook kakpipe %{
	# cargo install --path . --root ~/.local
	cargo install kakpipe
}

bundle kakpipe https://github.com/eburghar/kakpipe.git %{
	require-module kakpipe

	# defer %{ shell p : map global user | 'x: kakpipe ' -docstring "kakpipe FIFO buffer" }
	map global normal | 'x|' -docstring "pipe FIFO buffer"
}

# ........................................................................ popup

bundle popup.kak https://github.com/enricozb/popup.kak.git %{
	evaluate-commands %sh{ kak-popup init }
}

# ....................................................................... splash

# bundle splash.kak https://github.com/ftonneau/splash.kak.git
bundle splash.kak https://github.com/Hjagu09/splash.kak.git

# kak: filetype=kak
