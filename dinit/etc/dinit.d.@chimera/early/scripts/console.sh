#!/bin/sh

if [ "$1" = "keyboard" ]; then
    set -- "-k"
else
    set --
fi

exec setupcon "$@"
