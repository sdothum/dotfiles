#!/usr/bin/dash

# X11 Initialization
# ▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬

# Executed by startx (run your window manager from here):
#   startx -- -layout Multihead
# Note: .xinitrc takes precedence over .xsession, use either but ensure dbus is enabled

# ............................................................... Initialization

BOOTWM=$SESSION/boot:wm  # see console_login, user_login
WM=$HOME/.windowmanager

rm -f $BOOTWM                                     # cancel autostart of wm if manually started
[ -e $WM ] || { pkill -KILL startx; exit; }
wm=$(cat $WM)
[ $wm = shell ] && { pkill -KILL startx; exit; }  # trap autostart wm set as shell

# ................................................................... User setup

# build installed terminal
cpu atom && TERM=xterm || TERM=alacritty

# kill any dangling shell sessions from prior xsessions
killall bash

# Where the default home folders have not already been created, generate them
[ -x /usr/bin/xdg-user-dirs-update ] && /usr/bin/xdg-user-dirs-update

# ...................................................................... Daemons

# # cut and paste (leaves small visible square icon on desktop if started here, see autostart)
# autocutsel -selection PRIMARY -fork &
# Enable automounting removable devices
exists udiskie && udiskie --automount --notify --no-tray &
alpine && /usr/libexec/pipewire-launcher
# pulse &
# pipewire &
# pipewire-pulse &

# ........................................................................ D-Bus

# d-bus for file management, authentication, and other essential system processes
if exists dbus-launch && test -z "$DBUS_SESSION_BUS_ADDRESS"; then
    eval "$(dbus-launch --sh-syntax --exit-with-session)"
    echo "D-Bus per-session daemon address is: $DBUS_SESSION_BUS_ADDRESS"
fi
# export dbus for cron notifications, see notify
[ -e $HOME/.dbus ] || mkdir $HOME/.dbus
echo "export $(env | grep DBUS_SESSION_BUS_ADDRESS)" >$HOME/.dbus/Xdbus
chmod 600 $HOME/.dbus/Xdbus

# ................................................................ Gnome keyring

# eval $(/usr/bin/gnome-keyring-daemon --start --components=pkcs11,secrets,ssh)
# export SSH_AUTH_SOCK

# ........................................................................... UI

# ensure that gtk themes are applied uniformly in the desktop environment
export GTK2_RC_FILES="$HOME/.gtkrc-2.0"
export _JAVA_AWT_WM_NONREPARENTING=1

# # initialize keyboard
# [ $(hostname) = luna ] || setxkbmap us -variant colemak
# [ -e $HOME/.Xmodmap ] && xmodmap $HOME/.Xmodmap
# Ensure fonts are available to applications
xset +fp $HOME/.fonts
# xset fp rehash

# set arrowhead pointer instead of "X"
xsetroot -cursor_name left_ptr

# # autohide mouse pointer (conflicts with tabbed vimb, see autostart)
# exists unclutter && unclutter -idle 1 -jitter 2 -root &

# utf-8
xrdb -load $HOME/.Xresources

# login manager default
DEFAULTSESSION=2bwm
#echo $wm >$HOME/.xsession.trace

# ...................................................................... Display

tv_over() { xrandr --output $1 --off --output HDMI1 --primary --mode $2 --rate 60 --dpi 96; }

case $(hostname) in
	# luna ) xrandr --output DVI-D-1 --mode 1680x1050 --output HDMI-1 --primary --mode 1920x1080 --rate 60 --left-of DVI-D-1 --dpi 96 ;;
	luna ) xrandr --output HDMI-1 --mode 3440x1440  --rate 60 --dpi 96 ;;
	lumen) hdmi && tv_over LVDS1 1920x1080 ;;
	motu ) hdmi && tv_over eDP1 1920x1080 ;;
esac
# pulseeffects --gapplication-service &

# ............................................................... Window manager

export XDG_CONFIG_HOME=$HOME/.config

xexec() {
	export ROOT=${ROOT:-/tmp}
	mv -f $ROOT/$1.log $ROOT/$1.last.log 2>/dev/null
	rm -f $ROOT/$1:*
	# enable debug trace by referencing log file
	export TRACE=$ROOT/$1.log
	# exec ck-launch-session dbus-launch --sh-syntax --exit-with-x11 $1 >$ROOT/$1.log 2>&1
	exec $1 >$ROOT/$1.log 2>&1
}

setpath() {
	root=$1; shift
	path=$root
	for i in bin $@ ;do
		[ -d $root/$i ] && path=$path:$root/$i
	done
	export PATH=$(echo $path:$(echo $PATH | sed "s|$path:||g"))
}

case $wm in
2b* )
	pkill -KILL -f '2bwm'
	xrdb -load $HOME/.Xresources
	setpath $HOME/.config/2bwm cmd
	. $(which ENV)
	$TERM &
	# (sleep 0.15; xdotool --sync --onlyvisible --class "Alacritty" windowactivate --sync; sleep 0.65; xdotool type "autostart >/tmp/2bwm.log 2>&1"; xdotool key return) &  # autostart the panel in the terminal window (delay for celeron cpu)
	(sleep 0.15; autostart >/tmp/2bwm.log 2>&1) &
	xexec 2bwm ;;

aw* ) xexec awesome ;;

be* )
	xwallpaper --zoom $HOME/images/default
	xrdb -load $HOME/.Xresources
	setpath $HOME/.config/berry
	$TERM &
	sxhkd -c $HOME/.config/berry/sxhkdrc &
	conky clock auto
	xexec berry ;;

bs* ) 
	killall panel 2>/dev/null
	rm -f /tmp/bspwm-socket 2>/dev/null
	rm -f /tmp/bspwm.lock
	setpath $HOME/.config/bspwm
	sxhkd -c $HOME/.config/bspwm/sxhkdrc &
	xexec bspwm ;;

bu* )
	$HOME/.screenlayout/budgie.sh
	autostart
	xexec budgie-session ;;

ci* ) xexec gnome-session-cinnamon ;;
go* ) xexec goomwwm ;;
dw* ) xexec dwm ;;

he* )
	pkill -KILL -f 'herbst'
	# export ROOT=$HOME/tmp
	export PANEL_BOTTOM=true
	export SETROOT=$(cat $HOME/.setroot 2>/dev/null)  # setroot last wallpaper or wall, otherwise random wall
	setpath $HOME/.config/herbstluftwm
	. $HOME/.config/herbstluftwm/config/ENV
	which xdotool >/dev/null || $TERM &  # initial build install?
	# $TERM &
	xexec herbstluftwm ;;

gn* ) xexec gnome-session ;;
i3  ) xexec i3 ;;
kd* ) xexec startkde ;;
le* ) xexec leftwm ;;
lxd*) xexec lxsession ;;
lxq*) xexec startlxqt ;;
ma* ) xexec mate-session ;;
no* ) xexec notion ;;
op* ) xexec openbox-session ;;
rat*) xexec ratpoison ;;
raz*) xexec razor-session ;;
sp* ) xexec spectrwm ;;
st* ) xexec stumpwm ;;
su* ) xexec subtle ;;
wmi*) xexec wmii ;;

wi* )
	setpath $HOME/.config/windowchef
	export SXHKD_SHELL=/usr/bin/dash
	xsetroot -solid grey20
	xrdb -load $HOME/.Xresources
	sxhkd -c $HOME/.config/windowchef/sxhkdrc &
	$TERM &
	xexec windowchef ;;

wm* )
	setpath $HOME/.config/wmutils
	export SXHKD_SHELL=/usr/bin/dash
	xsetroot -solid grey20
	xrdb -load $HOME/.Xresources
	sxhkd -c $HOME/.config/wmutils/sxhkdrc &
	wew | yawee &
	$TERM &
	pwait wew ;;

wo* )
	export BLACKBOARD=/tmp/worm:blackboard
	xwallpaper --zoom $HOME/images/default
	xrdb -load $HOME/.Xresources
	setpath $HOME/.config/worm
	$TERM &
	conky clock auto
	xexec worm ;;

wt* )
	$TERM &
	xexec wtftw ;;

xf* ) xexec xfce4-session ;;
xm* ) xexec xmonad ;;
*   ) xexec $DEFAULTSESSION ;;
esac

# vim: set ft=sh: #
