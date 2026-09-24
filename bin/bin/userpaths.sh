#!/usr/bin/dash
# sdothum - 2016 (c) wtfpl

# Env
# ══════════════════════════════════════════════════════════════════════════════

# ............................................................. set session PATH

# SEE: .bashrc

[ $USER = root ] && exit

# NOTE: update list as required for language environments

SINGLES="
	$HOME/.cargo/bin
	$HOME/.nimble/bin
	$HOME/go/bin
"

addpath() {
	PATH="$1:$PATH"
}

# load /opt installations and other custom development environments
# HINT: "ln -s ../<installation> bin" if bin is not part of native directoy structure
#       or add appropriate directory to $SINGLES

for i in $(find /opt -type d -name bin) ;do addpath "$i" ;done
for i in $(find $HOME/.Garmin -type d -name bin | grep -v 'AppImages') ;do addpath "$i" ;done
for i in $SINGLES ;do addpath "$i" ;done

# set PATH so it includes user's private bin if it exists

[ -L $HOME/bin ] && L=-L
[ -d $HOME/bin ] && for i in $(find $L $HOME/bin -type d | grep -Ev '\.deprecated') ;do addpath "$i" ;done

export PATH
