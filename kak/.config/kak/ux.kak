# sdothum - 2016 (c) wtfpl

# Kakoune
# ══════════════════════════════════════════════════════════════════════════════

# Editing
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# ................................................................... Formatting

set-option global tabstop 3
set-option global indentwidth 3
declare-user-mode format

map global normal <c-l> ': comment-line<ret>' -docstring 'comment'  # beakl key position for "#" NOTE: <c-c> unmappable
map global normal '#'   ': enter-user-mode format<ret>'

# ................................................................... Commenting

defer %{ comment : map global format c       ': comment-line<ret>' -docstring 'comment' }
defer %{ comment : map global format l       'x|comment l .<ret>'  -docstring 'leader    ... xxx' }
defer %{ comment : map global format t       'x|comment t .<ret>'  -docstring 'trailer   xxx ...' }
defer %{ comment : map global format R       'x|comment r =<ret>'  -docstring 'ruler     ═══' }
defer %{ comment : map global format r       'x|comment r --<ret>' -docstring 'ruler     ━━━' }
defer %{ comment : map global format U       'x|comment u =<ret>'  -docstring 'underline ═══' }
defer %{ comment : map global format u       'x|comment u --<ret>' -docstring 'underline ━━━' }
defer %{ comment : map global format '`'     'x|comment c<ret>'    -docstring 'css       <code></code> block' }

# ..................................................................... Aligning

defer %{ align a : map global format <space> 'x|align '            -docstring 'align     '' '' nth+1 word' }
defer %{ align b : map global format <minus> 'x|align --<ret>'     -docstring 'align     --  comment' }
defer %{ align c : map global format '#'     'x|align \#<ret>'     -docstring 'align     #   comment' }
defer %{ align d : map global format /       'x|align //<ret>'     -docstring 'align     //  comment' }
defer %{ align e : map global format =       'x|align =<ret>'      -docstring 'align     =   statement' }
defer %[ align s : map global format {       'x|align \{<ret>'     -docstring 'align     {   block' ]  # ATTENTION: %[] to escape '{' :)
defer %{ align s : map global format )       'x|align \)<ret>'     -docstring 'align     )   case' }
defer %{ align s : map global format ';'     'x|align \;\;<ret>'   -docstring 'align     ;;  endcase' }
defer %{ align x : map global format '\'     'x|align \\<ret>'     -docstring 'align     \   continuation' }
defer %{ align x : map global format ','     'x|align \;\\<ret>'   -docstring 'align     ;\  continuation' }

# .................................................................... Searching

defer %{ focus s : map global user /   '/(?i)'     -docstring 'isearch prev,next' }
defer %{ focus s : map global user '\' '<a-/>(?i)' -docstring 'isearch prev,next' }
defer %{ focus x : map global user ?   '?(?i)'     -docstring 'iextend prev,next' }
defer %{ focus x : map global user !   '<a-?>(?i)' -docstring 'iextend prev,next' }

# .................................................................... Selection

defer %{ alpha : map global user s 'x<a-s>s'     -docstring 'split:select,iselect' }
defer %{ alpha : map global user S 'x<a-s>s(?i)' -docstring 'split:select,iselect' }

map global normal S 's(?i)'   -docstring 'case insensitive split:select:'
map global normal } ']p'      -docstring 'next paragraph'
map global normal { '[p'      -docstring 'previous paragraph'

# .............................................................. Line operations

map global normal G 'ge'      -docstring 'goto buffer end'
map global normal ^ 'gh'      -docstring 'goto line begin'
map global normal $ 'gl'      -docstring 'goto line end'
map global normal C '<a-l>di' -docstring 'replace to end of line'
map global normal D '<a-l>d'  -docstring 'delete to end of line'
map global normal Y '<a-l>'   -docstring 'yank to end of line'

# ........................................................................ Paste

map global normal <c-p> ':<space>yank-ring-previous<ret>'
map global normal <c-n> ':<space>yank-ring-next<ret>'

# Buffers
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

set-option global autoreload yes

# no sudo-write-all so sync root owned files on buffer switching
define-command sync %{
	# if %{ [ -n "$kak_opt_filetype" ] && $kak_modified } %{ sudo-write }  # BUG: $kak_opt_filetype is null for "if" command (?)
	# BUG: $kak_opt_filetype is null for %sh{} and root owned files(?)
	evaluate-commands %sh{ [ "$kak_buffname" != '*scratch*' ] && $kak_modified && echo "sudo-write" || echo "nop" }
}

# ..................................................................... Filetype

# modeline inline context: "# kak: filetype=.." (comment delimiter by filetype)
# NOTE: markdown statement '#[ kak: ... ]: #' issues *debug* "Unsupported kakoune variable:" message for trailing ']'
set-option global modelines 2  # BUG: avoid "otherwords:" error (not kak: or vim:) within modeline scan range (default 5)
hook global BufOpenFile .* %{ modeline-parse }

hook global BufOpenFile .*(.eml|.note) %{ set buffer filetype markdown }
hook global FocusOut .* sync   # over "write" for system files

# kettelkasten
hook global WinSetOption filetype=markdown %{
	define-command zk-index %sh{ zk index --no-input" }
	defer %{ alpha : map global user Z ': zk-index<ret>' -docstring 'zk index' }

	define-command zk-new %sh{ zk new $(dirname "$kak_buffile") --title="$kak_selection" }
	defer %{ alpha : map global user z ': zk-new<ret>'   -docstring 'zk new' }
}

# ............................................................ Buffer management

map global normal <a-ret>       ': sync<ret>: buffer-next<ret>'     -docstring 'next buffer'
map global normal <a-backspace> ': sync<ret>: buffer-previous<ret>' -docstring 'previous buffer'
map global normal <a-space>     ': sync<ret>ga'                     -docstring 'last buffer'

hook global WinDisplay filetype=diff %{
	map global normal <ret>      ': diff-jump<ret>'                  -docstring 'diff-jump new file'
	map global normal <a-ret>    ': diff-jump -<ret>'                -docstring 'diff-jump old file'
}

# Allow one trailing space only in diff output
hook global WinSetOption filetype=(diff) %{
	add-highlighter buffer/diff-allow-one-trailing-space regex '^ ' 0:Default
}
defer %{ alpha : map global user d ': buffer *debug*<ret>'            -docstring '*debug*' }
defer %{ alpha : map global user D ': sync<ret>: delete-buffer<ret>'  -docstring 'delete buffer' }
defer %{ alpha : map global user q ': quit<ret>'                      -docstring 'quit' }
defer %{ alpha : map global user w ': sync<ret>'                      -docstring 'save' }
defer %{ alpha : map global user x ': sync<ret>: write-all-quit<ret>' -docstring 'save all and quit' }

# Terminal
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

defer %{ alpha   : map global user t   ': nop %sh{ term >/dev/null 2>&1 }<ret>' -docstring 'terminal' }
defer %[ shell c : map global user '{' ': echo %sh{  }<left><left>'             -docstring 'shell' ]  # ATTENTION: %[] to escape '{}' :)

# kak: filetype=kak
