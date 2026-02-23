#!/bin/sh

DINIT_SERVICE=net-lo

. /etc/dinit.d/early/scripts/common.sh

exec /etc/dinit.d/early/helpers/lo
