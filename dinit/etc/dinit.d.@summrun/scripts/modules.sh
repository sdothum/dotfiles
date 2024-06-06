#!/bin/sh
# Code from Void Runit

export PATH=/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin

for f in $(kmod static-nodes -f devname 2>/dev/null|cut -d' ' -f1); do
	modprobe -bq $f 2>/dev/null
done

# Detect LXC (and other) containers
[ -z "${container+x}" ] || export VIRTUALIZATION=1
[ -n "$VIRTUALIZATION" ] && return 0
# Do not try to load modules if kernel does not support them.
[ ! -e /proc/modules ] && return 0

echo "Loading kernel modules..."
modules-load -v | tr '\n' ' ' | sed 's:insmod [^ ]*/::g; s:\.ko\(\.gz\)\? ::g'
echo
