" sdothum - 2016 (c) wtfpl

" Statusline
" ══════════════════════════════════════════════════════════════════════════════

" At cursor position ___________________________________________________________

" ................................................................... Atom / tag
" attribute at cursor position
function! statusline#Atom()
	return synIDattr(synID(line('.'), col('.'), 1), 'name')
endfunction

function! s:tag()
	return tagbar#currenttag('%s', '')
endfunction

" ............................................................ Special Character
let s:ascii = '\(\d\|\a\|\s\|[`~!@#$%^&*()_\-+={}\[\]\\|;:\",\.<>/?]\)'

function! s:specialChar()
	if mode() == 'n'  " getline() test fails on switch into insert mode
		try
			if !empty(getline(line('.')))            " ignore newline (is NUL)
				let l:char        = getline('.')[col('.')-1]
				if l:char !~ s:ascii && l:char != "'"  " show hex value, not interested in ascii keyboard characters
					let l:statusmsg = v:statusmsg
					normal! ga
					let l:hex       = 'U+' . matchstr(split(v:statusmsg)[3], '[^,]*')
					let v:statusmsg = l:statusmsg
					" clear ga information!
					echo ''
					return l:hex
				endif
			endif
		catch /.*/  " discard messages
		endtry
	endif
	return ''
endfunction

" .................................................................. Cursor info
function! Detail()
	let l:prefix = g:detail ? statusline#Atom() : s:tag()
	return empty(l:prefix) ? s:specialChar() : l:prefix . '  ' . s:specialChar()
endfunction

" Buffer statistics ____________________________________________________________

" ................................................................... Word count
" null return for non-prose or empty new buffer
function! s:wordCount()
	if mode() =~ '[vV]' | return '' | endif  " visual mode (gives incorrect word count)
	try  " trap error caused by snippet expansion involving substition placeholders
		let b:wordcount = ''
		let l:statusmsg = v:statusmsg
		let l:position  = getpos('.')
		execute "silent normal! g\<C-g>"
		if v:statusmsg != '--No lines in buffer--' | let b:wordcount = str2nr(split(v:statusmsg)[11]) | endif
		let v:statusmsg = l:statusmsg
		call setpos('.', l:position)  " go back (to EOL if need be)
		return b:wordcount
	catch /.*/                      " discard messages
	endtry
endfunction

" Statusline content ___________________________________________________________

" ....................................................................... Leader
function! s:escape(text)
	return substitute('%*' . a:text, ' ', '\\ ', 'g')
endfunction

function! Leader(text)
	return repeat(' ', (winwidth(0) / 2) - strlen(a:text) - strlen(g:pad[0]))
endfunction

" ......................................................................... Path
function! Name()
	return expand('%:t' . (Prose() ? ':r' : ''))
endfunction

function! Path()
	let l:path   = split(substitute(expand('%:p:h'), $HOME, '~', ''), '/')[:-1]
	let l:count  = len(l:path)
	if l:count < 3
		let l:path = join(l:path, '/')
	else
		let l:dirs = join(l:path[l:count - 2:], '/')
		let l:abbr = substitute(substitute(join(l:path[:-3], '/'), '\([/]*[.]*[^/]\)[^/]*', '\1', 'g'), '[/]', '', 'g')  " abbreviate path abbr and drop slashes
		let l:path = l:abbr . '/' . l:dirs
	endif
	return (l:path[0] == '~' ? '' : '/') . l:path
endfunction

" ................................................................. Buffer state
function! s:attn()
	return system('stat --printf %U ' . expand('%:p')) == 'root' ? '%3*' : '%1*'
endfunction

function! UnModified(show)
	return (expand('%t') =~ 'NrrwRgn' || w:tagged == g:active) ? (&modifiable ? (&modified ? g:duochrome_icon[2] : a:show ? (g:duochrome_insert ? g:duochrome_icon[4] : g:duochrome_icon[0]) : '') : g:duochrome_icon[1]) : g:duochrome_icon[3]
endfunction

" ......................................................................... Info
" normal mode code: col -> file%, prose: col -> wordcount
" insert mode code: col 
function! PosWordsCol()
	return mode() == 'n' ? (g:show_column ? col('.') : (Prose() ? s:wordCount() : (line('.') * 100 / line('$')) . '%')) : col('.')
endfunction

" DFM / expanded _______________________________________________________________

" .............................................................. set statusline=
" [path] .. filename state position .. [details]
function! statusline#Statusline(expanded)
	try  " trap snippet insertion interruption
		if Prose() && &filetype != 'steno' && g:duochrome_insert  " steno hides statusline content
			return s:escape(s:attn() . Leader('') . '  %{UnModified(0)}%1*')
		else
			let l:name     = '%1*%{Name()}' . g:pad[0]
			let l:info     = s:attn() . '%{UnModified(1)}' . g:pad[0] . '%1*%{PosWordsCol()}'  " utf-8 symbol occupies 2 chars (pad right 1 space)
			if a:expanded  " center dfm indicator / proofing statusline
				let l:leader = '%{Leader(Path() . g:pad[1] . Name())}'
				let l:name   = '%2*%{Path()}%1*' . g:pad[1] . l:name
				let l:info  .= g:pad[1] . '%2*%{Detail()}'
			else
				let l:leader = '%{Leader(Name())}'
			endif
			return s:escape('%1*' . l:leader . l:name . l:info . '%1*')
		endif
	catch /.*/  " discard messages
	endtry
endfunction

" statusline.vim
