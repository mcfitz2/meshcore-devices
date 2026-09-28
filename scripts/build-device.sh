#!/usr/bin/env bash
# Build one device's firmware from a MeshCore checkout.
# Outputs out/<slug>-<version>.bin (update/OTA) and
# out/<slug>-<version>-merged.bin (full flash at 0x0).
# usage: scripts/build-device.sh <slug> <meshcore-dir>
set -euo pipefail

slug=$1
root=$(cd "$(dirname "$0")/.." && pwd)
meshcore=$(cd "$2" && pwd)

env=$(jq -er --arg s "$slug" '.[] | select(.slug == $s) | .env' "$root/devices.json")
version=$(git -C "$meshcore" describe --tags --exact-match 2>/dev/null || echo dev)
version=${version##*-}
sha=$(git -C "$meshcore" rev-parse --short HEAD)

# upstream platformio.ini loads platformio.local.ini if present
cat "$root"/devices/*.ini > "$meshcore/platformio.local.ini"

export PLATFORMIO_BUILD_FLAGS="-DFIRMWARE_BUILD_DATE='\"$(date '+%d %b %Y')\"' -DFIRMWARE_VERSION='\"$version-$sha\"'"
cd "$meshcore"
pio run -e "$env"
pio run -e "$env" -t mergebin

mkdir -p "$root/out"
cp ".pio/build/$env/firmware.bin" "$root/out/$slug-$version.bin"
cp ".pio/build/$env/firmware-merged.bin" "$root/out/$slug-$version-merged.bin"
