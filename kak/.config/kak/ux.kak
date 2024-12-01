# sdothum - 2016 (c) wtfpl

# Kakoune
# ══════════════════════════════════════════════════════════════════════════════

# Editing
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# ................................................................... Formatting

set-option global tabstop 3
set-option global indentwidth 3
declare-user-mode format

map global normal <c-l>   ': comment-line<ret>' -docstring 'comment'  # beakl key position for "#" NOTE: <c-c> unmappable
map global normal |       'x| '                 -docstring "pipe FIFO buffer"
map global normal '#'     ': enter-user-mode format<ret>'
map global insert <a-ret> '<esc><a-o>ji'        -docstring 'insert non-comment line below cursor'


# ................................................................... Commenting

catch %{ comment : map global format c       ': comment-line<ret>' -docstring 'comment' }
catch %{ comment : map global format l       'x|comment l .<ret>'  -docstring 'leader    ... xxx' }
catch %{ comment : map global format t       'x|comment t .<ret>'  -docstring 'trailer   xxx ...' }
catch %{ comment : map global format R       'x|comment r =<ret>'  -docstring 'ruler     ═══' }
catch %{ comment : map global format r       'x|comment r --<ret>' -docstring 'ruler     ━━━' }
catch %{ comment : map global format U       'x|comment u =<ret>'  -docstring 'underline ═══' }
catch %{ comment : map global format u       'x|comment u --<ret>' -docstring 'underline ━━━' }
catch %{ comment : map global format '`'     'x|comment c<ret>'    -docstring 'css       <code></code> block' }

# ..................................................................... Aligning

catch %{ align a : map global format <space> 'x|align '            -docstring 'align     '' '' nth+1 word' }
catch %{ align b : map global format <minus> 'x|align --<ret>'     -docstring 'align     --  comment' }
catch %{ align c : map global format '#'     'x|align \#<ret>'     -docstring 'align     #   comment' }
catch %{ align d : map global format /       'x|align //<ret>'     -docstring 'align     //  comment' }
catch %{ align e : map global format =       'x|align =<ret>'      -docstring 'align     =   statement' }
catch %[ align s : map global format {       'x|align \{<ret>'     -docstring 'align     {   block' ]  # ATTENTION: %[] to escape '{' :)
catch %{ align s : map global format )       'x|align \)<ret>'     -docstring 'align     )   case' }
catch %{ align s : map global format ';'     'x|align \;\;<ret>'   -docstring 'align     ;;  endcase' }
catch %{ align x : map global format '\'     'x|align \\<ret>'     -docstring 'align     \   continuation' }
catch %{ align x : map global format ','     'x|align \;\\<ret>'   -docstring 'align     ;\  continuation' }

# .................................................................... Searching

catch %{ focus s : map global user /   '/(?i)'     -docstring 'isearch prev,next' }
catch %{ focus s : map global user '\' '<a-/>(?i)' -docstring 'isearch prev,next' }
catch %{ focus x : map global user >   '?(?i)'     -docstring 'iextend prev,next' }
catch %{ focus x : map global user <   '<a-?>(?i)' -docstring 'iextend prev,next' }

# .................................................................... Selection

catch %{ alpha : map global user s 'x<a-s>s'     -docstring 'split: select,iselect' }
catch %{ alpha : map global user S 'x<a-s>s(?i)' -docstring 'split: select,iselect' }

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
catch %{ focus 0 : map global user <ret> ': enter-user-mode buffer<ret>' -docstring 'buffer menu' }

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
# hook global BufOpenFile .* %{ modeline-parse }
hook global BufCreate .* %{ modeline-parse }

# hook global BufOpenFile .*[.](eml|note) %{ set-option buffer filetype markdown }
hook global BufCreate .*[.](eml|note) %{ set-option buffer filetype markdown }
hook global FocusOut .* sync   # over "write" for system files

# kettelkasten
hook global WinSetOption filetype=markdown %{
	define-command zk-index %sh{ zk index --no-input" }
	catch %{ alpha 9 : map global buffer Z ': zk-index<ret>' -docstring 'zk index' }

	define-command zk-new %sh{ zk new $(dirname "$kak_buffile") --title="$kak_selection" }
	catch %{ alpha 9 : map global buffer z ': zk-new<ret>'   -docstring 'zk new' }
}

# ............................................................ Buffer management

map global normal <a-ret>       ': sync<ret>: buffer-next<ret>'     -docstring 'next buffer'
map global normal <a-backspace> ': sync<ret>: buffer-previous<ret>' -docstring 'previous buffer'
map global normal <a-space>     ': sync<ret>ga'                     -docstring 'last buffer'

# USE: .*diff BECAUSE: rc/filetype/mail.kak also maps <ret> causing unexpected *.eml plug error(?)
hook global WinDisplay .*diff %{
	map global normal <ret>      ': diff-jump<ret>'                  -docstring 'diff-jump new file'
	map global normal <a-ret>    ': diff-jump -<ret>'                -docstring 'diff-jump old file'
}

# Allow one trailing space only in diff output
hook global WinSetOption filetype=diff %{
	add-highlighter buffer/diff-allow-one-trailing-space regex '^ ' 0:Default
}
catch %{ alpha 1 : map global buffer d ': buffer *debug*<ret>'            -docstring '*debug*' }
catch %{ alpha 1 : map global buffer D ': sync<ret>: delete-buffer<ret>'  -docstring 'save and delete' }
# SEE: kakpipe alpha subsort in xdisplay-plugins
catch %{ alpha 9 : map global buffer q ': quit!<ret>'                     -docstring 'quit' }
catch %{ alpha 9 : map global buffer w ': sync<ret>'                      -docstring 'save / quit' }
catch %{ alpha 9 : map global buffer W ': sync<ret>: quit!'               -docstring 'save / quit' }
catch %{ alpha 9 : map global buffer x ': sync<ret>: write-all-quit<ret>' -docstring 'save all and quit' }

# Terminal / shell
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

catch %{ alpha 9 : map global buffer t ': nop %sh{ term >/dev/null 2>&1 }<ret>' -docstring 'terminal' }
catch %[ alpha 9 : map global buffer s ': echo %sh{  }<left><left>'             -docstring 'shell' ]  # ATTENTION: %[] to escape '{}' :)

# kak: filetype=kak
