#!/bin/sh

case "$1" in
	stop )
		for conf in /etc/wireguard/*.conf; do
			[ -e "$conf" ] || continue;
			wg-quick down "$conf"
		done
		;;
	*    )
		for conf in /etc/wireguard/*.conf; do
			[ -e "$conf" ] || continue;
			wg-quick up "$conf"
		done
		;;
esac
