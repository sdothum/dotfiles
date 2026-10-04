#!/usr/bin/dash

cd ~/stow/garmin/gravitywell

./build.sh fr955

ifno "upload watchface (connect watch to usb)" && exit
mtp mount

cp -v bin/gravitywell.prg \
	"$HOME/mtp/Internal Storage/GARMIN/Apps/"

sync
ifno "unmount mtp" && sync || mtp umount


