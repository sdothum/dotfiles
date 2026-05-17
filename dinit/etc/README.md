# dinit.d on Voidlinux

## runit like stack

**dinit.d.@void** contains the dinit stack modelled after summrun's git repo posted
in the early days of dinit -- which is based largely on the **runit core
services**
(and is, unsurprisingly, similar to the Void repository example services).

## Chimera Linux stack

**dinit.d.@chimera** utilizes the **[Chimera Linux](https://github.com/chimera-linux/dinit-chimera)** dinit stack which must be
compiled and installed separately.

The services in /etc/dini.d include additional typically "required" services for
managing network connectivity, dbus, etc. plus the services particular to my
Void installation.

**Note:**

- the **tmpfiles.sh** service script must be stubbed to "exit 0" as Void does
not utilize a systemd like tmpfile manager. It can fail a boot, otherwise.

- the **dev.sh** service script must be modified to manage udev.

- if the **binfmt.sh** service script causes reboot/shutdown issues, it can be stubbed to
"exit 0" to avoid its call to its **helper** executable. i have not tested whether this is cleared
by installing Void's **binfmt-support** package or whether this is kernel
version specific. If retained and random issues occur, the service can be
stopped prior to rebooting instead to prevent any potential prolonged delays -- a
reboot script to do so (stop service) allows preserving maximum fidelity to the Chimera dinit stack.

SEE the dinit.d.@chimera/early/scripts directory and copy these scripts to
/usr/lib/dinit.d/early/scripts/
