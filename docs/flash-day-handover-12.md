# Handover #12 — 2026-10-29 ~20:15 UTC (READ THIS ONE FIRST)

> **DETOUR IN PROGRESS**: owner found **audio is not working** on the dev build
> currently on the phone (round-3b, 2026-10-28). A separate agent is being
> dispatched to fix audio. **Audio is now a release blocker for BOTH lines** —
> the prod DoD subsystem checklist requires audio green, so the prod flash/
> publish is ON HOLD until the detour resolves.
>
> ⚠️ Do NOT start the prod flash while audio is broken.

## 1. Project in 60 seconds (for the incoming audio agent)

- Device: Samsung Galaxy Note10+ SM-N975F, codename **d2s**, Exynos 9825.
- ROM: crDroid 16.0 (Android 16, Lineage 23.2 base), forked and continued as
  **Nopenix**, brand `ro.nopenix.variant=dev|prod`. Security-patch continuation
  only — no new features.
- This repo is the HUB (docs/manifests/scripts). ROM source lives in forked
  repos under the `NopeNix` GitHub org; the local full Android tree is at
  **`/srv/android/nopenix-d2s`** (hub-and-forks model, see AGENTS.md).
- Read order: `AGENTS.md` → `MEMORY.md` (top entries first) → relevant docs/.
- Two build lines: dev (userdebug, debug knobs, COMPLETE) and prod (user
  flavor + Magisk by design, IN PROGRESS — paused for this detour).

## 2. What happened this session (prod session #1, 2026-10-29)

All of this is DONE and PUSHED (nothing uncommitted):

1. **User flavor decided for prod** (owner decision).
2. **Device fork `NopeNix/android_device_samsung_d2s`, branch
   `nopenix/dev-fixes-16.0`** (pushed):
   - commit `161e3ea`: variant gates — `init.debug.rc` copy, `ro.debuggable=1`,
     and `BUILD_BROKEN_DUP_SYSPROP` are now dev-only via
     `ifneq ($(NOPENIX_VARIANT),prod)` in `device.mk` + `BoardConfig.mk`;
     `nopenix.mk` documents dev/prod semantics.
   - (earlier commit `7e6128c` already had branding + dev debug knobs +
     Updater OTA URL overlay.)
3. **Build wrappers** (host-local, NOT in git): `/srv/android/run-tf-prod.sh`
   (prod target-files build: `NOPENIX_VARIANT=prod`, `WITH_SU=false`, user
   flavor, logs `/srv/android/tf-prod.log`) and `/srv/android/run-sign-prod.sh`
   (sign + ota + recovery, logs `/srv/android/sign-prod.log`).
4. **Hub `main`** (pushed): `45bc454` seeds empty `ota/prod.json`
   (`{"response": []}`); `aa4e5fa` adds build-guide §5a (prod deltas),
   dev-prod "Magisk procedure" section (non-A/B: after every prod OTA reboot,
   Magisk app → Direct Install re-patch; APK + denylist survive OTA in /data),
   and removes the stale ota.md note about ota-json.sh nested format.
5. **First prod build COMPLETE** (2h41m build + ~80min sign):
   - Signed TF: `/srv/android/nopenix-d2s/out/signed-target-files.zip`
     (HYPHEN — verified prod: user flavor, ro.secure=1, ro.debuggable=0,
     ro.adb.secure=1, ro.nopenix.variant=prod, init.debug.rc ABSENT).
   - Prod OTA zip: staged as
     **`/srv/android/ota61/nopenix-13.0-20261029-d2s.zip`** (1,514,295,255
     bytes, sha256 `67e11cfcec7c7020b3a38c968f0a2727e0df527a333788771d86b7bba04dcc1c`,
     post-timestamp 1793268774, SPL 2026-10-01, SDK 36).
   - Signed recovery.img: `/srv/android/nopenix-d2s/out/Nopenix-recovery-signed.img`
     (re-extracted from the prod TF; see gotcha below).
6. **ota-json.sh prod entry generated** (buildtype Release) — ready to paste
   into `ota/prod.json` at publish time (NOT done — DoD gate).

### Gotchas hit this session (also in MEMORY.md, newest-first)

- **Filename typo in sign script**: stage-4 extracted recovery.img from
  `out/signed-target_files.zip` (UNDERSCORE = STALE DEV zip from Oct 28)
  instead of `out/signed-target-files.zip` (HYPHEN = fresh prod). The OTA zip
  itself (stage 3) was correct (hyphen input). Lesson: verify mtimes + variant
  props of BOTH the TF and signed output before trusting stage outputs.
- **Fork remote auth**: the fork remote had an embedded dead fine-grained PAT
  → 403 on push. Hub pushes work via SSH. Fix applied: switch fork remotes to
  `git@github.com:NopeNix/<repo>.git`.
- Build sandboxing nsjail warnings in tf-prod.log are harmless (also present
  in dev builds).

## 3. Prod line state (PAUSED here)

- Built + signed + verified artifacts exist (see §2.5). **NOT published**:
  prod DoD gate (docs/dev-prod.md) requires subsystem checklist (incl. AUDIO),
  banking-app tests, Magisk denylist setup, on-device verification — all
  owner-in-the-loop.
- Next steps once audio is fixed AND phone returns:
  1. Rebuild prod if the audio fix changes device/kernel trees (ask; a
     rebuild is another ~3h + ~80min sign).
  2. Flash transition dev→prod (policy: wipe userdata when returning to
     prod; owner-in-the-loop for recovery/adb steps).
  3. Magisk Direct Install + Zygisk denylist (docs/dev-prod.md "Magisk
     procedure").
  4. Subsystem checklist + banking tests → record in releases/.
  5. GitHub release + append entry to `ota/prod.json` (buildtype Release).

## 4. Context for the audio detour

- Phone currently runs dev round-3b (`nopenix-dev-13.0-20261028` release,
  SPL 2026-10-01, build ts 1793200269, variant=dev, userdebug, adb root works:
  `adb root` → uid 0; `/data/adbroot/enabled=1` present).
- Audio device config lives in the forks:
  `NopeNix/android_device_samsung_d2s` (16.0) and
  `NopeNix/android_device_samsung_exynos9820-common` (16.0) — checkout at
  `/srv/android/nopenix-d2s/device/samsung/{d2s,exynos9820-common}`.
  The d2s fork branch locally is `nopenix/dev-fixes-16.0` (has our commits);
  the common tree branch state should be checked there.
- Known audio-relevant bits in d2s device tree:
  `device.mk` copies `configs/audio/mixer_paths.xml` to vendor
  (`$(TARGET_COPY_OUT_VENDOR)/etc/mixer_paths.xml`); exynos9820-common
  `common.mk` carries the audio HAL config (check audio policy, mixer paths,
  audio HAL blobs in `NopeNix/proprietary_vendor_samsung_exynos9820-common`
  branch 13.0 and d2s blobs 14.0, strategy per docs/blob-strategy.md).
- The blob strategy (docs/blob-strategy.md): TheMuppets lineage-23.2 blobs
  are the default source — if audio blobs (audio HAL, audio policy config)
  came from an older crDroid extraction, mismatched HAL/props is a prime
  suspect for audio breakage. Check which audio HAL binaries/configs are
  actually on the phone (`/vendor/etc/audio/`, `/vendor/lib64/hw/audio*`,
  `dumpsys audio`, `logcat` audio_server/audio HAL output) before touching
  configs.
- IMPORTANT: whatever the fix, it must go into the FORKS (feature branch +
  push per repo rules — user OK for direct pushes was granted for
  `nopenix/dev-fixes-16.0`; ask before pushing elsewhere), then rebuild.

## 5. One-paragraph state for the returning owner

Prod line is built/signed/staged but deliberately unpublished; the phone is
still on dev round-3b. Audio is broken on dev → detour agent fixes it (likely
device-tree/blob territory on the d2s or exynos9820-common fork). Once audio
is green on dev: rebuild prod with the fix (variant gates are already in),
flash dev→prod (wipe userdata), Magisk Direct Install, run the subsystem +
banking checklist, then publish prod.json + GitHub release.
