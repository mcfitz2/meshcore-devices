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
config_sha=$(git -C "$root" rev-parse HEAD | cut -c1-7)

# Upstream copies FIRMWARE_VERSION into a 20-byte field in the companion
# device-info reply, so it must be at most 19 characters.
if [ "$version" = dev ]; then
  fw_version="dev-$sha"
else
  fw_version="$version-$config_sha"
fi
if [ "${#fw_version}" -gt 19 ]; then
  echo "error: firmware version \"$fw_version\" is longer than 19 characters" >&2
  exit 1
fi

# Both files below are changed in the checkout for the build only. Keep copies
# and restore them on exit (success or failure) so a local run leaves the
# user's MeshCore checkout, including any edits of their own, as it was.
board_h="$meshcore/src/helpers/ESP32Board.h"
local_ini="$meshcore/platformio.local.ini"
backup=$(mktemp -d)
cp "$board_h" "$backup/ESP32Board.h"
had_local_ini=0
if [ -e "$local_ini" ]; then
  had_local_ini=1
  cp "$local_ini" "$backup/platformio.local.ini"
fi
restore() {
  cp "$backup/ESP32Board.h" "$board_h"
  if [ "$had_local_ini" = 1 ]; then
    cp "$backup/platformio.local.ini" "$local_ini"
  else
    rm -f "$local_ini"
  fi
  rm -rf "$backup"
}
trap restore EXIT

# upstream ESP32Board::begin() calls adcAttachPin(), which Arduino core 3.x (C6)
# removed, so any C6 build with PIN_VBAT_READ fails to compile. The call is
# unnecessary: analogReadMilliVolts() attaches the pin itself.
if grep -q 'adcAttachPin(PIN_VBAT_READ);' "$backup/ESP32Board.h"; then
  sed '/adcAttachPin(PIN_VBAT_READ);/d' "$backup/ESP32Board.h" > "$board_h"
else
  echo "note: upstream no longer calls adcAttachPin(PIN_VBAT_READ); the ESP32Board.h workaround in build-device.sh can be removed" >&2
fi

# upstream platformio.ini loads platformio.local.ini if present
cat "$root"/devices/*.ini > "$local_ini"

build_date=$(date '+%d %b %Y')
export PLATFORMIO_BUILD_FLAGS="-DFIRMWARE_BUILD_DATE='\"$build_date\"' -DFIRMWARE_VERSION='\"$fw_version\"'"
cd "$meshcore"
pio run -e "$env"
pio run -e "$env" -t mergebin

mkdir -p "$root/out"
cp ".pio/build/$env/firmware.bin" "$root/out/$slug-$version.bin"
cp ".pio/build/$env/firmware-merged.bin" "$root/out/$slug-$version-merged.bin"
