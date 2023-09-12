" sdothum - 2016 (c) wtfpl

" GUI
" ══════════════════════════════════════════════════════════════════════════════

" Behaviour ____________________________________________________________________

" ................................................................... Toggle gui
" toggle gui menu
function! gui#ToggleGui()
	Trace gui:ToggleGui()
	if &guioptions =~# 'm' | set guioptions-=m
	else                   | set guioptions+=m
	endif
endfunction

" .................................................................... Scrolling
let s:scroll_ratio = 12  " integer division (vs 0.percent calculation and integer conversion)

" dynamic scroll offset
function! gui#ScrollOffset()
	let &scrolloff = Prose() ? 999 : winheight(win_getid()) / s:scroll_ratio
endfunction

" Look _________________________________________________________________________

" 0 -> 1 -> 2 -> reset, cycle counter
function! s:triCycle(counter, ...)
	if a:counter == 2 | return a:0 ? a:1 : 0 | endif
	return a:counter + 1
endfunction

" ................................................................... Cursorline
function! gui#ToggleCursorline()
	let g:duochrome_cursorline = s:triCycle(g:duochrome_cursorline, &diff)  " always highlight diff
	Background
endfunction

" ................................................................... Cursorword
function! gui#ToggleCursorword()
	let b:cursorword = !b:cursorword  " new cursor position required to reflect state change
	if col('.') == col('$') - 1 | normal! h
	else                        | normal! l
	endif
endfunction

" ............................................................... Column margins
augroup column | autocmd! | augroup END

set colorcolumn=0  " highlight column

" toggle colorcolumn modes
function! gui#ToggleColumn()
	let g:duochrome_ruler = s:triCycle(g:duochrome_ruler)
	if     g:duochrome_ruler == 0 | let &colorcolumn = 0
	elseif g:duochrome_ruler == 1 | let &colorcolumn = col('.') | autocmd column CursorMoved,CursorMovedI * let &colorcolumn = col('.')
	elseif g:duochrome_ruler == 2 | autocmd! column
	endif
	ShowBreak
	let g:show_column = 1  " flash column position, see statusline.vim
	Background
endfunction

" Highlights ___________________________________________________________________

" .......................................................... Line wrap highlight
let s:wraplight = 0        " show linewrap with (0) s:breakchar (1) highlight
let s:breakchar = '\ ↪\ '  " \escape spaces

" highlight wrapped line portion, see theme:Theme()
function! gui#ShowBreak()
	if g:duochrome_ruler == 0 && s:wraplight
		set showbreak=  " disable breakchar
		let l:edge       = winwidth(0) - &numberwidth - &foldcolumn - 1
		let &colorcolumn = join(range(l:edge, 999), ',')  " highlight break line
	else
		execute 'set showbreak=' . s:breakchar
	endif
endfunction

function! gui#ToggleBreak(...)
	let s:wraplight       = a:0 ? a:1 : !s:wraplight
	let g:duochrome_ruler = -1
	ToggleColumn
endfunction

" gui.vim
