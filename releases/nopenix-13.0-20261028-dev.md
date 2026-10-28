# Nopenix dev 13.0 (2026-10-28) — d2s

Round-3 dev-line build. crDroid 16.0 base (Lineage 23.2), dev variant
(userdebug + debug knobs: adb root, su).

- **Security patch level: 2026-10-01** (up from 2026-04-01 in round 2 — ASB
  catch-up via targeted repo sync of crDroid/Lineage upstream projects)
- Build timestamp: 1793135136 (2026-10-27 21:05 UTC)
- sha256: `e40b8fa681d8a0a88d6fa241b5f260f3066c5fc8316d32ef2af7ad3ee8fb6ab6`
- Size: 1,521,950,513 bytes
- Release: https://github.com/NopeNix/d2s-crdroid16/releases/tag/nopenix-dev-13.0-20261028
- Channel: `ota/dev.json` (Nightly)

## Changelog vs round 2 (nopenix-dev-13.0-20261026)

- ASB catch-up: upstream sync of crDroid/Lineage github projects; local patches
  (ro.secure/gen_build_prop, SPOOF_SAFETYNET, libbt, version.mk, ...) re-applied.
- New SPL 2026-10-01.

## On-device verification (2026-10-28)

Boots, adb root = uid 0, branding live (ro.nopenix.variant=dev,
ro.crdroid.build.version=13.0), BT ON, WiFi connected (11ax), LTE IN_SERVICE
(Telekom), sensors/camera present. Installed via recovery sideload (not yet via
Updater in-place — that exercise is still pending). GNSS outdoor test pending.
