#!/bin/sh

DINIT_SERVICE="cryptdisks-${1:-unknown}"
DINIT_NO_CONTAINER=1

. /etc/dinit.d/early/scripts/common.sh

[ -x "/usr/libexec/dinit-cryptdisks" ] || exit 0

exec "/usr/libexec/dinit-cryptdisks" "$@"
