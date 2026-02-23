#!/bin/sh
#
# tries to commit machine-id to disk to mark boot done
#

DINIT_SERVICE=done
# the mount test would fail, might as well just skip it altogether
DINIT_NO_CONTAINER=1

. /etc/dinit.d/early/scripts/common.sh

# was never bind-mounted, so just exit
/etc/dinit.d/early/helpers/mnt is /etc/machine-id || exit 0
# no generated machine-id
test -e /run/dinit/machine-id || exit 0

/etc/dinit.d/early/helpers/mnt umnt /etc/machine-id

if touch /etc/machine-id > /dev/null 2>&1; then
    cat /run/dinit/machine-id > /etc/machine-id
else
    # failed to write, bind it again
    /etc/dinit.d/early/helpers/mnt mnt /etc/machine-id /run/dinit/machine-id none bind
fi

exit 0
