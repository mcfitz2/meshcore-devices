#!/usr/bin/env bash
# Print the JSON list of builds the daily check should run. A device needs a
# build when its release for the latest MeshCore version (a) doesn't exist,
# (b) lacks an expected asset (see scripts/assets.sh), or (c) was built from older
# device config than HEAD.
# Needs GH_REPO (owner/name), a gh token and full git history.
# usage: scripts/plan-builds.sh
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)

if [ "$(git -C "$root" rev-parse --is-shallow-repository)" = true ]; then
  echo "error: needs full git history (fetch-depth: 0)" >&2
  exit 1
fi

builds='[]'
while read -r slug firmware; do
  tag=$("$root/scripts/latest-tag.sh" "$firmware")
  version=${tag##*-}
  release="$slug-$version"

  reason=""
  if ! info=$(gh release view "$release" --json body,assets 2>/dev/null); then
    reason="no release"
  else
    while read -r asset; do
      if ! jq -e --arg a "$asset" 'any(.assets[].name; . == $a)' <<< "$info" >/dev/null; then
        reason="missing $asset"
        break
      fi
    done < <("$root/scripts/assets.sh" "$slug" "$version")
  fi

  if [ -z "$reason" ]; then
    marker=$(jq -r .body <<< "$info" |
      sed -n 's/^<!-- config-sha: \([0-9a-f]\{40\}\) -->.*/\1/p' | head -1)
    # newest commit touching anything that feeds this device's build
    latest=$(git -C "$root" log -1 --format=%H -- \
      devices.json devices/common.ini "devices/$slug.ini" scripts/build-device.sh)
    if [ -z "$marker" ]; then
      reason="no config marker"
    elif ! git -C "$root" merge-base --is-ancestor "$latest" "$marker" 2>/dev/null; then
      reason="config changed"
    fi
  fi

  if [ -z "$reason" ]; then
    echo "$slug: $version up to date" >&2
  else
    echo "$slug: building $version ($reason)" >&2
    builds=$(jq -c --arg s "$slug" --arg v "$version" '. + [{slug: $s, version: $v}]' <<< "$builds")
  fi
done < <(jq -r '.[] | "\(.slug) \(.firmware)"' "$root/devices.json")

echo "$builds"
