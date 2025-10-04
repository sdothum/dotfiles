# sdothum - 2016 (c) wtfpl

# Kakoune
# ══════════════════════════════════════════════════════════════════════════════

# Formatting
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# ..................................................................... Defaults

set-option global tabstop 3
set-option global indentwidth 3
declare-user-mode format

map global normal '#' ': enter-user-mode format<ret>'

# ....................................................................... Format

addm %{ format  >1 : map global format <tab>   '%|unexpand --first-only -t<space>' -docstring 'leading tabs,n spaces' }
addm %{ format  >2 : map global format <s-tab> '%|expand --init -t<space>'         -docstring 'leading tabs,n spaces' }
addm %{ format  f1 : map global format f       ': refold<ret>'                     -docstring 'fold,unfold' }
addm %{ format  f2 : map global format F       ': unfold<ret>'                     -docstring 'fold,unfold' }

# ...................................................................... Comment

nopm %{ comment 0  : format }
addm %{ comment c1 : map global format <c-c>   ': comment-line<ret>'               -docstring 'comment,block  (kak)' }
addm %{ comment c2 : map global format c       ': comment-block<ret>'              -docstring 'comment,block  (kak)' }
addm %{ comment h  : map global format h       'x|comment c<ret>'                  -docstring '/* css */'   }
addm %{ comment m  : map global format '`'     'x|comment \`<ret>'                 -docstring 'markdown ``    (code block)' }

# ......................................................................... Line

nopm %{ line    0  : format - }
addm %{ line    l1 : map global format l       'x|comment l .<ret>'                -docstring 'leader     ... xxx' }
addm %{ line    l2 : map global format t       'x|comment t .<ret>'                -docstring 'trailer    xxx ...' }
addm %{ line    r1 : map global format R       'x|comment r =<ret>'                -docstring 'ruler      ═══'     }
addm %{ line    r2 : map global format r       'x|comment r --<ret>'               -docstring 'ruler      ━━━'     }
addm %{ line    u1 : map global format U       'x|comment u =<ret>'                -docstring 'underline  ═══'     }
addm %{ line    u2 : map global format u       'x|comment u --<ret>'               -docstring 'underline  ━━━'     }

define-command refold %{ if %{ [ "$kak_opt_hardwrap" = true ] } %{ execute-keys %sh{ echo "x|comment f $kak_opt_autowrap_column<ret>" }}}
define-command unfold %{ if %{ [ "$kak_opt_hardwrap" = true ] } %{ execute-keys 'x|comment F<ret>' }}  # (??) utf-8 sed errors from kak shell

map global normal <c-l> ': comment-line<ret>' -docstring 'comment'  # beakl key position for "#" NOTE: <c-c> unmappable

# ........................................................................ Align

nopm %{ align 0  : format = }
addm %{ align 1  : map global format <space> 'x|align '          -docstring 'align  space   nth+1 word'         }
addm %{ align c1 : map global format '#'     'x|align \#<ret>'   -docstring 'align      #   comment'            }
addm %{ align c2 : map global format /       'x|align //<ret>'   -docstring 'align     //   comment'            }
addm %{ align c3 : map global format <minus> 'x|align --<ret>'   -docstring 'align     --   comment'            }
addm %{ align e  : map global format =       'x|align =<ret>'    -docstring 'align      =   equation'           }
addm %[ align f  : map global format {       'x|align \{<ret>'   -docstring 'align      {   block'              ]  # ATTENTION: %[] to escape '{' :)
addm %{ align p1 : map global format )       'x|align \)<ret>'   -docstring 'align      )   case pattern'       }
addm %{ align p2 : map global format ';'     'x|align \;\;<ret>' -docstring 'align     ;;   endcase'            }
addm %{ align x1 : map global format '\'     'x|align \\<ret>'   -docstring 'align      \   continuation'       }
addm %{ align x2 : map global format ','     'x|align \;\\<ret>' -docstring 'align     ;\   continuation'       }
addm %{ align z  : map global format '*'     'x|align \*/<ret>'  -docstring 'align     */   css comment  (end)' }

map global insert <tab>   '<a-;><a-gt>'  # tab key indents (with spaces)
map global insert <s-tab> '<a-;><a-lt>'  # shift tab deindents

# Editing
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# ......................................................................... Line

map global insert <a-ret> '<esc><a-o>ji' -docstring 'insert non-comment line below cursor'
map global normal C       '<a-l>di'      -docstring 'replace to end of line'
map global normal D       '<a-l>d'       -docstring 'delete to end of line'  # BUG: plugin kakboard interferes with yank buffer
map global normal <a-D>   '<a-l><a-d>'   -docstring 'delete to end of line (not yanking)'

# ........................................................................ Paste

map global normal |       'x| '          -docstring "pipe FIFO buffer"
map global normal <c-p>   ':<space>yank-ring-previous<ret>'
map global normal <c-n>   ':<space>yank-ring-next<ret>'

# .................................................................... Clipboard

# auto update clipoard with yank, change and delete actions
hook global RegisterModified '"' %{ nop %sh{ printf %s "$kak_main_reg_dquote" | xsel --input --clipboard }}

nopm %{ paste 0  : edit - }
addm %{ paste p1 : map global edit p '<a-!> xsel --outafter --clipboard<ret>' -docstring 'clipboard  —— after,before,replace' }
addm %{ paste p2 : map global edit P '! xsel --outafter --clipboard<ret>'     -docstring 'clipboard  —— after,before,replace' }
addm %{ paste p9 : map global edit R '| xsel --output --clipboard<ret>'       -docstring 'clipboard  —— after,before,replace' }

# Selection
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# ......................................................................... Line

# map global normal G   'ge'     -docstring 'goto buffer end'  # breaks selection motion
map global normal ^     'gh'     -docstring 'goto line begin'
map global normal $     'gl'     -docstring 'goto line end'
map global normal Y     '<a-l>y' -docstring 'yank to end of line'

# ........................................................................ Block

map global normal <c-=> '{p'     -docstring 'extend to previous paragraph'  # NOTE: flip <a-;> selection direction after forward select
map global normal =     '<a-a>p' -docstring 'select surrounding paragraph'
map global normal <a-=> '}p'     -docstring 'extend to next paragraph'

# .................................................................... Searching

nopm %{ search 0  : edit }
addm %{ search /1 : map global edit /     '/(?i)'             -docstring 'isearch    —— prev,next' }
addm %{ search /2 : map global edit '\'   '<a-/>(?i)'         -docstring 'isearch    —— prev,next' }
addm %{ search /3 : map global edit >     '?(?i)'             -docstring 'iextend    —— prev,next' }
addm %{ search /4 : map global edit <     '<a-?>(?i)'         -docstring 'iextend    —— prev,next' }

# .............................................................. Split selection

addm %{ search d1 : map global edit m     ': mkd-para<ret>'  -docstring 'markdown   —— paragraphs,tables,code' }
addm %{ search d2 : map global edit M     ': mkd-table<ret>' -docstring 'markdown   —— paragraphs,tables,code' }
addm %{ search d3 : map global edit <c-m> ': mkd-code<ret>'  -docstring 'markdown   —— paragraphs,tables,code' }

addm %{ search /5 : map global edit s     'x<a-s>s'          -docstring 'split      —— select,iselect' }
addm %{ search /6 : map global edit S     'x<a-s>s(?i)'      -docstring 'split      —— select,iselect' }

define-command mkd-para  %{ if %{ [ "$kak_opt_filetype" = markdown ] } %{ execute-keys '%<a-s>s^[^|`]<ret>x' }}
define-command mkd-table %{ if %{ [ "$kak_opt_filetype" = markdown ] } %{ execute-keys '%<a-s>s^[|]<ret>x'   }}
define-command mkd-code  %{ if %{ [ "$kak_opt_filetype" = markdown ] } %{ execute-keys '%<a-s>s^[`]<ret>x'   }}

map global normal S 's(?i)' -docstring 'split: iselect:'

# Buffers
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

set-option global autoreload yes
declare-user-mode buffer

map global normal <ret>   ': enter-user-mode buffer<ret>'
map global normal <c-ret> ': enter-user-mode buffer<ret>'  # for find *scratch* buffer
nopm %{ mode 0 : edit = }
addm %{ mode b : map global edit <ret> ': enter-user-mode buffer<ret>' -docstring 'buffer user-mode' }

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

# ............................................................ Buffer management

map global normal <a-space>     ': sync<ret>: buffer-next<ret>'     -docstring 'next buffer'
map global normal <a-backspace> ': sync<ret>: buffer-previous<ret>' -docstring 'previous buffer'
map global normal <a-ret>       ': sync<ret>ga'                     -docstring 'last buffer'

# USE: .*diff BECAUSE: rc/filetype/mail.kak also maps <ret> causing unexpected *.eml plug error(?)
hook global WinDisplay .*[.]diff %{
	nop %sh{ notify 20 critical "*.diff buffer" "&lt;<b>ret</b>&gt;\tgoto 1st buffer &amp; line\n&lt;<b>c-ret</b>&gt;\tgoto 2nd buffer &amp; line\n&lt;<b>space</b>&gt;\tbuffer (user-mode)" }

	map buffer normal <ret>   ': diff-jump -<ret>'            -docstring 'diff-jump 1st file'
	map buffer normal <a-ret> ': diff-jump  <ret>'            -docstring 'diff-jump 2nd file'
	map buffer normal <space> ': enter-user-mode buffer<ret>' -docstring 'diff buffer mode'
}

# Allow one trailing space only in diff output
hook global WinSetOption filetype=diff %{
	add-highlighter buffer/diff-allow-one-trailing-space regex '^ ' 0:Default
}

nopm %{ test 0  : buffer = }
addm %{ test b  : map global buffer *   ': buffer *debug*<ret>'            -docstring '*debug*'   }
nopm %{ file 0  : buffer - }
addm %{ file d1: map global buffer d   ': sync<ret>: delete-buffer<ret>'  -docstring 'delete  —— with save,discard!'  }
addm %{ file d2 : map global buffer D   ': delete-buffer!<ret>'            -docstring 'delete  —— with save,discard!'  }
# SEE: kakpipe alpha subsort in xdisplay-plugins
addm %{ file q  : map global buffer q   ': quit!<ret>'                     -docstring 'quit!' }
addm %{ file w1 : map global buffer w   ': sync<ret>'                      -docstring 'write   —— save,and quit!' }
addm %{ file w2 : map global buffer W   ': sync<ret>: quit!'               -docstring 'write   —— save,and quit!' }
addm %{ file x  : map global buffer x   ': sync<ret>: write-all-quit<ret>' -docstring 'save all and quit' }

map global normal <c-w> ': sync<ret>'       -docstring 'write'
map global insert <c-w> '<esc>: sync<ret>i' -docstring 'write'

# Terminal / shell
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

addm %{ meta t : map global buffer t ': nop %sh{ term >/dev/null 2>&1 }<ret>' -docstring 'terminal'      }
addm %[ test i : map global buffer i ': echo %sh{ % }<left><left>'            -docstring 'inspect %{..}' ]  # ATTENTION: %[] to escape '{}' :)

# kak: filetype=kak
