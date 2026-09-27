#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

sdk=${CONNECTIQ_SDK:-}
if [ -z "$sdk" ]; then
    sdk=$(find "$HOME/.Garmin/ConnectIQ/Sdks" \
        -mindepth 1 -maxdepth 1 -type d 2>/dev/null |
        sort -V | tail -n 1)
fi

if [ -z "$sdk" ] || [ ! -x "$sdk/bin/monkeyc" ]; then
    printf '%s\n' \
        'Connect IQ SDK not found.' \
        'Set CONNECTIQ_SDK to the extracted SDK directory.'
    exit 1
fi

key=${CONNECTIQ_KEY:-"$HOME/.Garmin/ConnectIQ/Keys/developer_key.der"}
device=${1:-fr955}

mkdir -p "$project_dir/bin"

"$sdk/bin/monkeyc" \
    -f "$project_dir/monkey.jungle" \
    -d "$device" \
    -y "$key" \
    -o "$project_dir/bin/orbital.prg" \
    -w

printf 'Built: %s\n' "$project_dir/bin/orbital.prg"
