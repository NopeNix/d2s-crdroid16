# Nopenix dev 13.0 (2026-10-31, ts 1793455983) - d2s

First release carrying the **signed Magisk zip** (official workstream
2026-11-01, commit `2654ba3`): `Nopenix-magisk-v31.1-dev-20261031-d2s.zip` is a
flashable zip, sideloadable from **our own recovery** (signed with the Nopenix
releasekey — spec: `docs/proposals/2026-11-01-signed-magisk-zip.md`). No code
changes vs 20261030 dev; this is the same build line with the new artifact
workflow live.

- SPL: 2026-10-01
- Build timestamp: 1793455983
- ROM sha256: `274758bcc8b7ba3b2138dabfa396c89a75432effeb9644d8f1c4e691d2a91f28`
- Magisk zip sha256: `a17b2ba5916d978b72f5658f930f688989e962a8f551d24af54423641ceedc45`
- Rooted OTA sha256: `52299feb07bfa99b2e1e4dc81f58dd0ea852da25feed45086b1e10a7b3ea2317`
- Release: https://github.com/NopeNix/d2s-crdroid16/releases/tag/nopenix-dev-13.0-20261031
- Channel: ota/dev.json (Nightly) — ⚠ magisk zip is NOT a channel entry, asset only

## Magisk zip notes

- Magisk pinned **v31.1** (APK sha256 verified `89cefac0…26ac6e7`).
- Any OTA removes root (OTA ships unpatched boot.img) → re-sideload the
  matching magisk zip after each update.
- On-device acceptance test (sideload → boot → Magisk "Installed") — DONE
  (v31.1, magiskd root, su, SELinux enforcing).

## ROOTED flavor (owner decision 2026-11-01)

- `Nopenix-dev-13.0-20261031-d2s-ROOTED.zip`: the SAME dev build with a
  Magisk-patched boot baked in (`scripts/make-rooted-ota.sh`). Root SURVIVES
  future rooted dev OTAs. Unroot = install the rootless zip. Offered in
  `ota/dev.json` as `23.2-rooted` (timestamp+60 until the downgrade prop ships).
- ⚠ On-device acceptance test for the ROOTED OTA zip itself: prod ROOTED zip
  DONE on device (owner, zero errors — same patch sequence); dev ROOTED zip
  itself PENDING (high confidence).
