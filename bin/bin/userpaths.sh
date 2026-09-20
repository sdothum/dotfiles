# /etc/profile.d/path.sh
# SEE: .xinitrc -> . /etc/profile
[ $USER = root ] && exit


addpath() {
	# echo $PATH | grep -q "$1:" && return
	PATH="$1:$PATH"
}

for i in $(find /opt -type d -name bin) ;do addpath "$i" ;done
for i in $(find $HOME/go -type d -name bin) ;do addpath "$i" ;done
for i in $(find $HOME/.cargo -type d -name bin | grep -Ev '/(git|registry)') ;do addpath "$i" ;done
for i in $(find $HOME/.nimble -type d -name bin | grep -v '/pkgs.*') ;do addpath "$i" ;done
for i in $(find $HOME/.Garmin -type d -name bin | grep -v 'AppImages') ;do addpath "$i" ;done

# set PATH so it includes user's private bin if it exists

[ -d $HOME/bin ] && for i in $(find -L $HOME/bin -type d | grep -Ev '\.(deprecated|save|old)') ;do addpath "$i" ;done

export PATH
