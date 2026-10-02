# meshcore-devices

Custom [MeshCore](https://github.com/meshcore-dev/MeshCore) firmware builds for my devices, rebuilt automatically when MeshCore publishes a release.

## Devices

| Device | Hardware | Firmware | Releases |
|---|---|---|---|
| Solar Repeater | Xiao ESP32-C6 + Wio-SX1262 kit (header-wired) | repeater, WiFi OTA enabled | [releases](../../releases?q=solar-repeater) |
| Stealth Companion | Heltec V3 | companion (BLE) | [releases](../../releases?q=stealth-companion) |
| GMRS Backpack Companion | Heltec V3 | companion (BLE) | [releases](../../releases?q=gmrs-backpack-companion) |

Every build uses the US preset (910.525 MHz / 62.5 kHz / SF7 / CR5) as its first-boot default. No passwords are built in; set admin and guest passwords in the app. Devices keep their saved settings across updates.

## Web flasher

**https://mcfitz2.github.io/meshcore-devices/** flashes the newest release of each device over USB from desktop Chrome or Edge.

- Updating a device: answer **No** to "Erase device?" to keep its settings and contacts.
- New or wiped device: answer **Yes**.

## Release files

Each release is named `<device>-<version>`, e.g. `solar-repeater-v1.17.1`.

- `<device>-<version>.bin`: app image. Use it to update a device that already runs MeshCore (OTA or USB).
- `<device>-<version>-merged.bin`: full flash image, written at `0x0`. Use it for a new or wiped device.

## Updating the Solar Repeater over WiFi

1. Send `start ota` from the app or CLI.
2. Join the open `MeshCore-OTA` WiFi network and open `http://192.168.4.1/update`.
3. Upload `solar-repeater-<version>.bin`. The device reboots when done.

## How builds run

- **Check for MeshCore releases** runs daily. For each device it looks up the latest MeshCore release of that device's firmware type and builds it if this repo has no matching release yet.
- Each device also has its own workflow (e.g. **Solar Repeater**) to build on demand, optionally for a specific MeshCore version.
- After any build, **Deploy web flasher** republishes the site with each device's highest-version release.

GitHub disables scheduled workflows in public repos after 60 days without commits. If that happens, re-enable **Check for MeshCore releases** from the Actions tab.

## Adding a device

1. Add an entry to `devices.json`: `slug`, `name`, `firmware` (`repeater`, `companion` or `room-server`), `env`, `hardware` (shown on the flasher page) and `chip` (ESP Web Tools chip family, e.g. `ESP32-S3`).
2. Add `devices/<slug>.ini` defining `[env:<env>]`. Extend an upstream target and add `${us_preset.build_flags}`.
3. Copy one of the per-device workflows in `.github/workflows/` and change its name and slug.
4. Run `scripts/check-devices.sh` to check that `devices.json` and `devices/` agree (the **Lint** workflow also runs it on pushes and PRs).

Build locally with `scripts/build-device.sh <slug> <path-to-MeshCore-checkout>`.
