# vim-duochrome

more than just a distraction free colorscheme (though you can copy the
colors/duochrome.vim file to your colors folder for just that)..

![DuoChrome](/screenshots/duochrome.jpg)

## purpose

create a colorscheme that not only displays a minimalist distraction
free palette but [dynamically
configures](http://thedarnedestthing.com/duochrome%20gym) the vim
environment (feature set works best with Gvim) to provide a distraction
free workflow for concentrating on writing and coding

## features

- auto-centering of text area within window (window width and textwidth dependent)
- auto-hyperfocusing on insert mode
- auto-fontsize for code and markdown
- minimalist dynamic statusline content (name + state + col/%/wordcount)
- toggle cursorline (dfm, highlight, underline)
- toggle breakchar (and line highlight)
- toggle line wrap (disable textwidth)
- toggle relative number
- toggle column ruler (cursor, fixed)
- toggle expanded statusline (path + tag/atom + utf-8 code)
- toggle background (light, dark)
- toggle fontsize (code, prose)

## dependencies

    Plug 'junegunn/limelight.vim'  " hyperfocus highlighting
    Plug 'bilalq/lite-dfm'         " distraction free mode

## optional dependencies

    Plug 'itchyny/vim-cursorword'          " word highlighting
    Plug 'nathanaelkane/vim-indent-guides' " colourized indent columns
    Plug 'majutsushi/tagbar'               " ctags
    Plug 'lvht/tagbar-markdown'            " markdown for tagbar

## configuration

    let g:duochrome_font = ['<code font family>', '<prose font family>']
    let g:duochrome_icon = ['<unmodified (normal mode)>', '<unmodifiable>', '<modified>', '<inactive (window)>', '<insert mode>']

    let g:duochrome_map = 1  " (0) user mappings (1) duochrome mappings

## duochrome mappings

    " ........................................................................ Debug
    nnoremap <silent><S-F10> :let g:trace = !g:trace<CR>
 
    " Behaviour ____________________________________________________________________
    " ................................................................... Toggle gui
    nnoremap <silent><S-F12>      :ToggleGui<CR>
    inoremap <silent><S-F12> <C-o>:ToggleGui<CR>
    vnoremap <silent><S-F12> :<C-u>ToggleGui<CR>
    " ................................................................... Redraw gui
    nnoremap <silent><F12>      :RedrawGui<CR>
    inoremap <silent><F12> <C-o>:RedrawGui<CR>
    vnoremap <silent><F12> :<C-u>RedrawGui<CR>
 
    " Look _________________________________________________________________________
    " ................................................................... Cursorline
    nmap <silent><F6>      :ToggleCursorline<CR>
    imap <silent><F6> <C-o>:ToggleCursorline<CR>
    " ................................................................... Cursorword
    nmap <silent><F5>      :ToggleCursorword<CR>
    imap <silent><F5> <C-o>:ToggleCursorword<CR>
    " ............................................................... Column margins
    nmap <silent><Bar> :ToggleColumn<CR>
    " .......................................................... Line wrap highlight
    nmap <silent><S-F6>      :ToggleBreak<CR>
    imap <silent><S-F6> <C-o>:ToggleBreak<CR>
 
    " Theme ________________________________________________________________________
    " ................................................................ Switch colour
    nmap <silent><F7>      :LiteSwitch<CR>
    imap <silent><F7> <C-o>:LiteSwitch<CR>
 
    " Distraction free mode ________________________________________________________
    " .................................................................... View mode
    nmap <silent><S-F11>      :ToggleProof<CR>
    imap <silent><S-F11> <C-o>:ToggleProof<CR>
    " ................................................................. Line numbers
    nmap <silent># :ToggleNumber<CR>
    " .................................................... Toggle statusline details
    nmap <silent><F8>      :ToggleInfo<CR>
    imap <silent><F8> <C-o>:ToggleInfo Prose()<CR>
 
    " Format _______________________________________________________________________
    " ..................................................................... Filetype
    nmap <leader>F :Filetype<Space>
    " .................................................................... Line wrap
    nmap <silent><leader><CR> :ToggleWrap<CR>
 
    " Screen _______________________________________________________________________
    " ...................................................................... Refresh
    nmap <silent><F11>      :Refresh<CR>
    imap <silent><F11> <C-o>:Refresh<CR>
    " ............................................................. Switch font size
    nmap <silent><S-F7>      :Font !g:fonttype<CR>
    imap <silent><S-F7> <C-o>:Font !g:fonttype<CR>
 
    " Statusline ___________________________________________________________________
    " .................................................................. Information
    nmap <silent><S-F8>      :let g:detail = !g:detail<CR>
    imap <silent><S-F8> <C-o>:let g:detail = !g:detail<CR>
    " .............................................................. Column position
    nnoremap <silent><C-c> hl
    " ................................................................. Syntax group
    nnoremap <silent><F10> :Atom<CR>

## todo considerations

- user defineable delay timings for gui refreshes
- handling of unavailable optional plugin dependencies 
- update
[vim-colors-duochrome](https://github.com/sdothum/vim-colors-duochrome)
with the dark and diff colorschemes as separate colorscheme only plugin

