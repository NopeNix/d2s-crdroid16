# Branding — how "Nopenix" becomes visible without breaking OTA

## Constraint (do not break this)

The Updater app matches OTA JSON `version` against `ro.lineage.build.version`, and the
device's product name (`PRODUCT_NAME = lineage_d2s`) is what `brunch d2s` resolves.
**Do NOT rename PRODUCT_NAME / PRODUCT_DEVICE / the product makefile.** Branding is
additive, via props and display strings.

## What we set (all RESOLVED in the 2026-10-26 dev build — see handover-9)

1. **Version props** — in our `android_device_samsung_d2s` fork, `nopenix.mk`
   (included from `device.mk` BEFORE the crDroid vendor inherit) sets:
   - `NOPENIX_VARIANT ?= dev` (build wrapper may override per line: dev|prod)
   - `NOPENIX_VERSION := 13.0`
   - `CR_VERSION := 13.0` — must be set in nopenix.mk because crDroid's
     `vendor/lineage/config/version.mk` hardcodes `CR_VERSION := 12.12`; carried
     as `patches/vendor_lineage_version-cr-version-optional.patch` (makes it
     `?=`) so the device value wins.
   - `ro.nopenix.variant`, `ro.nopenix.version`, `ro.lineage.build.version=23.2`
     via `PRODUCT_PRODUCT_PROPERTIES`.
2. **Updater URL** — crDroid 16 Updater reads the `updater_server_url` string
   resource ONLY (the old `lineage.updater.uri` prop is NOT read). Override via
   **channel-specific device-tree overlays** (d2s `88bd604`, 2026-10-30):
   `overlay/updater/dev/packages/apps/Updater/app/src/main/res/values/strings.xml`
   (→ `ota/dev.json`) and `overlay/updater/prod/...` (→ `ota/prod.json`),
   selected by `DEVICE_PACKAGE_OVERLAYS` in `nopenix.mk` per `NOPENIX_VARIANT`;
   `PRODUCT_ENFORCE_RRO_TARGETS := *` turns the override into the auto-RRO
   `Updater__aosp_d2s__auto_generated_rro_vendor.apk` (vendor partition).
   Rules: the overlay dir must mirror the package source path, and the baked
   channel MUST be verified before publish via
   `scripts/verify-ota-channel.sh` (hub) — the 2026-10-30 prod build shipped
   with dev.json baked because `NOPENIX_OTA_URI` was computed but never
   consumed; that variable is gone.
3. **Zip name** — `LINEAGE_VERSION := nopenix-<dev|prod>-<version>-<date>-d2s`
   reassigned in `device/samsung/d2s/lineage_d2s.mk`. Release naming therefore
   follows `nopenix-dev-13.0-YYYYMMDD-d2s.zip` style.
4. **Display version** — Settings → About shows `v13.0-YYYYMMDD` (crDroid's
   display string derives from `CR_VERSION` + build date). All changes are
   additive props/strings; PRODUCT_NAME stays `lineage_d2s` (do NOT rename).

## Resolved (2026-10-26, handover-9)

- [x] crDroid 16.0 version-string prop = `CR_VERSION` in `config/version.mk`
      (overridable via our patch + `nopenix.mk`). Display version verified live.
- [x] Zip filename generator var = `LINEAGE_VERSION` (device-tree reassignment).
- [x] Updater URL = `updater_server_url` resource overlay (auto-RRO), verified
      baked into target files and fetched by the on-device Updater.

> Whoever resolves these: update this doc (ask user first) + append to MEMORY.md.

> Dev/prod note (2026-10-26): v13.0-dev verified live on device with
> `ro.nopenix.variant=dev`, `ro.nopenix.version=13.0`, display `v13.0-20261026`,
> `ro.lineage.build.version=23.2` (handover-9). For prod, the same `nopenix.mk`
> with `NOPENIX_VARIANT=prod` selects the `overlay/updater/prod` Updater
> overlay (`ota/prod.json`) — verified on device 2026-10-31 (prod phone
> migrated dev→prod channel via one in-place OTA; see docs/ota.md).
