#!/bin/sh

DINIT_SERVICE=binfmt
DINIT_NO_CONTAINER=1

. /etc/dinit.d/early/scripts/common.sh

if [ "$1" = "stop" ]; then
   exec /etc/dinit.d/early/helpers/binfmt -u
fi

# require the module if it's around, but don't fail - it may be builtin
/etc/dinit.d/early/helpers/kmod load binfmt_misc

# try to make sure it's mounted too, otherwise binfmt-helper will fail
/etc/dinit.d/early/helpers/mnt try /proc/sys/fs/binfmt_misc binfmt_misc binfmt_misc \
    nosuid,noexec,nodev 2>/dev/null

exec /etc/dinit.d/early/helpers/binfmt
