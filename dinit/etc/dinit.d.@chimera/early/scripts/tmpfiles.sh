#!/bin/sh
exit 0  # systemd (sd-) specific command (cannot build chimera/sd-tools)

DINIT_SERVICE=tmpfiles

. /etc/dinit.d/early/scripts/common.sh

sd-tmpfiles "$@"

RET=$?
case "$RET" in
	65) exit 0 ;; # DATERR
	73) exit 0 ;; # CANTCREAT
	*) exit $RET ;;
esac
