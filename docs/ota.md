# OTA updates — serving updates to the phone

## How the Updater app works (verified on-device against crDroid 16 Updater, 2026-10-26)

crDroid 16 ships a rewritten `packages/apps/Updater` ("NetworkUpdate"). Behavior
as verified on the d2s dev build (handover-9):

- **It GETs the URL from the `updater_server_url` string resource ONLY.** The
  `lineage.updater.uri` runtime prop of older Lineage Updaters is NOT read
  (README legend only). We override the resource via a device-tree overlay at
  `device/samsung/d2s/overlay/packages/apps/Updater/app/src/main/res/values/strings.xml`;
  `PRODUCT_ENFORCE_RRO_TARGETS := *` converts it to an auto-RRO that lands in
  `vendor/overlay/Updater__aosp_d2s__auto_generated_rro_vendor.apk` (verified in
  the 2026-10-26 target files).
- The response must be a JSON object wrapping an array, with **flat** per-build
  fields (NOT the old nested `files[]` format — bare arrays and nested entries
  are both rejected/parsed-incorrectly by the new Updater):
  ```json
  {
    "response": [
      {
        "maintainer": "Nopenix",
        "oem": "Samsung",
        "device": "Galaxy Note10+",
        "filename": "nopenix-dev-13.0-20261026-d2s.zip",
        "download": "https://github.com/NopeNix/d2s-crdroid16/releases/latest/download/nopenix-dev-13.0-20261026-d2s.zip",
        "timestamp": 1793044455,
        "sha256": "e1da56bb...",
        "size": 1518604804,
        "version": "23.2",
        "buildtype": "Nightly",
        "os_patch_level": "2026-04-01",
        "os_sdk_level": 36
      }
    ]
  }
  ```
- **Matching: `timestamp` + `os_sdk_level`**, NOT the JSON `version` field
  (that is display-only in the new Updater). The Updater offers any entry with a
  newer timestamp whose sdk level matches the device. `buildtype` is informational
  (the channel split is by URI, see below).
- PRODUCT_NAME stays `lineage_d2s` regardless (see `docs/branding.md`).
- `ota_property_files` (A/B payload offsets) is not needed: d2s is a non-A/B
  recovery device; the flat entry works without it.

## Hosting on GitHub (decided: releases + raw JSON)

- **Zips** → GitHub **Releases** on `NopeNix/d2s-crdroid16` (limit 2 GB/file; our zips ≈1.5 GB → OK).
- **JSON** → committed to this repo, one file per channel (per `docs/dev-prod.md`):
  - `ota/dev.json` — dev line (type `nightly`), served at
    `https://raw.githubusercontent.com/NopeNix/d2s-crdroid16/main/ota/dev.json`
  - `ota/prod.json` — prod line (type `release`), served at
    `https://raw.githubusercontent.com/NopeNix/d2s-crdroid16/main/ota/prod.json`
  Raw GitHub serves HTTPS with stable content — acceptable to the Updater.
  (Alternative: GitHub Pages if raw proves problematic.)

The phone side: the build bakes `updater_server_url` (via the device-tree overlay
RRO, see `docs/branding.md`) pointing at its channel's JSON. The runtime prop
override trick of older Lineage builds does **not** exist in crDroid 16 — to
re-point a running device you must rebuild with a different overlay value, or
debug-test by temporarily replacing the RRO on device.

## Upgrade path: official crDroid 12.9 → first Nopenix build

**Important**: you cannot OTA straight from official 12.9 to our build. The official
recovery only trusts crDroid's release keys; our zips are signed with our own keys
(see `docs/signing.md`).

One-time manual path:

1. Unlock bootloader (already done if you're on crDroid 12.9).
2. Flash our built `recovery.img` (comes out of our first build; also attached to the release):
   - Odin (Windows): AP slot, or `heimdall flash --RECOVERY recovery.img --no-reboot` (Linux).
3. Boot recovery (Vol Up + Power while rebooting), "Apply update" → "Apply from ADB" →
   `adb sideload nopenix-<...>.zip`.
4. Reboot. Verify Settings → About shows the Nopenix branding + new security patch level.
5. From now on: Updater app polls the baked `updater_server_url` JSON and applies
   our signed zips (same-key chain).

Later updates (Nopenix → Nopenix) are true in-place OTAs via the Updater app.
(Also proven: the agent-driven recovery flash method of handover-9 — adb reboot
recovery → `adb root` → push OTA in chunks to /data → run `update-binary` from
the unpacked zip — installs a package without any user menu steps.)

## OTA release checklist (per build)

> Two channels per docs/dev-prod.md: `ota/dev.json` (type `Nightly`, dev line —
> published freely, that is the point) and `ota/prod.json` (type `release`, prod
> line — only after the prod Definition of done). Each build's baked
> `updater_server_url` RRO points at its channel. Magisk note for prod: OTA
> rewrites `boot` → Magisk re-patch required before reboot after every prod OTA.

1. Build + sign (docs/signing.md, docs/build-guide.md); prod releases use the
   hardened variant, dev releases the debug variant.
2. Generate the JSON entry: `scripts/ota-json.sh <zip> [version] [type]`.
   ⚠ NOTE (2026-10-26): the script still emits the OLD nested `files[]` format —
   it must be updated to the flat `{"response":[...]}` schema before the next
   release (open item; `ota/dev.json` was hand-edited to the correct format).
3. Commit updated `ota/dev.json` (or `ota/prod.json`) + create GitHub release
   with the zip + recovery.img.
4. Verify with `curl <json url>` and confirm `timestamp` advanced.
5. On the phone: Updater → check for update → download → install (in-place
   update; first Nopenix flash still needs the sideload path below).
6. Add a note in `releases/`.
