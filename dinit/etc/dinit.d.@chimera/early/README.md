# dinit.d patches to dinit-chimera

## dev.sh

- udev implementation

## tmpfiles.sh

- stub (exit 0)
- cannot build sd-tmpfiles on void glibc
- sd-tmpfiles is systemd related, hence, ignored
- NOTE: a number of services are systemd related (but simply exit 0)

## early-devices.target

- waits-for: service completions
- attempted to ascertain whether udev settle is boot delay culprit
- no discernible improvement in boot time
