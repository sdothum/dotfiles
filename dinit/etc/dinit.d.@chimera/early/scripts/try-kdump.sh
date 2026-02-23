#!/bin/sh

[ -x "/etc/dinit.d/early/scripts/kdump.sh" ] || exit 0

exec /etc/dinit.d/early/scripts/kdump.sh "$@"
