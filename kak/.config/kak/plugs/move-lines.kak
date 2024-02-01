define-command move-lines-down \
-docstring 'move-lines-down [<count>] move selected lines down by <count> or one line' \
-params ..1 \
%{
    execute-keys -draft "x<a-_><a-:>Z;ez;%arg{1}J<a-;>LxdzP"
}

define-command move-lines-up \
-docstring 'move-lines-up [<count>] move selected lines up by <count> or one line' \
-params ..1 \
%{
    execute-keys -draft "x<a-_><a-:><a-;>Z;bz;%arg{1}K<a-;>Hxdzp"
}
