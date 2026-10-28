# Flash-Day Handover #10 — 2026-10-28 ~15:50 UTC (READ THIS ONE FIRST)

> **SUPERSEDED by handover #11 (2026-10-28): Updater in-place exercise DONE (owner-driven,
> success), GNSS outdoor confirmed, DEV DoD MET. Read handover-11 first.**

> Supersedes handover #9. Round 3 (ASB catch-up) is BUILT, FLASHED, and PUBLISHED.
> One open decision: how to complete the Updater in-place exercise (see below).

## TL;DR — CURRENT STATE

- **Phone runs round 3 already**: SPL **2026-10-01** (up from 2026-04-01),
  build timestamp 1793135136 (2026-10-27 21:05 UTC), crdroid 13.0,
  `ro.nopenix.variant=dev`, display BP4A.251205.006.
- On-device verification (2026-10-28): boots, `adb root` = uid 0 (su intact),
  ro.secure=0 / ro.debuggable=1, ro.adb.secure=0, /cache clean (2.4 MB —
  bootlog cap works), BT ON, WiFi 11ax connected, LTE IN_SERVICE (Telekom),
  sensors, camera. GNSS outdoor test still pending (needs human).
- **An undocumented session (Oct 27–28 early AM) already did the round-3
  sync/rebuild/sign/chunk-push/sideload**. This session found that out from log
  timestamps, verified the device, and completed the missing publish steps.
- **Round 3 PUBLISHED this session**: GitHub release `nopenix-dev-13.0-20261028`
  (OTA zip + recovery img, zip upload verified byte-accurate via range fetch +
  tail compare), `ota/dev.json` updated to the round-3 entry (flat format,
  release-tagged download URL), release notes in `releases/nopenix-13.0-20261028-dev.md`.
  Live check confirmed raw dev.json serves SPL 2026-10-01.

## UPDATER IN-PLACE EXERCISE — STATUS: CHAIN PROVEN, INSTALL PENDING

On-device Updater was launched and **fetched + parsed the round-3 dev.json
successfully** (log: `UpdatesRepository: Nopenix-dev-13.0-20261028-d2s.zip is not
newer than the current build`). That is expected: the phone IS round 3, so the
timestamp match reports "not newer". The full download→install→reboot cycle has
NOT been done through the Updater app yet (round 3 went in via recovery sideload).

Three options for completing it (DECISION NEEDED FROM USER):

- **A (recommended, safe)**: no-op rebuild (`m target-files-package` ~15 min,
  resign ~20 min) → new build timestamp → publish as a newer release entry →
  Updater finds it → download (~3 h at the observed 145 KB/s host→GitHub, but
  device downloads from GitHub too, likely faster) → install → reboot. Phone
  ends on identical code. Cost: a rebuild + one more release + upload time.
- **B (fast, small risk)**: reflash round 2 (asset still on the round-2 release,
  HTTP 200) via the proven agent-driven method, then let Updater install round 3
  in place. Avoids a rebuild. Risk: it is a Samsung-firmware downgrade flash
  (same payloads as what's already installed — cm.bin etc. identical years of
  SPL? Actually round 2 SPL was 2026-04-01, round 3 is 2026-10-01, so firmware
  payloads differ). Needs explicit user OK.
- **C (defer)**: let the natural round 4 (next ASB cycle) be the first in-place
  Updater install.

## KEY FACTS ADDED THIS SESSION (also in MEMORY.md)

1. **`scripts/ota-json.sh` fixed** (commit 870c591): emits crDroid flat
   `{"response":[...]}` format; then upgraded to read `post-timestamp` /
   `post-security-patch-level` / `post-sdk-level` from the SIGNED
   `META-INF/com/android/metadata` (falls back to zip mtime + prop.default).
   This is more correct: post-timestamp is the value the Updater compares.
2. **Updater on round 3 fetches dev.json fine and correctly reports
   "not newer"** when the installed build IS the newest entry — server/device
   chain verified end-to-end without consuming the exercise.
3. **Round-2 zip layout had no SYSTEM/etc/prop.default** (system payload lives
   in system.new.dat.br) — scripts reading props from the zip must fall back to
   metadata (now fixed).
4. `gh release create` with a 1.5 GB asset **stops responding interactively**
   (tool soft-timeout kills the streaming CLI, asset half-uploads, release stays
   draft). Workaround proven: create release detached (setsid), poll asset list,
   re-run `gh release upload --clobber` detached, `--draft=false` to publish.
   Host→GitHub throughput observed ~145 KB/s steady (3 h for 1.5 GB).
5. Updater app has NO LAUNCHER intent filter (Settings-only entry point) —
   start it via `adb shell am start -n org.lineageos.updater/.UpdatesActivity`.
6. Round-2→round-3 delta context: 98 crDroid/Lineage github projects were
   synced (the run-sync64.sh targeted list), full tree clean.

## NEXT SESSION TASK LIST

1. **USER DECISION**: Updater in-place exercise → option A, B, or C (above).
   If A: rebuild via `/srv/android/build-start.sh` (env exports the dev knobs),
   sign via run-sign61.sh, publish, then drive Updater on device.
2. **GNSS outdoor test** (human + device outside; the only subsystem item left).
3. **Fork PRs** (needs user OK): d2s + exynos9820-common feature branches
   (`nopenix/dev-fixes-16.0`) → PRs into our forks' `16.0`.
4. **Prod line start** (after dev DoD complete): per docs/dev-prod.md —
   decide fate of init.debug.rc (shrink/remove), Magisk plan, hardened knobs.
5. Keep docs current per AGENTS.md rule 3 (propose first).

## GOTCHAS CARRIED (from #9, still apply)

- TF-zip self-deletion → rerun `m target-files-package` (~12-22 min).
- sign_target_files_apks ~15-30 min at ~1MB/s — don't kill.
- /tmp host tmpfs: use /srv/android/tmp (TMPDIR) for big temp files.
- dd chunk offsets: explicit decimal. Terminal backgrounding: `setsid ... < /dev/null &`.
- Human-in-the-loop: SIM PIN after flash, physical replug on USB glitch.
- Long heredocs via terminal tool get corrupted — use file_editor or python files.
