# ROADMAP — status and next steps

**Two build lines (decided 2026-10-26, docs/dev-prod.md): DEV then PROD.**
Dev = open debug playground (userdebug + debug knobs, adb-root), the CURRENT MAIN
GOAL; its OTA channel (nightly) must be exercised. Prod = the owner's hardened
daily driver WITH Magisk root (Zygisk denylist for banking), SELinux enforcing,
encrypted data; patch level tracks upstream ASB. Known limit (both): unlocked
bootloader + own keys ⇒ no Google Play Integrity — accepted. Authoritative
next-session task list: `docs/flash-day-handover-8.md`.

Legend: ⚪ todo · 🟡 in progress · 🟢 done · 🔴 blocked

## Phase 0 — Research & repo setup 🟢
- [x] Identify device, maintainer, official build history (docs/history.md)
- [x] Fork device/common/kernel/blob repos to NopeNix
- [x] Hub repo structure, AGENTS.md, MEMORY.md, docs
- [x] Local manifest written (manifests/nopenix.xml)

## Phase 1 — First build 🟡 (next!)
- [ ] Build host prepared (Ubuntu, deps, repo tool) — build-guide.md §1–2
- [ ] `repo sync` with our local manifest
- [ ] Blob layout verification: TheMuppets lineage-23.2 vs proprietary-files.txt (blob-strategy.md)
- [ ] Signing keys generated (signing.md)
- [ ] Branding wired: version strings, updater URI, zip naming (branding.md)
- [ ] `brunch d2s` succeeds end-to-end
- [ ] Boot test on device

## Phase 2 — OTA pipeline 🟡 (partially prepared)
- [x] OTA JSON format documented; ota-json.sh written
- [x] v13 flashed on device (2026-10-26): boots, BT/LTE/WiFi/audio/sensors/S-Pen verified
- [ ] DEV build with debug knobs ON (BUILD_BROKEN_DUP_SYSPROP → adb-root works) —
      current main goal; handover-8 item 3
- [ ] Variant/branding props: ro.nopenix.variant=dev, ro.lineage.build.version fix,
      Nopenix display version, nopenix-dev zip naming — handover-8 item 2
- [ ] Dev OTA channel: ota/dev.json (nightly), lineage.updater.uri, in-place Updater
      install exercised on dev — handover-8 item 6
- [ ] Device-tree fixes pushed to NopeNix forks (BT glue, VINTF, SPOOF_SAFETYNET,
      branding) — handover-8 item 7
- [ ] GNSS outdoor verification — handover-8 item 8
- [ ] PROD line (only after dev is done): hardened user build + Magisk root
      (Zygisk denylist), prod.json channel, GitHub Releases, banking-app tests
      recorded in releases/

## Phase 3 — Security-patch cadence 🟪 (routine) — HARD REQUIREMENT for daily driver
- [ ] Monthly: `repo sync` crDroid 16.0 upstream → rebuild → release (patch-level bump)
- [ ] Track upstream security merges: crdroidandroid 16.0 branches carry the ASB patches
- [ ] Watch for crDroid upstream abandoning 16.0 → decide: pin vs. rebase to Lineage 23.2 directly

## Phase 4 — Optional hygiene
- [ ] CI for docs (markdown lint) — cheap, doable on GitHub runners
- [ ] Verify what "stock kernel" in v12.9 means; decide our kernel stance (default: use
      crdroidandroid kernel 16.0 branch as-is)

## Decisions log
- 2026-10-04: hub-and-forks repo model (code in forks, docs/manifests here)
- 2026-10-04: TheMuppets lineage-23.2 blobs default (docs/blob-strategy.md)
- 2026-10-04: local builds only (GH runners insufficient); releases via GitHub Releases
- 2026-10-04: keep PRODUCT_NAME `lineage_d2s`; brand via props (docs/branding.md)
