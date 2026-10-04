#!/usr/bin/dash
set -x

sdk="$HOME/.Garmin/ConnectIQ/Sdks/connectiq-sdk-lin-9.2.0-2026-06-09-92a1605b2"

podman run --rm -it \
   $1 \
   --name garmin-ciq-sim \
   --network=host \
   --userns=keep-id \
   --user "$(id -u):$(id -g)" \
   -e DISPLAY="$DISPLAY" \
   -e HOME="$HOME" \
   -e LIBGL_ALWAYS_SOFTWARE=1 \
   -e GALLIUM_DRIVER=llvmpipe \
   -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
   -v "$HOME:$HOME:rw" \
   garmin-ciq-sim \
   strace -f -o "$HOME/ciq-simulator.strace" \
   "$sdk/bin/connectiq"
