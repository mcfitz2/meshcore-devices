#!/usr/bin/env bash
# Print the newest published MeshCore release tag for a firmware family
# (repeater, companion, room-server), e.g. "repeater-v1.17.1".
# usage: scripts/latest-tag.sh <firmware>
set -euo pipefail

tag=$(gh release list -R meshcore-dev/MeshCore --exclude-drafts --exclude-pre-releases \
  --limit 100 --json tagName,publishedAt \
  --jq "[.[] | select(.tagName | startswith(\"$1-v\"))] | sort_by(.publishedAt) | last | .tagName")

if [ -z "$tag" ] || [ "$tag" = "null" ]; then
  echo "no MeshCore release found for '$1'" >&2
  exit 1
fi
echo "$tag"
