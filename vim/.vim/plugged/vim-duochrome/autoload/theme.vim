" sdothum - 2016 (c) wtfpl

" Theme
" ══════════════════════════════════════════════════════════════════════════════

" Colorscheme __________________________________________________________________

" ............................................................... Initialization
function! theme#Background(...)
	Trace theme:Background
	Margins  " must be called before colorscheme ta refresh cursorlinenr cleared by LiteDFM
	if a:0 | let &background = a:1
	else   | execute 'set background=' . &background
	endif
endfunction

" .......................................................... Toggle colourscheme
function! theme#LiteSwitch()
	Trace theme:LiteSwitch
	if empty($DISPLAY) | return | endif  " console
	Quietly LiteDFMClose                 " trap and ignore initialization error
	if &background == 'light' | Background dark
	else                      | Background light
	endif
endfunction

" Statusline ___________________________________________________________________

" ................................................................ Single window
function! theme#StatusLine()
	Trace theme:StatusLine
	set laststatus=2
endfunction

" ................................................................ Split windows
" split window statusline background, see ui.vim autocmd
function! theme#SplitColors()
	Trace theme:SplitColors
	let g:duochrome_split = &diff ? 0 : winnr('$') > 1
	Background
endfunction

" theme.vim
