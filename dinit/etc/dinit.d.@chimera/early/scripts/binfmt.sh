#!/bin/sh
exit 0  # NOTE: disabled for this Voidlinux installation

DINIT_SERVICE=binfmt
DINIT_NO_CONTAINER=1

. /usr/lib/dinit.d/early/scripts/common.sh

if [ "$1" = "stop" ]; then
   exec /usr/lib/dinit.d/early/helpers/binfmt -u
fi

# require the module if it's around, but don't fail - it may be builtin
/usr/lib/dinit.d/early/helpers/kmod load binfmt_misc

# try to make sure it's mounted too, otherwise binfmt-helper will fail
/usr/lib/dinit.d/early/helpers/mnt try /proc/sys/fs/binfmt_misc binfmt_misc binfmt_misc \
    nosuid,noexec,nodev 2>/dev/null

exec /usr/lib/dinit.d/early/helpers/binfmt
