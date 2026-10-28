# Daily-driver target (decided 2026-10-26) — SUPERSEDED

> **Superseded by `docs/dev-prod.md` (2026-10-26, same day).** This file's
> "no Magisk on the daily image" stance was reversed by the owner: prod carries
> Magisk root by design. Kept for history; do not update further.

The project's end goal changed on 2026-10-26: Nopenix is not just a community
continuation — the **project owner wants to run this build as their personal daily
driver**: real SIM, real data, banking apps. Every release is judged against that.

## Hard requirements

1. **Current security patch level.** The build must track crDroid 16.0 upstream
   (which carries the Android Security Bulletin patches). v13 currently ships
   `2026-04-01` (parity with the last official v12.9); the next build must catch up
   and every later build must follow the upstream ASB cadence (Phase 3 in ROADMAP).
   A stale patch level is a **release blocker**.
2. **Release-grade, non-debug image.** Flash-day debug builds (adb-root,
   `BuildBrokenDupSysprop` dup-sysprop escape hatch, `ro.secure` fiddling) are
   bring-up tools only. A daily-driver release must be:
   - user variant (or userdebug with debug doors closed) — no adb-root convenience,
   - SELinux enforcing,
   - no Magisk / no root / no spoofing modules — root trades security for
     compatibility and is explicitly rejected for the daily image,
   - only our signing keys, key material never on-device.
3. **OTA-updatable in place.** Updates must install through the Updater app without
   a PC, so the owner actually applies patch-level bumps promptly.

## Known limits (honest disclosure)

- **Google Play Integrity cannot be passed.** Unlocked bootloader + custom signing
  keys means no hardware-backed device attestation for our ROM. Banking apps and
  other apps that *enforce* device integrity may refuse to run. This applies to
  **every** custom ROM on this hardware, including the official crDroid v12.9 —
  it is not something we broke.
  - Mitigation A: keep the image root-free (root/spoof modules are the "fix" but
    weaken the daily driver — rejected by default).
  - Mitigation B: test the owner's actual banking apps on each release and record
    which work in `releases/nopenix-<version>.md`.
- **Verified boot is disabled** (Samsung allows no custom AVB keys while unlocked;
  vbmeta verification is turned off at flash time). Accepted risk; mitigations:
  read-only system partition, only flash builds we signed ourselves, private keys
  never leave the build host.

## Definition of done for a "daily driver" release

- [ ] Patch level == latest upstream ASB level (or documented gap)
- [ ] Non-debug variant (no adb-root; SELinux enforcing confirmed on device)
- [ ] Subsystem checklist green (BT, LTE, WiFi, audio, sensors, S-Pen, camera, GNSS)
- [ ] Owner's banking apps tested; results recorded in the release note
- [ ] OTA JSON published; Updater finds and installs it in place
- [ ] Release note in `releases/` with sha256, patch level, app-test results
