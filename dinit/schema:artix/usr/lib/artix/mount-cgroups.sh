#!/bin/sh
# Code from Void Runit

[ -r /etc/rc.conf ] && . /etc/rc.conf
# Detect LXC (and other) containers
[ -z "${container+x}" ] || export VIRTUALIZATION=1

if [ -z "$VIRTUALIZATION" ]; then
	_cgroupv1=""
	_cgroupv2=""

	case "${CGROUP_MODE:-hybrid}" in
		legacy)
			_cgroupv1="/sys/fs/cgroup"
			;;
		hybrid)
			_cgroupv1="/sys/fs/cgroup"
			_cgroupv2="${_cgroupv1}/unified"
			;;
		unified)
			_cgroupv2="/sys/fs/cgroup"
			;;
	esac

	# cgroup v1
	if [ -n "$_cgroupv1" ]; then
		mountpoint -q "$_cgroupv1" || mount -o mode=0755 -t tmpfs cgroup "$_cgroupv1"
		while read -r _subsys_name _hierarchy _num_cgroups _enabled; do
			[ "$_enabled" = "1" ] || continue
			_controller="${_cgroupv1}/${_subsys_name}"
			mkdir -p "$_controller"
			mountpoint -q "$_controller" || mount -t cgroup -o "$_subsys_name" cgroup "$_controller"
		done < /proc/cgroups
	fi

	# cgroup v2
	if [ -n "$_cgroupv2" ]; then
		mkdir -p "$_cgroupv2"
		mountpoint -q "$_cgroupv2" || mount -t cgroup2 -o nsdelegate cgroup2 "$_cgroupv2"
	fi
fi
