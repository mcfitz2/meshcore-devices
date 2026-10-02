#!/usr/bin/env bash
# Print the release asset filenames for a device, one per line. Single source
# of truth for what build-device.sh produces and what plan-builds.sh and
# build-site.sh expect, per platform.
# usage: scripts/assets.sh <slug> <version>
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
slug=$1
version=$2

platform=$(jq -er --arg s "$slug" '.[] | select(.slug == $s) | .platform' "$root/devices.json")
case "$platform" in
  esp32) printf '%s\n' "$slug-$version.bin" "$slug-$version-merged.bin" ;;
  nrf52) printf '%s\n' "$slug-$version.uf2" "$slug-$version.zip" ;;
  *)
    echo "error: unknown platform \"$platform\" for $slug" >&2
    exit 1
    ;;
esac
