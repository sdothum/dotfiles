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

	addmodes %{ snippet 0 : map global edit '%' ': snippets ' -docstring 'snippets' }
	addmodes %{ snippet 1 : map global edit 'N' 'Z,c'         -docstring 'snippet first,next placeholder' }
	addmodes %{ snippet 1 : map global edit 'n' 'z)Z,c'       -docstring 'snippet first,next placeholder' }
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
