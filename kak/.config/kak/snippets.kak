# sdothum - 2016 (c) wtfpl

# Kakoune
# ══════════════════════════════════════════════════════════════════════════════

# Snippets
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# ....................................................................... plugin

bundle kakoune-snippets https://github.com/occivink/kakoune-snippets.git %{
	set-option global snippets_auto_expand true

	hook -once global BufSetOption .* %{
		set buffer snippets %opt{snippets}  # keep any global snippets
	}

	push %{ snippet : map global format '%' ': snippets ' -docstring 'snippets' }
}

# ........................................................................ shell

hook -once global BufSetOption filetype=sh %{
	set -add buffer snippets 'usage:'     '%us' %{ snippets-insert %{usage() { usage: "$(basename $0) ${1:options}"; exit 1; } }}
	set -add buffer snippets 'usage:pipe' '%up' %{ snippets-insert %{usage() { usage: "$(basename $0) ${1:options}" | usage:pipe
	exit 1
} }}
}

# ..................................................................... markdown

hook -once global BufSetOption filetype=markdown %{
	set -add buffer snippets 'date'   '%da' %{ snippets-insert %sh{ date '+## %A, %d %B %Y' | tr '[:upper:]' '[:lower:]' }}
	set -add buffer snippets 'img'    '%im' %{ snippets-insert %{![${1:heading}](/images/${2:file}.jpg) }}
	set -add buffer snippets 'search' '%se' %{ snippets-insert %{[${1:description}](http://thedarnedestthing.com/search?query=${2:query}) }}
}

# ......................................................................... mail

hook -once global BufSetOption filetype=mail %{
	set -add buffer snippets 'dad'     '%da' %{ snippets-insert %{:D(A):D }}
	set -add buffer snippets 'regards' '%re' %{ snippets-insert %{Regards,
Steven & Daisy }}
}

# kak: filetype=kak
