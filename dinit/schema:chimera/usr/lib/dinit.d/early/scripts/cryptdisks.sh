#!/bin/sh

DINIT_SERVICE="cryptdisks-${1:-unknown}"
DINIT_NO_CONTAINER=1

. ./early/scripts/common.sh

[ -r /usr/lib/cryptsetup/cryptdisks-functions ] || exit 0
[ -r /etc/crypttab ] || exit 0

. /usr/lib/cryptsetup/cryptdisks-functions

INITSTATE="$1"

case "$2" in
    start) do_start ;;
    stop) do_stop ;;
    *) exit 1 ;;
esac
