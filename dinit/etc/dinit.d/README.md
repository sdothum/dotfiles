# Dinit

These files are based on the initial work by [summrum/void_dinit](https://github.com/summrum/void_dinit).

The initial service files have been modified were necessary to run on my system. Notably the "network" service did not meet my needs and has been rewritten.
## udev

Of particular note is the addition of the "udev-settle" service to boot.d removing it as a "depends-on" requirement for the "console-setup" and "filesystems" services. (The appropriate lines are commented out).

## WHY?

With udev as a service dependency, the boot times are identical to Runit -- faster than most other distros, at roughly 12 seconds on my system -- the largest delay consumed by udev settling and its impact to dependent services.

Removing it as a service dependency reduces the boot time on my system to roughly 2 seconds! i have not experienced any system instability so far but consider this a highly experimental service configuration.

As it stands, even without the above udev configuration, Dinit remains unsupported on Voidlinux as a system init. USE AT YOUR OWN RISK.

## TODO

Bring up to date with latest Void Runit core scripts.


