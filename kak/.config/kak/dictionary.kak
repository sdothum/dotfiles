# sdothum - 2016 (c) wtfpl

# Kakoune
# ══════════════════════════════════════════════════════════════════════════════

# Terminal $DISPLAY plugins
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# ...................................................................... kak-lsp

# markdown dictionary
hook -group user-lsp-markdown global BufSetOption filetype=markdown %{
	set-option buffer lsp_servers %{
		[ltex-ls]
		root_globs = [".git"]
		command = "/opt/ltex-ls/bin/ltex-ls"
		settings_section = "ltex"

		[ltex-ls.settings.ltex]
		language = "en-US"
		disabledRules = { "en-US" = ["PROFANITY"] }
		dictionary = { "en-US" = [
			"asymmetric",
			"beakl",
			"beaklwi",
			"bigram",
			"Calibre",
			"chording",
			"double-storey",
			"ebook",
			"econtent",
			"eink",
			"epub",
			"ereader",
			"ereaders",
			"ereading",
			"favour",
			"favourite",
			"frontlight",
			"graal",
			"groot",
			"grote",
			"kepub",
			"keyswitch",
			"keyswitches",
			"Kindle",
			"Kobo",
			"kobopatch",
			"kobopatches",
			"koreader",
			"licht",
			"lua",
			"lythe",
			"mobi",
			"pdf",
			"serifed",
			"single-storey",
			"stria",
			"trigram",
			"warmlight"
		] }
	}
}

# kak: filetype=kak
