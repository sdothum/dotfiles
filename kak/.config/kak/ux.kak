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
map global normal |     'x| '                 -docstring "pipe FIFO buffer"
map global normal '#'   ': enter-user-mode format<ret>'


# ................................................................... Commenting

push %{ comment : map global format c       ': comment-line<ret>' -docstring 'comment' }
push %{ comment : map global format l       'x|comment l .<ret>'  -docstring 'leader    ... xxx' }
push %{ comment : map global format t       'x|comment t .<ret>'  -docstring 'trailer   xxx ...' }
push %{ comment : map global format R       'x|comment r =<ret>'  -docstring 'ruler     ═══' }
push %{ comment : map global format r       'x|comment r --<ret>' -docstring 'ruler     ━━━' }
push %{ comment : map global format U       'x|comment u =<ret>'  -docstring 'underline ═══' }
push %{ comment : map global format u       'x|comment u --<ret>' -docstring 'underline ━━━' }
push %{ comment : map global format '`'     'x|comment c<ret>'    -docstring 'css       <code></code> block' }

# ..................................................................... Aligning

push %{ align a : map global format <space> 'x|align '            -docstring 'align     '' '' nth+1 word' }
push %{ align b : map global format <minus> 'x|align --<ret>'     -docstring 'align     --  comment' }
push %{ align c : map global format '#'     'x|align \#<ret>'     -docstring 'align     #   comment' }
push %{ align d : map global format /       'x|align //<ret>'     -docstring 'align     //  comment' }
push %{ align e : map global format =       'x|align =<ret>'      -docstring 'align     =   statement' }
push %[ align s : map global format {       'x|align \{<ret>'     -docstring 'align     {   block' ]  # ATTENTION: %[] to escape '{' :)
push %{ align s : map global format )       'x|align \)<ret>'     -docstring 'align     )   case' }
push %{ align s : map global format ';'     'x|align \;\;<ret>'   -docstring 'align     ;;  endcase' }
push %{ align x : map global format '\'     'x|align \\<ret>'     -docstring 'align     \   continuation' }
push %{ align x : map global format ','     'x|align \;\\<ret>'   -docstring 'align     ;\  continuation' }

# .................................................................... Searching

push %{ focus s : map global user /   '/(?i)'     -docstring 'isearch prev,next' }
push %{ focus s : map global user '\' '<a-/>(?i)' -docstring 'isearch prev,next' }
push %{ focus x : map global user ?   '?(?i)'     -docstring 'iextend prev,next' }
push %{ focus x : map global user !   '<a-?>(?i)' -docstring 'iextend prev,next' }

# .................................................................... Selection

push %{ alpha : map global user s 'x<a-s>s'     -docstring 'split: select,iselect' }
push %{ alpha : map global user S 'x<a-s>s(?i)' -docstring 'split: select,iselect' }

map global normal S         's(?i)'  -docstring 'split: iselect:'

map global normal '<minus>' '{p'     -docstring 'extend to previous paragraph'
map global normal {         '[p'     -docstring 'select to paragraph begin'
map global normal '='       '<a-a>p' -docstring 'select surrounding paragraph'
map global normal }         ']p'     -docstring 'select to paragraph end'
map global normal '<plus>'  '}p'     -docstring 'extend to next paragraph'

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
declare-user-mode buffer

map global normal <ret> ': enter-user-mode buffer<ret>'

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
	push %{ alpha : map global buffer Z ': zk-index<ret>' -docstring 'zk index' }

	define-command zk-new %sh{ zk new $(dirname "$kak_buffile") --title="$kak_selection" }
	push %{ alpha : map global buffer z ': zk-new<ret>'   -docstring 'zk new' }
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
hook global WinSetOption filetype=diff %{
	add-highlighter buffer/diff-allow-one-trailing-space regex '^ ' 0:Default
}
push %{ alpha : map global buffer d ': buffer *debug*<ret>'            -docstring '*debug*' }
push %{ alpha : map global buffer D ': sync<ret>: delete-buffer<ret>'  -docstring 'save and delete' }
push %{ alpha : map global buffer q ': quit!<ret>'                     -docstring 'quit' }
push %{ alpha : map global buffer w ': sync<ret>'                      -docstring 'save / quit' }
push %{ alpha : map global buffer W ': sync<ret>: quit!'               -docstring 'save / quit' }
push %{ alpha : map global buffer x ': sync<ret>: write-all-quit<ret>' -docstring 'save all and quit' }

# Terminal / shell
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

push %{ alpha : map global buffer t ': nop %sh{ term >/dev/null 2>&1 }<ret>' -docstring 'terminal' }
push %[ alpha : map global buffer s ': echo %sh{  }<left><left>'             -docstring 'shell' ]  # ATTENTION: %[] to escape '{}' :)

# kak: filetype=kak
