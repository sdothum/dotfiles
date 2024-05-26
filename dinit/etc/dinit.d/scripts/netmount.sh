#!/bin/sh
# Code from Void Runit
. /etc/dinit.d/config/netmount.conf

case $1 in
	start )
		# Ensure the network manager is running
		[ -z "$NETWORK_MANAGER" ] || sv check "$NETWORK_MANAGER" > /dev/null 2>&1 || exit 1

		# If it's running or not in used - rc.local - discover default gateway
		if [ -z "$GATEWAY" ]; then
			set -- $(ip route show | grep default)
			GATEWAY="$3"
		fi

		ping -W 1 -c 1 $GATEWAY > /dev/null 2>&1 || exit 1

		# Network is up and running so now mount network filesystems from fstab
		mount -a -t "$NETWORK_FS" || exit 1
		mount -a -O _netdev || exit 1

		# Then wait to behave like the service is up
		exec pause
		;;

	stop  )
		# Don't do anything if ./run didn't exit properly (RUNIT "finish" not applicable here)
		# [ "$1" -eq 1 ] && exit 0

		# Simply umount network filesystems
		umount -a -f -t $NETWORK_FS > /dev/null 2>&1
		ret=$?
		[ $ret -ne 0 ] && umount -a -f -l -t $NETWORK_FS > /dev/null 2>&1

		umount -a -f -O _netdev > /dev/null 2>&1
		ret=$?
		[ $ret -ne 0 ] && umount -a -f -l -O _netdev > /dev/null 2>&1
		;;
esac




