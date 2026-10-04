#!/usr/bin/dash

cd ~/stow/garmin/interstellar

./build.sh fr955

ifno "upload watchface (connect watch to usb)" && exit
mtp mount

cp -v bin/interstellar.prg \
	"$HOME/mtp/Internal Storage/GARMIN/Apps/"

sync
ifno "unmount mtp" && sync || mtp umount


