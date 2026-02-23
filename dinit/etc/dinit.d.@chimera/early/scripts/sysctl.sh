#!/bin/sh

DINIT_SERVICE=sysctl

. /etc/dinit.d/early/scripts/common.sh

exec /etc/dinit.d/early/helpers/sysctl
