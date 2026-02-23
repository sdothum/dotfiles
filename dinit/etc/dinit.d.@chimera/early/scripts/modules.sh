#!/bin/sh

DINIT_SERVICE=modules
DINIT_NO_CONTAINER=1

. /etc/dinit.d/early/scripts/common.sh

exec /etc/dinit.d/early/helpers/kmod modules
