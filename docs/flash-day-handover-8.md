# Flash-Day Handover #8 — 2026-10-26 ~15:30 UTC (READ THIS ONE FIRST)

> Supersedes handover #7. #4 still holds the proven flash recipe mechanics.

## TL;DR — CURRENT STATE

- **v13 (dev line) is ON THE PHONE AND VERIFIED WORKING** (2026-10-26, session #7 wrap-up):
  boots, setup wizard completed, adb works after RSA acceptance, BT **ON since boot
  0 crashes** (libbt-vendor glue fix WORKS), LTE Telekom IN_SERVICE (voice+data+SMS),
  WiFi, speaker audio, full sensor list, S-Pen (`sec_e-pen`), camera (5 devices
  enumerated). GNSS service up but outdoor fix not tested. Patch level 2026-04-01
  (parity with official v12.9). Build date Oct 25.
- v13's "adb does not connect" scare from handover-7 was a non-issue: the phone was
  just sitting in the unauthorized state hidden behind the setup wizard; user accepted
  the RSA prompt and all was well.
- On-device deviations (known, low priority): `ro.secure=1` (so `adb root` gives
  uid 2000 — the gen_build_prop.py fix exists in tree but is gated on
  `BuildBrokenDupSysprop` which was NOT set in v13's build config), no
  `ro.lineage.build.version`, display version still "v12.12-20261025" (crDroid
  branding, not Nopenix).

## THE PLAN (decided 2026-10-26 — read docs/dev-prod.md, it is authoritative)

- **Two build lines**: dev (userdebug + debug knobs, the playground, current main
  goal) and prod (hardened + Magisk root, daily driver, NOT started yet).
- **Current main goal: fully working DEV build. Prod comes after, in later sessions.**
- Dev Definition of done is in `docs/dev-prod.md`: boots + debug conveniences +
  subsystem checklist + **OTA flow exercised on the dev channel**.
- OTA: two channels — `ota/dev.json` (type nightly) and `ota/prod.json` (type
  release), device baked with the matching `lineage.updater.uri`.

## NEXT SESSION TASK LIST (in order — this is the work)

1. **Write a handover-9 or update this file** as you go; log every gotcha in
   MEMORY.md immediately.
2. **Branding + variant props** (device tree, `NopeNix/android_device_samsung_d2s` fork,
   currently LOCAL-ONLY changes in `/srv/android/nopenix-d2s` — see item 6 before pushing):
   - Set `ro.nopenix.variant=dev` for dev builds (nopenix.mk or device.mk).
   - Fix `ro.lineage.build.version` so the Updater version-match works (v13 has none —
     check why: crDroid version props come from vendor config; compare v13's
     system build.prop against the official v12.9's).
   - Display version: replace "v12.12-20261025" with a Nopenix version string
     (`ro.crdroid.display.version` or equivalent — identify exact prop).
   - Zip naming `nopenix-dev-<...>` (identify the crDroid filename generator var,
     see docs/branding.md open items).
3. **Build the dev build with the debug knobs ON** (the real dev-line definition):
   - `BUILD_BROKEN_DUP_SYSPROP=true` in the build env (this makes
     gen_build_prop.py skip `ro.secure=1` → `adb root` → uid 0; the local patch in
     `/srv/android/nopenix-d2s/build/soong/scripts/gen_build_prop.py:350-357` checks
     `config["BuildBrokenDupSysprop"]`, fed from `BUILD_BROKEN_DUP_SYSPROP` via
     `build/make/core/soong_config.mk:303`).
   - Verify the flag is actually in the product config JSON before trusting a
     17-min+ build: `grep BuildBrokenDupSysprop out/soong/soong.config` or the
     productVariables dump (`out/soong/dump-soong-products.txt` or
     `out/.soong_config` equivalents — find it; if unsure, check after build start).
   - Rebuild + sign per the flash-day procedure (gotchas in handover-7 "HOW v13 GOT
     BUILT" — all still apply: TF-zip self-deletion, SELINUX_IGNORE_NEVERALLOWS,
     /srv/android/tmp TMPDIR, tf-dir unzip, PATH for host bins, super image build).
4. **Flash dev build** (handover-4 recipe + handover-7 dd-chunk decimal-offsets
   gotcha; read-back md5 verify everything).
5. **Verify dev line**: adb root → uid 0; `getprop ro.nopenix.variant` = dev;
   subsystem checklist again (BT/LTE/WiFi/audio/sensors/S-Pen/camera/GNSS).
6. **Set up the dev OTA channel**:
   - Create `ota/dev.json` in this hub repo (format per docs/ota.md; type `nightly`).
   - Commit + push to hub main (hub doc commits only with user OK per AGENTS.md
     rule 6 — ask).
   - Set `lineage.updater.uri` to the raw dev.json URL in the dev build's props
     (device tree overlay or `setprop` for testing).
   - Exercise: Updater → check → download → install a dev build in place. This is
     the dev Definition of done's OTA item. If the in-place OTA path has bugs,
     debug on dev — that is exactly what the dev line is for.
7. **Device-tree fixes → push to NopeNix forks** (AGENTS.md rule 6: feature branches
   + PRs for non-trivial; ask user OK first). The LOCAL-ONLY fixes in
   `/srv/android/nopenix-d2s` (device/common trees) that are NOT yet pushed:
   - SPOOF_SAFETYNET init fix (v12 fix, overrides ro.debuggable at runtime)
   - manifest.xml VINTF fix (removed IKeyDisabler/IAdaptiveBacklight — system_server hang)
   - Bluetooth glue (bluetooth/Android.bp + soong_config_set + libbt-vendor:64 in
     exynos9820-common common.mk) — v13 proved this works
   - PLUS whatever branding/variant changes from item 2.
   - The gen_build_prop.py ro.secure patch is in build/ (crDroid source, not our fork)
     — carry it as a documented local patch (add a patch file in this hub repo,
     e.g. patches/ or docs/) so a fresh sync does not silently lose it.
8. **GNSS outdoor test** on the dev build (only checklist item not yet verified).

## AFTER DEV IS DONE (NOT this round)

Prod line per docs/dev-prod.md: user-variant hardened build, Magisk + Zygisk
denylist, SELinux enforcing, prod.json channel, GitHub releases. Also then:
ASB catch-up (repo sync crDroid 16.0 upstream, rebuild both lines) — the
current 2026-04-01 patch level is only acceptable until the first prod build;
the monthly cadence (ROADMAP Phase 3) starts once prod exists.

## KEY FILE / STATE POINTERS

- Phone: Samsung SM-N975F, serial RF8MC0SAXCJ, USB 18d1:4ee7 on bus 9. Currently
  running v13 (dev-ish but without debug knobs), authorized adb, WiFi "NopeNix Network",
  Telekom SIM loaded.
- Artifacts: `/srv/android/nopenix-d2s/out/` (signed-target_files.zip, tf-dir,
  Nopenix-signed-ota.zip) and `/srv/android/flash-day/` (+ v13/IMAGES). /srv has
  ~59G free; / has ~11G free (out/ cleanup candidates listed in handover-7 item 6).
- Build source: `/srv/android/nopenix-d2s` (repo tree, crDroid 16.0 base + local
  manifest + local patches).
- Signing: `/srv/android/sign-target.sh` (stages 1-3), certs in `~/.android-certs/`.
- Keys/procedure gotchas: handover-7 "HOW v13 GOT BUILT" + "FLASH NOTES" — still
  the authoritative mechanical reference.

## SESSION-BRIDGING GOTCHAS (tooling, learned the hard way)

- Backgrounding in the terminal tool: only `setsid script.sh < /dev/null &` with a
  wrapper FILE (write via file_editor, never heredoc — heredocs corrupt). Poll with
  sleep+pgrep+tail.
- Long builds: check `m target-files-package` re-deletes its TF output (handover-7).
- sign_target_files_apks ~75-90 min at ~1MB/s — do NOT kill thinking it hung.
- file_editor `create` cannot overwrite existing files; use str_replace.
- Ask the human for every on-device manual step (screen taps, recovery boot,
  RSA accept) — the human-in-the-loop is part of the dev-line design, not a failure.
