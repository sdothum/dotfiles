# sdothum - 2016 (c) wtfpl

# Kakoune
# ══════════════════════════════════════════════════════════════════════════════

# Terminal $DISPLAY plugins
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

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
