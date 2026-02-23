#!/bin/sh

DINIT_SERVICE=pseudofs
# can't mount in containers
DINIT_NO_CONTAINER=1

. /etc/dinit.d/early/scripts/common.sh

exec /etc/dinit.d/early/helpers/mnt prepare ${dinit_early_root_remount:-ro,rshared}
