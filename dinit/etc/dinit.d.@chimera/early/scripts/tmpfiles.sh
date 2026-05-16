#!/bin/sh
exit 0  # NOTE: disabled for this Voidlinux installation

DINIT_SERVICE=tmpfiles

. /usr/lib/dinit.d/early/scripts/common.sh

sd-tmpfiles "$@"

RET=$?
case "$RET" in
	65) exit 0 ;; # DATERR
	73) exit 0 ;; # CANTCREAT
	*) exit $RET ;;
esac
