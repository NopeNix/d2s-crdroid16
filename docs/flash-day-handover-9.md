# Flash-Day Handover #9 — 2026-10-26 ~21:40 UTC (READ THIS ONE FIRST)

> **SUPERSEDED by handover #10 (2026-10-28): round 3 was built, flashed, and published;
> the round-3 publish + verification this file described as pending is DONE. Read handover-10 first.**

> Supersedes handover #8. Dev line round-2 is ON THE PHONE AND FULLY WORKING.

## TL;DR — CURRENT STATE

- **Dev line (v13.0-dev, 2026-10-26) is verified working**: boots, adb authorized,
  **adb root = uid 0** (WITH_SU=true packaged `adb_root` service + `su`;
  `/data/adbroot/enabled` must contain `1`), su works, Nopenix branding live
  (`ro.nopenix.variant=dev`, `ro.crdroid.build.version=13.0`, display
  `v13.0-20261026`, `ro.lineage.build.version=23.2`), SPL 2026-04-01.
- Subsystems: BT ON, WiFi validated, LTE IN_SERVICE (Telekom, after SIM PIN entry),
  sensors, S-Pen, camera — all green. GNSS outdoor NOT yet tested.
- **Dev OTA channel is LIVE and proven server-side**: `ota/dev.json` (flat crDroid
  format) + GitHub release `nopenix-dev-13.0-20261026` (OTA zip + recovery img).
  On-device Updater fetched, parsed, and registered the download entry.
- Artifacts: `/srv/android/nopenix-d2s/out/Nopenix-signed-ota.zip`
  (sha256 e1da56bb0cafae1f3f73f03360a7c9e1d25dcf9e20b142107705955dcce2d6e4),
  `Nopenix-recovery-signed.img` (md5 2c4f882415a2b8b170f67e21e297260a).

## KEY DISCOVERIES THIS SESSION (change how things work — see MEMORY.md too)

1. **crDroid 16 Updater does NOT read `lineage.updater.uri`.** It reads the
   `updater_server_url` string resource. Override via device-tree overlay at
   `device/samsung/d2s/overlay/packages/apps/Updater/app/src/main/res/values/strings.xml`
   → auto-RRO lands in `vendor/overlay/Updater__aosp_d2s__auto_generated_rro_vendor.apk`.
2. **Updater JSON format** = `{"response":[{ ... flat fields ... }]}` — flat:
   maintainer/oem/device/filename/download/timestamp/sha256/size/version/buildtype/
   os_patch_level/os_sdk_level. NOT nested `files[]`. Bare array rejected.
3. **Updater matches by timestamp + sdk level**, NOT the JSON `version` field.
4. **`adb root` needs crDroid's `adbroot_service`** — packaged only with
   `WITH_SU=true` (adds `adb_root` + `su`). Also create `/data/adbroot/enabled`
   containing `1` (one-time, via su).
5. **Version override**: `vendor/lineage/config/version.mk` patched to
   `CR_VERSION ?= 12.12`; device tree sets `CR_VERSION := 13.0` in
   `device/samsung/d2s/nopenix.mk` (included from device.mk BEFORE the lineage
   common inherit). Zip naming via `LINEAGE_VERSION` reassignment in
   `lineage_d2s.mk`. Patch carried in hub `patches/`.
6. **`/cache/bootlog.txt` (init.debug.rc full logcat) filled the 564 MB cache
   partition** → OTA updater ENOSPC. Now capped at 50 MB (`head -c`).
7. **AGENT-DRIVEN FLASH METHOD (proven 2x, no user menu steps)**:
   `adb reboot recovery` → `adb root` (recovery adbd root works) →
   `mount -t f2fs /dev/block/sda32 /data` → `split -b 400M` OTA → push chunks →
   md5 verify each → `cat` to `/data/otaNN.zip` → md5 vs host → unzip
   `update-binary` to /tmp → detached run:
   `setsid sh -c "nohup /tmp/META-INF/com/google/android/update-binary 3 1 /data/otaNN.zip 3>/tmp/log 1>/tmp/out 2>/tmp/err &"`
   (it is an ELF, NOT a sh script; fd 3 carries UI) → wait for
   `script succeeded: result was [1.000000]` → clean chunks → reboot.
   NOTE: recovery boots sometimes come up with adbd as uid 2000 — run `adb root`
   first and it becomes uid 0. System boots come up authorized (no RSA friction).

## ROUND 2 CHANGES SUMMARY (all local-only, /srv/android/nopenix-d2s)

- `device/samsung/d2s/nopenix.mk` (new): CR_VERSION=13.0, variant/version props,
  OTA URI switch (dev|prod), NOPENIX_VARIANT from build wrapper (default dev).
- `device/samsung/d2s/device.mk`: include nopenix.mk.
- `device/samsung/d2s/lineage_d2s.mk`: LINEAGE_VERSION := nopenix-dev-<ver>-<date>-d2s.
- `device/samsung/d2s/init.debug.rc`: bootlog capped 50 MB.
- `vendor/lineage/config/version.mk`: CR_VERSION ?= (local patch, carried).
- Build wrappers: `/srv/android/build-start.sh` and `/srv/android/run-tf61.sh` now
  export WITH_SU=true + BUILD_BROKEN_DUP_SYSPROP=true + WITH_ADB_INSECURE=true.
  (run-tf61.sh writes to /srv/android/tf61.log; sign: /srv/android/run-sign61.sh →
  /srv/android/sign61.log — stage1 unzip, stage2 sign, stage3 ota, stage4 recovery.)

## HUB REPO (committed + pushed to main)

- `ota/dev.json` (flat format), `ota/README.md` (two channels + corrections),
  `patches/device_d2s-nopenix.mk`,
  `patches/vendor_lineage_version-cr-version-optional.patch`.
- GitHub release `nopenix-dev-13.0-20261026` with OTA zip + recovery img.
- MEMORY.md session-8 entry + permanent ASB policy entry.

## PERMANENT POLICY (user, 2026-10-26): latest patches always

Every future build integrates the latest available Android ASB + latest patches of
all other components. Round 3 = `repo sync` crDroid 16.0 upstream first.

## NEXT SESSION TASK LIST (round 3)

1. **ASB catch-up**: `repo sync` crDroid 16.0 upstream (or as much as feasible),
   re-apply local patches (gen_build_prop.py ro.secure, SPOOF_SAFETYNET init.cpp,
   version.mk CR_VERSION, libbt glue, manifest VINTF, SPOOF_SAFETYNET rc — check
   each still needed), rebuild round 3. New SPL expected.
2. **Publish**: new signed OTA → release tag → update `ota/dev.json` (new timestamp,
   new sha256, same filename OR versioned filename).
3. **Updater in-place exercise**: phone Updater → new build found (newer timestamp)
   → download → install → reboot = completes the dev Definition of done OTA item.
4. **GNSS outdoor test** (last subsystem item).
5. **Fork PRs** (user OK required): push d2s + exynos9820-common fixes as feature
   branches → PRs. Also decide fate of init.debug.rc (shrink/remove for prod).
6. **Round-3 flash** via the agent-driven method above.
7. Update docs/ota.md + docs/branding.md (stale lineage.updater.uri claims) — ask
   user first per AGENTS.md rule 3.

## GOTCHAS CARRIED (handover-7, still apply)

- TF-zip self-deletion → rerun `m target-files-package` (~12-22 min).
- sign_target_files_apks ~15-30 min at ~1MB/s — don't kill.
- /tmp host tmpfs: use /srv/android/tmp (TMPDIR).
- dd chunk offsets: explicit decimal.
- Terminal backgrounding: `setsid script.sh < /dev/null &` + wrapper file, no heredocs.
- Human-in-the-loop still needed for: screen taps (SIM PIN), physical replug on USB
  glitch (adbd restart can drop the phone off USB — replug fixes).
