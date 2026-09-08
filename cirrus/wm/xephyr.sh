#!/bin/sh

cleanup() {
	rm cirrusrc sxhkdrc
	exit 0
}

trap 'cleanup' INT

D=${D:-80}

Xephyr -screen 1280x720 :$D&
sleep 1

export DISPLAY=:$D
cp examples/sxhkdrc sxhkdrc
cp examples/cirrusrc cirrusrc
sed -i 's/sirocco/.\/sirocco/g' sxhkdrc cirrusrc
sxhkd -c sxhkdrc &
./cirrus -c cirrusrc
