#!/usr/bin/env bash
# Check that devices.json and devices/*.ini agree, so a bad entry fails here
# instead of in a firmware build. Prints every problem as "error: ..." on
# stderr and exits 1; prints "devices.json OK (<N> devices)" on success.
# usage: scripts/check-devices.sh
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
json="$root/devices.json"
errors=0

err() {
  echo "error: $*" >&2
  errors=$((errors + 1))
}

if ! jq -e 'type == "array" and length > 0' "$json" > /dev/null 2>&1; then
  err "devices.json must be a valid, non-empty JSON array"
  exit 1
fi

count=$(jq length "$json")

# required string fields, allowed firmware values, optional boolean ota
while IFS= read -r msg; do
  err "$msg"
done < <(jq -r '
  to_entries[] | .key as $i | .value as $d
  | if ($d | type) != "object" then "entry \($i) is not an object"
    else
      (("slug","name","firmware","env","hardware","chip") as $f
        | select(($d[$f] | type) != "string" or $d[$f] == "")
        | "entry \($i) (\($d.slug // "?")): missing or empty string field \"\($f)\""),
      (select(($d.firmware | type) == "string" and $d.firmware != ""
              and (["repeater","companion","room-server"] | index($d.firmware) | not))
        | "entry \($i) (\($d.slug // "?")): firmware \"\($d.firmware)\" must be repeater, companion or room-server"),
      (select($d | has("ota") and (.ota | type) != "boolean")
        | "entry \($i) (\($d.slug // "?")): field \"ota\" must be true or false")
    end
' "$json")

# duplicates
while IFS= read -r v; do err "duplicate slug \"$v\""; done < <(
  jq -r '[.[] | objects | .slug | strings] | group_by(.)[] | select(length > 1) | .[0]' "$json")
while IFS= read -r v; do err "duplicate env \"$v\""; done < <(
  jq -r '[.[] | objects | .env | strings] | group_by(.)[] | select(length > 1) | .[0]' "$json")

# per-device slug format and ini file
while IFS=$'\t' read -r slug env; do
  [[ -n "$slug" ]] || continue
  if ! [[ "$slug" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
    err "slug \"$slug\" must be lowercase letters, digits and single hyphens"
  fi
  ini="$root/devices/$slug.ini"
  if [[ ! -f "$ini" ]]; then
    err "devices/$slug.ini does not exist (slug \"$slug\")"
  elif [[ -n "$env" ]] && ! grep -qxF "[env:$env]" "$ini"; then
    err "devices/$slug.ini has no line \"[env:$env]\""
  fi
done < <(jq -r '.[] | objects | select((.slug | type) == "string") | [.slug, (.env | strings)] | @tsv' "$json")

# orphan ini files
for f in "$root"/devices/*.ini; do
  name=$(basename "$f" .ini)
  [[ "$name" == common ]] && continue
  if ! jq -e --arg s "$name" 'any(.[]; type == "object" and .slug == $s)' "$json" > /dev/null; then
    err "devices/$name.ini matches no slug in devices.json"
  fi
done

if ((errors > 0)); then
  exit 1
fi
echo "devices.json OK ($count devices)"
