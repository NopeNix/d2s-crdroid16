# Handover #13 — 2026-10-30 ~13:00 UTC

> **SUPERSEDED by handover #14 (2026-10-30 ~19:30 UTC): prod rebuilt with the
> audio fix, FLASHED, booted, verified. DoD gate open (Magisk + banking tests).
> Read handover-14 first.**

> **AUDIO DETOUR CLOSED.** Owner confirmed working audio on the phone after the
> in-place Updater OTA to `nopenix-dev-13.0-20261030`. The blocker from
> handover-12 is cleared. **Next main-line work: RESUME THE PROD LINE** (§3 of
> handover-12, restated and updated in §2 below).

## 1. What the audio detour did (2026-10-30, this session)

1. **Diagnosis** (owner asked "find any clue"): the SLSI primary audio HAL was
   never built. The phone and the build shipped only the generic AOSP
   `audio.primary.default.so`, which opens the ABox PCM and writes frames
   (AudioFlinger showed 12.7M frames written, hw status 0) but performs no
   Samsung routing (mixer_paths.xml / ABox / madera) → silence.
   Root cause: `hardware/samsung_slsi-linaro/exynos/libaudio/audiohal/Android.bp`
   declares its own `soong_namespace {}` — soong never parsed the directory
   (no `libaudio` in `out/soong/.intermediates/hardware/samsung_slsi-linaro/exynos/`).
   **Exact same bug class as the gralloc3 bootloop #6 fix** (MEMORY.md 2026-10-23).
2. **Fix** (fork `NopeNix/android_device_samsung_exynos9820-common`, branch
   `nopenix/dev-fixes-16.0`, commit `1d502b6`, PUSHED):
   - `common.mk`: `PRODUCT_SOONG_NAMESPACES += hardware/samsung_slsi-linaro/exynos/libaudio/audiohal`
   - `BoardConfigCommon.mk`: `$(call soong_config_set,exynos_audio,PREDEFINED_LOW_CAPTURE_DURATION,20)`
     and `$(call soong_config_set,exynos_audio,PROXY_LIBRARY,//device/samsung/exynos9820-common:libaudioproxy)`
   - Matches the LineageOS lineage-23.2 official d2s config (the known-good
     oracle; verified against LineageOS repos line-by-line).
   - `libaudioproxy` (device-tree `audio/proxy/`) was already building; it just
     had no consumer. Now the HAL links it (+ `libaudio-ril`), confirmed in the
     generated ninja before compiling.
3. **Build + sign + publish**:
   - Dev TF build 2h27m; all three audio artifacts in the signed TF
     (`VENDOR/lib64/hw/audio.primary.universal9825.so`, `libaudio-ril.so`,
     `libaudioproxy.so`, `VENDOR/etc/mixer_paths.xml`).
   - Release **`nopenix-dev-13.0-20261030`** (public, byte-verified 1,522,236,417
     bytes): https://github.com/NopeNix/d2s-crdroid16/releases/tag/nopenix-dev-13.0-20261030
   - sha256 `c2ac045f5c471c4fd3fb231155d5ff09cf2adbf2ace4527627f1ba74598aa34b`,
     post-timestamp **1793348962** (from signed META-INF — never file mtime),
     SPL 2026-10-01, SDK 36, buildtype Nightly.
   - `ota/dev.json` updated + hub `main` pushed: `7d26c34` (release+json),
     `d4865b2`/`f1d83bb` (memory). Release note: `releases/nopenix-13.0-20261030-dev.md`.
4. **Owner installed the OTA in place via the Updater and confirmed audio works.**

### Phone state right now

- Runs `nopenix-dev-13.0-20261030` (dev variant, userdebug knobs ON: adb root
  uid 0 works, `/data/adbroot/enabled=1`). In-place OTA install succeeded —
  the Updater chain works with the 20261030 entry.
- Audio, BT, LTE, WiFi, sensors, S-Pen, camera, GNSS: all green.

## 2. NEXT SESSION: prod line resume (task list)

Per `docs/dev-prod.md` (authoritative) + handover-12 §3:

1. **Rebuild prod with the audio fix** — the audio fix lives in the
   exynos9820-common fork, so the staged 2026-10-29 prod OTA
   (`/srv/android/ota61/nopenix-13.0-20261029-d2s.zip`, sha256 67e11cfc…) is
   STALE — **do not publish it**; it contains the broken-audio build.
   Use `/srv/android/run-tf-prod.sh` (prod: NOPENIX_VARIANT=prod, WITH_SU=false,
   user flavor, log `/srv/android/tf-prod.log`) then `/srv/android/run-sign-prod.sh`
   (log `/srv/android/sign-prod.log`). ~2.5-3h build + ~80min sign.
   ⚠️ Pre-verify stage outputs per handover-12 gotcha: check mtimes + variant
   props of BOTH the TF (`out/signed-target-files.zip`, HYPHEN=prod) and the
   signed OTA before trusting; stage-4 of the sign script must read recovery
   from the HYPHEN zip.
2. **Flash dev→prod transition** (owner-in-the-loop): policy = wipe userdata
   entering prod (docs/dev-prod.md "Single-phone data discipline"). Recovery
   sideload or manual flash of the new signed OTA + `Nopenix-recovery-signed.img`
   + vbmeta (existing flash-day recipes, e.g. build-super / flash-day logs).
3. **Magisk Direct Install + Zygisk denylist** for owner's banking apps
   (docs/dev-prod.md "Magisk procedure": non-A/B, re-patch boot after every
   prod OTA reboot).
4. **Subsystem checklist + banking-app tests** on device, results recorded in
   a `releases/` note (audio should pass trivially now).
5. **Publish prod**: GitHub release + append entry to `ota/prod.json`
   (buildtype Release) via `scripts/ota-json.sh` (emits flat format; verify the
   entry and the timestamp = signed META-INF post-timestamp).

## 3. Gotchas that still apply (from MEMORY.md, condensed)

- **SLSI HAL dirs with their own `soong_namespace {}`** (gralloc3, libaudio) are
  invisible to soong unless in `PRODUCT_SOONG_NAMESPACES`. If another SLSI HAL
  silently falls back to a `.default`/`.generic` blob, check this first.
- **Fork remotes**: embedded fine-grained PATs go dead → 403 on push. Fix each
  time: `git remote set-url github git@github.com:NopeNix/<repo>.git`
  (SSH auth as NopeNix works; verified 2026-10-30).
- **1.5 GB release upload**: `nohup setsid gh release upload … --clobber > log &`
  (detached); interactive upload hangs. Verify asset size == local size after.
- **raw.githubusercontent CDN caches ~5 min** after push — Updater may say
  "not newer" briefly right after a dev.json update.
- **Updater JSON timestamp MUST be the signed META-INF post-timestamp**
  (= ro.build.date.utc), never the file mtime.
- **Same-day rebuilds collide on date-derived tags/filenames** — if you rebuild
  the same build line twice in one day, version the name (e.g. `20261030-2`).
- `ro.build.type=user` + `ro.debuggable=1` on the signed dev zip is NORMAL
  (crDroid labels it that way; matches the round-3b baseline — do not "fix" it).
- Old fork branch note: the exynos9820-common `nopenix/dev-fixes-16.0` branch
  was re-created by the 2026-10-30 push (handover-12's "pushed" was defeated by
  the dead PAT — the branch only landed on 2026-10-30). d2s fork branch
  `nopenix/dev-fixes-16.0` (commit `161e3ea`) was already on the remote.

## 4. One-paragraph state for the incoming agent

Dev line is fully DONE and green incl. audio (release nopenix-dev-13.0-20261030
installed in place, owner-confirmed). The staged 2026-10-29 prod OTA is STALE
(preh-audio-fix) — rebuild prod with run-tf-prod.sh + run-sign-prod.sh, verify
stage outputs (hyphen filename + variant props), flash dev→prod with userdata
wipe (owner-in-the-loop), Magisk Direct Install + Zygisk denylist, run the
subsystem + banking checklist, record results in releases/, then publish
ota/prod.json + GitHub release. All repo rules in AGENTS.md apply: no fork
pushes without the user's OK (nopenix/dev-fixes-16.0 in exynos9820-common is
pre-approved), docs edits propose-first, MEMORY.md append-only.
