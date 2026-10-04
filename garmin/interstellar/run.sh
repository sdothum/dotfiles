#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

sdk=${CONNECTIQ_SDK:-}
if [ -z "$sdk" ]; then
    sdk=$(find "$HOME/.Garmin/ConnectIQ/Sdks" \
        -mindepth 1 -maxdepth 1 -type d 2>/dev/null |
        sort -V | tail -n 1)
fi

device=${1:-fr955}
prg="$project_dir/bin/interstellar.prg"

[ -f "$prg" ] || "$project_dir/build.sh" "$device"

"$sdk/bin/monkeydo" "$prg" "$device"
