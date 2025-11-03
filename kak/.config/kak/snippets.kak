# sdothum - 2016 (c) wtfpl

# Kakoune
# ══════════════════════════════════════════════════════════════════════════════

# Snippets
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# ....................................................................... plugin

bundle kakoune-snippets https://github.com/occivink/kakoune-snippets.git %{
	set-option global snippets_auto_expand true

	hook global BufSetOption .* %{
		set-option buffer snippets %opt{snippets}  # keep any global snippets
	}

	set-option -add global snippets 'wtfpl' '%wt' %{ snippets-insert %sh{ printf "# sdothum - $(date '+%Y') (c) wtfpl\n\${}" }}
	# SEE: bin/functions/edit/kaktype script
	set-option -add global snippets 'kak:'  '%ka' %{ snippets-insert %sh{ kaktype "$kak_opt_filetype" }}

	addm %{ paste s0 : map global select '%'       ': snippets ' -docstring 'snippets' }
	addm %{ paste s1 : map global select '<tab>'   'Z,c'         -docstring 'snippets   —— first,next field' }
	addm %{ paste s2 : map global select '<s-tab>' 'z)Z,c'       -docstring 'snippets   —— first,next field' }

	map global insert <tab>   '<esc>Z,c'   -docstring 'select initial snippet tab'
	map global insert <s-tab> '<esc>z)Z,c' -docstring 'select next snippet tab'
}

# ........................................................................ shell

hook global BufSetOption filetype=sh %{
	set-option -add buffer snippets 'usage:'     '%us' %{ snippets-insert %{usage() { usage: "$(basename $0) ${options}"; exit 1; } }}
	set-option -add buffer snippets 'USAGE:'     '%US' %{ snippets-insert %{usage() { echo "$(basename $0) ${options}" | usage:
	exit 1
} }}
	set-option -add buffer snippets 'usage:pipe' '%up' %{ snippets-insert %{usage() { echo "$(basename $0) ${options}" | usage:pipe
	exit 1
} }}
}

# ..................................................................... markdown

hook global BufSetOption filetype=markdown %{
	set-option -add buffer snippets 'date'   '%da' %{ snippets-insert %sh{ date '+## %A, %d %B %Y' | tr '[:upper:]' '[:lower:]' }}
	set-option -add buffer snippets 'img'    '%im' %{ snippets-insert %{![${title}](/images/${file}.jpg) }}
	set-option -add buffer snippets 'search' '%se' %{ snippets-insert %{[${text}](http://thedarnedestthing.com/search?query=${query}) }}
}

# ......................................................................... mail

hook global BufSetOption filetype=mail %{
	set-option -add buffer snippets 'dad'     '%da' %{ snippets-insert %{:D(A):D }}
	set-option -add buffer snippets 'regards' '%re' %{ snippets-insert %{Regards,
Steven & Daisy }}
}

# kak: filetype=kak
