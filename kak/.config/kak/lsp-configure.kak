# sdothum - 2016 (c) wtfpl

# Kakoune
# ══════════════════════════════════════════════════════════════════════════════

# LSP server
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# ...................................................................... kak-lsp

# NOTE: bundle replaced by void xbps package and setup in autoload
# nop evaluate-commands %sh{ kak-lsp -s $kak_session --kakoune }  # NOTE: autoload overrides this statement
set-option global lsp_cmd /opt/kak-lsp/bin/kak-lsp  # patched to suppress extension/statusUpdate messages
set-option global lsp_snippet_support false
set global lsp_debug false

declare-option str linemark '►'                                      # diagnostic line marker
set-option global lsp_diagnostic_line_error_sign   "%opt{linemark}"  # lsp glyph overrides
set-option global lsp_diagnostic_line_hint_sign    "%opt{linemark}"
set-option global lsp_diagnostic_line_info_sign    "%opt{linemark}"
set-option global lsp_diagnostic_line_warning_sign "%opt{linemark}"
set-option global lsp_inlay_diagnostic_sign        ''               # diagnostic fence meter (visual ticks replace ■'s)

hook global KakEnd .* lsp-exit

hook global WinSetOption filetype=(c|cpp|go|javascript|latex|lua|markdown|nim|perl|python|ruby|rust|toml|typescript) %{
	lsp-enable-window
	lsp-auto-hover-buffer-enable

	map global object a     '<a-semicolon>lsp-object<ret>'                               -docstring 'LSP any symbol'
	map global object <a-a> '<a-semicolon>lsp-object<ret>'                               -docstring 'LSP any symbol'
	map global object e     '<a-semicolon>lsp-object Function Method<ret>'               -docstring 'LSP function or method'
	map global object k     '<a-semicolon>lsp-object Class Interface Struct<ret>'        -docstring 'LSP class interface or struct'
	map global object d     '<a-semicolon>lsp-diagnostic-object --include-warnings<ret>' -docstring 'LSP errors and warnings'
	map global object D     '<a-semicolon>lsp-diagnostic-object<ret>'                    -docstring 'LSP errors'
}

hook global WinSetOption filetype=markdown %{
	lsp-inlay-diagnostics-enable global  # messages truncated at window width
	colorscheme %opt{theme}  # FOR: restore Diagnostic faces (overwritten by lsp injection)
}

hook global WinSetOption filetype=(c|cpp|go|lua|nim|perl|python|ruby|rust) %{
    hook window -group semantic-tokens BufReload    .* lsp-semantic-tokens
    hook window -group semantic-tokens NormalIdle   .* lsp-semantic-tokens
    hook window -group semantic-tokens InsertIdle   .* lsp-semantic-tokens
    hook window -once -always WinSetOption filetype=.* %{
        remove-hooks window semantic-tokens
    }
}

addm %{ usermode l : map global select L ': enter-user-mode lsp<ret>' -docstring "LSP mode" }

# ................................................................ nimlangserver

# override servers.kak nimlsp reference
remove-hooks global lsp-filetype-nim

hook -group user-lsp-nim global BufSetOption filetype=nim %{
	set-option buffer lsp_servers %{
		[nimlangserver]
		root_globs = ["*.nimble", ".git", ".hg"]
		command = "/opt/nimlangserver/bin/nimlangserver"  # patched to fix ProgressToken error (and resultant messages)

		[nimlangserver.settings.nim]
		notificationVerbosity = "none"
	}
}
# ...................................................................... ltex-ls

# markdown dictionary
define-command -hidden ltex-configure %{
	evaluate-commands %sh{
      dictionary=$(cat "$kak_config/dictionary.txt")

		printf 'set-option buffer lsp_servers %%{
	[ltex-ls]
	root_globs = [".git"]
	command = "/opt/ltex-ls/bin/ltex-ls"
	settings_section = "ltex"

	[ltex-ls.settings.ltex]
	language = "en-US"
	disabledRules = { "en-US" = ["PROFANITY"] }
	dictionary = { "en-US" = [
%s
	] }
}
' "$dictionary"
	}
}

# .......................................................... Markdown dictionary

hook -group user-lsp-markdown global BufSetOption filetype=markdown %{
	ltex-configure
}

define-command -hidden ltex-dictionary-add %{
	execute-keys <a-i>w
	nop %sh{
		printf '"%s",\n' "$kak_selection" >> "$kak_config/dictionary.txt"
	}
	ltex-configure
}

map global normal @ ': ltex-dictionary-add<ret>' -docstring 'add word to dictionary'

# kak: filetype=kak
