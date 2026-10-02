#!/usr/bin/env bash
# Build the web flasher site into site/: for each device, download the
# merged image from its newest release and write an ESP Web Tools manifest.
# Needs GH_REPO (owner/name) and a gh token.
# usage: scripts/build-site.sh
set -euo pipefail

# esp-web-tools is vendored from its npm tarball so the flasher page doesn't
# run code served by a third-party CDN. Bump both together; the integrity is
# .dist.integrity from https://registry.npmjs.org/esp-web-tools/<version>
esp_web_tools_version=10.4.0
esp_web_tools_integrity=sha512-3pwkeFFm5Fj7UQo8SJNYK5RXrtNCpq6X9QoI6bMT4GBZWgrJqjn0YvM9ihG74BtMoSFYXfmDtkehuxe50PTMPQ==

root=$(cd "$(dirname "$0")/.." && pwd)
site="$root/site"
rm -rf "$site"
mkdir -p "$site/firmware"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
curl -fsSL -o "$tmp/ewt.tgz" \
  "https://registry.npmjs.org/esp-web-tools/-/esp-web-tools-$esp_web_tools_version.tgz"
actual="sha512-$(openssl dgst -sha512 -binary < "$tmp/ewt.tgz" | openssl base64 -A)"
if [ "$actual" != "$esp_web_tools_integrity" ]; then
  echo "error: esp-web-tools $esp_web_tools_version tarball integrity mismatch" >&2
  exit 1
fi
tar -xzf "$tmp/ewt.tgz" -C "$tmp" package/dist/web
mkdir -p "$site/esp-web-tools"
cp -R "$tmp/package/dist/web/." "$site/esp-web-tools/"

rows=""
while read -r device; do
  slug=$(jq -r .slug <<< "$device")
  name=$(jq -r .name <<< "$device")
  hardware=$(jq -r .hardware <<< "$device")
  chip=$(jq -r .chip <<< "$device")

  # highest version, not newest, so an on-demand build of an old version
  # doesn't replace the current one
  release=$(gh release list --limit 100 --json tagName \
    --jq ".[] | select(.tagName | test(\"^$slug-v[0-9]\")) | .tagName" | sort -V | tail -1)
  if [ -z "$release" ]; then
    echo "$slug: no release yet, skipping"
    continue
  fi
  version=${release#"$slug-"}
  echo "$slug: $version"

  mkdir -p "$site/firmware/$slug"
  gh release download "$release" --pattern "$slug-$version-merged.bin" --dir "$site/firmware/$slug"

  jq -n --arg name "$name" --arg version "$version" --arg chip "$chip" \
    --arg path "$slug-$version-merged.bin" '{
      name: $name,
      version: $version,
      new_install_prompt_erase: true,
      builds: [{chipFamily: $chip, parts: [{path: $path, offset: 0}]}]
    }' > "$site/firmware/$slug/manifest.json"

  rows+="
      <tr>
        <td><strong>$name</strong><br><small>$hardware</small></td>
        <td><a href=\"https://github.com/$GH_REPO/releases/tag/$release\">$version</a></td>
        <td><esp-web-install-button manifest=\"firmware/$slug/manifest.json\"></esp-web-install-button></td>
      </tr>"
done < <(jq -c '.[]' "$root/devices.json")

cat > "$site/index.html" <<EOF
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>MeshCore device flasher</title>
  <script type="module" src="esp-web-tools/install-button.js"></script>
  <style>
    body { font-family: system-ui, sans-serif; max-width: 760px; margin: 2rem auto; padding: 0 1rem; line-height: 1.5; }
    table { border-collapse: collapse; width: 100%; }
    td, th { padding: .6rem; border-bottom: 1px solid #ddd; text-align: left; vertical-align: middle; }
    small { color: #666; }
    .note { background: #f4f4f4; padding: .8rem 1rem; border-radius: 6px; }
  </style>
</head>
<body>
  <h1>MeshCore device flasher</h1>
  <p>Connect the device over USB and click <em>Connect</em>. Needs desktop Chrome or Edge.</p>
  <table>
    <tr><th>Device</th><th>Version</th><th></th></tr>$rows
  </table>
  <div class="note">
    <p><strong>Updating a device:</strong> answer <em>No</em> to "Erase device?" to keep its name, radio settings, passwords and contacts.</p>
    <p><strong>New or wiped device:</strong> answer <em>Yes</em>. It starts with the US preset; set admin and guest passwords in the app.</p>
    <p>If the device isn't detected, hold BOOT while plugging it in.</p>
  </div>
  <p><small>Built by <a href="https://github.com/$GH_REPO">$GH_REPO</a> from <a href="https://github.com/meshcore-dev/MeshCore">MeshCore</a> releases.</small></p>
</body>
</html>
EOF
