#!/usr/bin/dash

udev
sleep 1

cd ~/stow/garmin/interstellar

./build.sh fr955
[ $? -eq 0 ] || exit

# ifno "upload watchface (connect watch to usb)" && exit
mtp mount
[ $? -eq 0 ] || exit

cp -v bin/interstellar.prg \
	"$HOME/mtp/Internal Storage/GARMIN/Apps/"

sync
# ifno "unmount mtp" && sync || mtp umount


