#!/bin/sh

cleanup() {
	rm faouziarc sxhkdrc
	exit 0
}

trap 'cleanup' INT

D=${D:-80}

Xephyr -screen 1280x720 :$D&
sleep 1

export DISPLAY=:$D
cp examples/sxhkdrc sxhkdrc
cp examples/faouziarc faouziarc
sed -i 's/sirocco/.\/sirocco/g' sxhkdrc faouziarc
sxhkd -c sxhkdrc &
./faouzia -c faouziarc
