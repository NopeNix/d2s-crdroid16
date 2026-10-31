# OTA updates — serving updates to the phone

## How the Updater app works (verified on-device against crDroid 16 Updater, 2026-10-26)

crDroid 16 ships a rewritten `packages/apps/Updater` ("NetworkUpdate"). Behavior
as verified on the d2s dev build (handover-9):

- **It GETs the URL from the `updater_server_url` string resource ONLY.** The
  `lineage.updater.uri` runtime prop of older Lineage Updaters is NOT read
  (README legend only). We override the resource via **channel-specific
  device-tree overlays** (d2s fork commit `88bd604`, 2026-10-30):
  `device/samsung/d2s/overlay/updater/dev/packages/apps/Updater/.../strings.xml`
  → `ota/dev.json` and `.../overlay/updater/prod/...` → `ota/prod.json`,
  selected by `DEVICE_PACKAGE_OVERLAYS` in `nopenix.mk` per `NOPENIX_VARIANT`.
  `PRODUCT_ENFORCE_RRO_TARGETS := *` converts the override into auto-RROs.
  **Gotchas (learned 2026-10-30, see MEMORY.md):**
  - the overlay dir path inside must **mirror the target package's source
    path** (`packages/apps/Updater/app/src/main/res/values/`) or aapt2
    silently drops the override (RRO builds with no URL at all);
  - the override URL lands in the **vendor** auto-RRO
    (`vendor/overlay/Updater__aosp_d2s__auto_generated_rro_vendor.apk`);
    a product-partition Updater RRO may exist without any URL (not an error).
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

The phone side: the build bakes `updater_server_url` (via the channel overlay
RRO, see `docs/branding.md`) pointing at its channel's JSON. The runtime prop
override trick of older Lineage builds does **not** exist in crDroid 16. A
running phone only re-reads its baked URL after an **OTA or reflash** — it
never re-polls a different URL on its own. Proven migration path (2026-10-30,
prod phone migrated dev→prod channel in place):
1. Publish the new build (which bakes the NEW channel URL) to its own channel.
2. Add one clearly-labeled TEMPORARY entry to the OLD channel's JSON pointing
   at the same zip (same filename/sha/size, honest timestamp). The phone,
   polling the old channel, gets offered it and installs in place.
3. After reboot the phone runs the new build and polls the new channel.
4. Remove the temporary entry from the old channel.

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
2. **Channel check (mandatory, before publish)**:
   `scripts/verify-ota-channel.sh <signed-target-files.zip> <dev|prod>` —
   asserts the Updater RRO(s) in the signed TF bake the intended channel's
   `updater_server_url`. FAILs on wrong channel, missing URL (aapt2 overlay
   drop), or conflicting URLs across RROs. Wired as stage 5 of
   `run-sign-prod.sh`; a `CHANNEL_CHECK_FAILED` in the sign log = do NOT
   publish. Added 2026-10-30 after the prod 20261030 build was found to have
   baked dev.json (see release note for the full story).
3. Generate the JSON entry: `scripts/ota-json.sh <zip> [version] [buildtype]`
   (fixed 2026-10-28, commit 870c591: emits the flat `{"response":[...]}` format
   and reads post-timestamp/SPL/SDK from the signed META-INF metadata — the old
   nested-files[] note is obsolete). Prod entries: `buildtype` = `release`,
   then append the entry object to `ota/prod.json`.
4. Commit updated `ota/dev.json` (or `ota/prod.json`) + create GitHub release
   with the zip + recovery.img.
5. Verify with `curl <json url>` — **wait out the raw.githubusercontent CDN
   cache (~5 min; a new commit's content is not served immediately)** — and
   confirm `timestamp` advanced AND that it is newer than any entry already
   served on that channel. Never publish an entry whose timestamp is older
   than, or equal to, the newest entry already present (the Updater would
   ignore it as "up to date").
6. On the phone: Updater → check for update → download → install (in-place
   update; first Nopenix flash still needs the sideload path below).
7. Add a note in `releases/`.

> **Timestamp honesty rule** (2026-10-30): never bump a published entry's
> timestamp to force an update offer — that breaks future build ordering.
> If you need the phone to take a build it already runs (chain exercise) or a
> build on the "wrong" channel (migration), use a separate labeled TEMPORARY
> entry and remove it afterwards (see migration path above).
