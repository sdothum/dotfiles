# dinit.d patches to dinit-chimera

## dev.sh

- udev implementation

## tmpfiles.sh

- stub (exit 0)
- sd-tools does not build on void glibc without updating with missing header files
- sd-tmpfiles is systemd tmpfile manager daemon, hence, ignored
- NOTE: a number of services are systemd related (but simply exit 0)

## early-devices.target

- waits-for: service completions
- attempted to ascertain whether udev settle is boot delay culprit
- no discernible improvement in boot time
