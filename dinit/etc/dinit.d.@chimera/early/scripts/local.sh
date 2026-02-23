#!/bin/sh

DINIT_SERVICE=local

. /etc/dinit.d/early/scripts/common.sh

[ -x /etc/rc.local ] && /etc/rc.local

exit 0
