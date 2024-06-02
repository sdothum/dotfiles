#!/bin/sh

[ -s /etc/hostname ] && HOSTNAME="$(cat /etc/hostname)"
[ "$HOSTNAME" ] && echo "$HOSTNAME" >| /proc/sys/kernel/hostname
