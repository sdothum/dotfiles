#!/bin/sh
# Code from Void Runit

# Detect LXC (and other) containers
[ -z "${container+x}" ] || export VIRTUALIZATION=1
[ -n "$VIRTUALIZATION" ] && return 0

case $1 in
	stop )
		if [ -z "$VIRTUALIZATION" ]; then
			echo "Stopping udev..."
			udevadm control --exit
		fi
		;;
	*    )
		if [ -x /usr/lib/systemd/systemd-udevd ]; then
			_udevd=/usr/lib/systemd/systemd-udevd
		elif [ -x /sbin/udevd -o -x /bin/udevd ]; then
			_udevd=udevd
		else
			echo "cannot find udevd!"
		fi

		if [ -n "${_udevd}" ]; then
			echo "Starting udev and waiting for devices to settle..."
			${_udevd} --daemon
		fi
		;;
esac
