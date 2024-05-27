#!/bin/sh
# Code from Void Runit
 
# Detect LXC (and other) containers
[ -z "${container+x}" ] || export VIRTUALIZATION=1

case $1 in
	stop )
		# The system is being shut down
		if [ -z "$VIRTUALIZATION" ]; then
			echo "Saving random number seed.."
			seedrng
		fi
		;;
	*    )
		install -m0664 -o root -g utmp /dev/null /run/utmp

		if [ -z "$VIRTUALIZATION" ]; then
			echo "Seeding random number generator..."
			seedrng || true
		fi

		# Configure network
		echo "Setting up loopback interface..."
		ip link set up dev lo

		[ -r /etc/hostname ] && read -r HOSTNAME < /etc/hostname
		if [ -n "$HOSTNAME" ]; then
			echo "Setting up hostname to '${HOSTNAME}'..."
			printf "%s" "$HOSTNAME" > /proc/sys/kernel/hostname
		else
			echo "Didn't setup a hostname!"
		fi

		if [ -f /etc/localtime ]; then
			loc_set=$(readlink -f /etc/localtime)
			set_zone=$(echo "$loc_set" | sed s%"/usr/share/zoneinfo/"%""%g)
			echo "Timezone set to '${set_zone}'"
		else
			[ -r /etc/rc.conf ] && . /etc/rc.conf
			echo "Setting timezone to '${TIMEZONE}'..."
			ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
		fi
		;;
esac
