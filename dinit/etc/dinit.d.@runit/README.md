# Dinit

These files are based on the initial work by [summrum/void_dinit](https://github.com/summrum/void_dinit).

The initial service files have been modified were necessary to run on my system. Notably the "network" service did not meet my needs and has been rewritten.
## udev

Of particular note is the change of the "depends-on" udev-settle to "waits-for" udev-trigger for the "console-setup" and "filesystems" services. (The appropriate lines are commented out).

**DO NOT DO THIS** if you require block devices like LVM: change the above services to "depends-on" udev-settle.

## WHY?

With udev as a service dependency, the boot times are identical to Runit -- faster than most other distros, at roughly 12 seconds on my system -- the largest delay consumed by udev settling and its impact to dependent services.

Removing it as a service dependency reduces the boot time on my system (with M.2 NVMe drives) to barely over 1 second! i have not experienced any system instability but recommend one use the "depends-on" udev-settle for the "console-setup" and "filesystems" services.

As it stands, even without the above experimental udev configuration, Dinit remains unsupported on Voidlinux. **USE AT YOUR OWN RISK**.

## Resources

Other than the official [Dinit](https://davmac.org/projects/dinit/) project page, Artix and Chimera Linux distros should be installed/referenced for their dinit deployment. Both utilize a much more granular services configuration which, i imagine, help trim the (udev) boot time with dinit's parallel service execution versus Void/Runit's fewer more linear scripts (which are also reflected in "summrun's" original dinit work.)

Even with the udev-settle time, Runit (and by virtue of this dinit cloning of the service structure) is plenty fast (and faster than most other distros).

Again, **USE AT YOUR OWN RISK**.
