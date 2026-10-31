# ota/ — Updater JSON channels (dev/prod two-line model)

Per docs/dev-prod.md there are two channels:

- `ota/dev.json` — dev line, entries `"type": "nightly"`. Served at
  https://raw.githubusercontent.com/NopeNix/d2s-crdroid16/main/ota/dev.json
- `ota/prod.json` — prod line, entries `"buildtype": "release"`. Served at
  https://raw.githubusercontent.com/NopeNix/d2s-crdroid16/main/ota/prod.json
  **First entry published 2026-10-30** (`nopenix-13.0-20261030-d2s.zip`, the
  channel-fixed prod build, ts 1793395784). NOTE: GitHub's raw CDN caches for
  ~5 minutes after a push — verify with a wait, not immediately.

IMPORTANT (verified against the crDroid 16 Updater source, 2026-10-26): the new
Updater does NOT read the `lineage.updater.uri` runtime prop (README-only
legend). The URL comes from the `updater_server_url` string resource, which the
build overrides via a device-tree overlay converted to an auto-RRO by
`PRODUCT_ENFORCE_RRO_TARGETS := *` (lands in vendor/overlay as
`Updater__aosp_d2s__auto_generated_rro_vendor.apk`). Verified baked in the
2026-10-26 dev build target files.

The Updater matches updates by `timestamp` + `os_sdk_level`, NOT by the JSON
`version` field (that is display-only in the new Updater). `ro.lineage.build.version`
is still set (23.2) for doc consistency.

Regenerate JSON entries with `scripts/ota-json.sh <zip> [version] [type]`.
`dev.json` is created when the first dev build is published (in progress).
