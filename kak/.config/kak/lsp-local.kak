# sdothum - 2016 (c) wtfpl

# Kakoune
# ══════════════════════════════════════════════════════════════════════════════

# Terminal $DISPLAY plugins
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# ...................................................................... kak-lsp

# override servers.kak nimlsp reference
remove-hooks global lsp-filetype-nim

hook -group user-lsp-nim global BufSetOption filetype=nim %{
	set-option buffer lsp_servers %{
		[nimlangserver]
		root_globs = ["*.nimble", ".git", ".hg"]
	}
}

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
