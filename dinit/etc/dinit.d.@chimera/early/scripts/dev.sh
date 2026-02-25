#!/bin/sh

case "$1" in
	start   ) /usr/bin/udevd --daemon      ;;
	stop    ) udevadm control -e           ;;
	settle  ) udevadm settle               ;;
	trigger ) udevadm trigger --action=add ;;
esac

