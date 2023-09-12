" sdothum - 2016 (c) wtfpl

" Library
" ══════════════════════════════════════════════════════════════════════════════

" System _______________________________________________________________________

" .................................................................. Debug trace
" escape problematic shell commandline characters
function! lib#trace(msg)
	if g:trace | silent execute '!echo "' . substitute(a:msg, '[-<>#$]', '\\&', 'g') . '" >>/tmp/vim:trace' | endif
endfunction

" ........................................................... Error message trap
" ignore 1st time error messages from plugins (uninitialized s:variables)
function! lib#Quietly(command)
	try
	 execute a:command
	catch /.*/  " discard messages
	endtry
endfunction

" ........................................................ State change notifier
" nargs -> <message>: <bool>, note ':' separator terminating message
function! lib#Notify(s)
	let l:msg = split(a:s, ' *: ')  " accept g:varname in bool expression
	execute 'let l:state = ' . msg[1] . ' ? "ON" : "OFF"'
	echo l:msg[0] l:state
endfunction

" ............................................................. GUI delay window
" wait for prior gui action to properly complete
function! lib#WaitFor(...)
	execute 'sleep ' . (a:0 ? a:1 : '10m')
endfunction

" lib.vim
