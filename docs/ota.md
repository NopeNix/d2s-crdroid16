# OTA updates — serving updates to the phone

## How the Updater app works (verified against crDroid/LineageOS Updater source)

crDroid 16 ships `packages/apps/Updater` (Lineage Updater lineage). Behavior:

- It GETs the URL from the `updater_server_url` string resource, overridable at runtime
  by the system property **`lineage.updater.uri`**.
- The response must be a JSON array:
  ```json
  [
    {
      "datetime": 1781858358,
      "files": [
        {
          "filename": "ota-package.zip",
          "os_patch_level": "2026-06-01",
          "os_sdk_level": 36,
          "ota_property_files": "payload_metadata.bin:4662:187245,...",
          "sha256": "11468fc2...",
          "size": 1926282058,
          "url": "https://example.com/full/ota-package.zip"
        }
      ],
      "type": "nightly",
      "version": "23.2"
    }
  ]
  ```
- `version` is matched against **`ro.lineage.build.version`**; `type` against
  `ro.lineage.releasetype`. This is why we must **not** rename PRODUCT_NAME away from
  `lineage_d2s` (see `docs/branding.md`).
- `ota_property_files` comes from `META-INF/com/android/metadata` of the built zip.
  `scripts/ota-json.sh` extracts these fields automatically.

## Hosting on GitHub (decided: releases + raw JSON)

- **Zips** → GitHub **Releases** on `NopeNix/d2s-crdroid16` (limit 2 GB/file; our zips ≈1.5 GB → OK).
- **JSON** → committed to this repo (e.g. `ota/d2s.json`) and served via
  `https://raw.githubusercontent.com/NopeNix/d2s-crdroid16/main/ota/d2s.json`.
  Raw GitHub serves proper `application/json`-ish content with HTTPS — acceptable to the Updater.
  (Alternative: GitHub Pages if raw proves problematic.)

The phone side: Settings → System → Updater is configured by the build's
`lineage.updater.uri` prop (set in our device-tree overlay — see `docs/branding.md`).
For the transition build you can also set the URI manually:

```bash
adb shell setprop lineage.updater.uri https://raw.githubusercontent.com/NopeNix/d2s-crdroid16/main/ota/d2s.json
```

(persistent value gets baked into the next build's prop default).

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
5. From now on: Updater app polls our JSON and applies our signed zips (same-key chain).

Later updates (Nopenix → Nopenix) are true in-place OTAs via the Updater app.

## OTA release checklist (per build)

> Two channels per docs/dev-prod.md: `ota/dev.json` (type nightly, dev line —
> published freely, that is the point) and `ota/prod.json` (type release, prod line
> — only after the prod Definition of done). Devices point at their channel via
> `lineage.updater.uri` baked per line. Magisk note for prod: OTA rewrites `boot`
> → Magisk re-patch required before reboot after every prod OTA.

1. Build + sign (docs/signing.md, docs/build-guide.md); prod releases use the
   hardened variant, dev releases the debug variant.
2. Run `scripts/ota-json.sh` on the zip → prints JSON block.
3. Commit updated `ota/d2s.json` + create GitHub release with the zip + recovery.img.
4. Verify with `curl <json url>` and confirm `version`/`datetime` advanced.
5. On the phone: Updater → check for update → download → install.
6. Add a note in `releases/`.
