#!/usr/bin/dash

podman run --rm -it \
   --name garmin-ciq-sim \
   --network=host \
   --security-opt label=disable \
   -e DISPLAY="$DISPLAY" \
   -e XAUTHORITY=/tmp/.Xauthority \
   -v /tmp/.X11-unix:/tmp/.X11-unix \
   -v "${XAUTHORITY:-$HOME/.Xauthority}:/tmp/.Xauthority:ro" \
   -v "$HOME/.Garmin/ConnectIQ:/root/.Garmin/ConnectIQ" \
   localhost/garmin-ciq-sim:latest \
   /root/.Garmin/ConnectIQ/Sdks/connectiq-sdk-lin-9.2.0-2026-06-09-92a1605b2/bin/simulator &

