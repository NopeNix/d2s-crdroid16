# Flash-Day Handover #11 — 2026-10-28 ~22:25 UTC

> **SUPERSEDED by handover #12 (2026-10-29): audio broken on dev → detour;
> prod flash/publish ON HOLD. Read handover-12 first.**

> Supersedes handover #10. **DEV LINE DEFINITION OF DONE: MET.**
> The dev line is COMPLETE. Next phase: prod line (docs/dev-prod.md).

## TL;DR — FINAL DEV STATE

- Phone: round-3b build installed **in place via the crDroid Updater app**
  (owner-driven, end-to-end: find -> download -> install -> reboot).
  Proof: Updater DB `status=2`, `install_old_timestamp=1793135136`,
  bootreason `reboot,ota`. Build timestamp 1793200269 (2026-10-28 ~15:11 UTC).
- SPL **2026-10-01**. All debug knobs verified after the in-place update:
  adb root = uid 0, ro.secure=0, ro.debuggable=1, ro.adb.secure=0,
  /data/adbroot/enabled=1, /cache clean (bootlog cap works).
- Subsystems ALL GREEN incl. **GNSS outdoor (owner-confirmed 2026-10-28)**.
- Release `nopenix-dev-13.0-20261028` now carries the round-3b zip
  (same-day clobber; sha256 687f1faf..., size 1521914209).

## SESSION-10 CHAIN SUMMARY (what happened today)

1. Round 3 (ASB catch-up) was found already built+flashed by an undocumented
   session; this session verified the device and PUBLISHED round 3
   (release + ota/dev.json + release notes).
2. User chose option A for the Updater exercise: no-op rebuild for a fresh
   timestamp. Full auto-pipeline: run-tf61.sh (build) -> watch-tf-sign.sh
   (auto-sign) -> pipeline-r3b.sh (auto-publish: release, zip upload,
   dev.json push, release publish). Build 5h32m, sign ~30 min, upload ~6 min.
3. Owner ran the Updater in-place update. SUCCESS. Dev DoD met.

## GOTCHAS ADDED (see MEMORY.md for full detail)

- **OTA JSON timestamp MUST be post-timestamp from signed META-INF metadata**
  (= ro.build.date.utc). pipeline-r3b.sh originally used zip file mtime ->
  mismatch (1793221972 vs true 1793200269). Fixed in script + dev.json.
- **Same-day rebuilds collide on date-derived release tags/filenames**;
  --clobber silently replaces the asset. Always verify upload byte-accuracy
  (tail range compare) after a clobber. Future: versioned filenames (20261028-2)
  or hour-in-tag for same-day rebuilds.
- Updater DB row status=2 = installed; prefs install_old_timestamp /
  install_again are the authoritative in-place-exercise proof.

## NEXT: PROD LINE (start per docs/dev-prod.md)

Prod = hardened daily driver WITH Magisk (Zygisk denylist for banking),
SELinux enforcing, owner-encrypted, latest ASB. Task list:

1. Prod build variant: separate nopenix.mk OTA URI switch (prod.json channel),
   user build (or userdebug hardened? decide), WITH_SU=false, no debug knobs,
   init.debug.rc fate: REMOVE for prod (or shrink to cap-only).
2. Magisk integration plan: patch boot.img post-sign (document the step), Zygisk
   denylist for banking apps.
3. SELinux enforcing check (crDroid default; verify no permissive remnants).
4. Prod release gate (docs/dev-prod.md): subsystem checklist, banking-app test
   results recorded in releases/, prod.json channel, Updater in-place exercise.
5. Optional first: fork PRs for d2s + exynos9820-common fixes (feature branches
   exist: nopenix/dev-fixes-16.0; user OK required).
