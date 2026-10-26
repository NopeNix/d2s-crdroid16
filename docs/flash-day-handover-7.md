# Flash-Day Handover #7 — 2026-10-26 ~09:10 UTC (READ THIS ONE FIRST)

> Supersedes handover #6. #4 still holds the proven flash recipe mechanics; this file
> covers what happened since, where v13 stands, and what the next session must do.

## TL;DR — CURRENT STATE

- **v13 BUILT, SIGNED, AND FULLY FLASHED on the phone** (all partitions dd'd + md5-verified
  read-back). v13 = v12 + Bluetooth glue (libbt-vendor.so / vnd_exynos9820.txt) +
  `ro.secure=0` via gen_build_prop.py fix (adbd root). Build finished 19:58 UTC Oct 25.
- **BUT: after reboot into system (08:25 UTC Oct 26), adb does NOT connect.** Phone
  enumerates on USB as `18d1:4ee7` serial RF8MC0SAXCJ (adbd's ffs function IS advertised,
  Vendor Specific class 255), but the ADB interface has **no kernel driver bound** and
  `adb devices` stays empty 25+ min. USB unbind/rebind from host did NOT help.
  This smells like the handover-4 `FUNCTIONFS_BIND` timeout pattern again — meaning
  system-side adbd is stuck early (system_server hang still not fixed?) — OR the phone
  is stuck on some screen. **Nobody checked the phone screen yet.**
- Recovery adb (before reboot) worked fine the whole session. `adb root` works IN
  RECOVERY (uid 0, context su).

## WHERE THE ARTIFACTS ARE

- `/srv/android/nopenix-d2s/out/Nopenix-signed-ota.zip` — md5 `cc468d54ff411802a314c199a3592353`
- `/srv/android/nopenix-d2s/out/Nopenix-recovery-signed.img` — md5 `5d79f9334bbaf84206d33b20f435f02b`
- `/srv/android/nopenix-d2s/out/signed-target_files.zip` — v13 signed TF (3.35GB), still on disk
- `/srv/android/flash-day/` — copies of OTA + recovery, plus `v13/IMAGES/{boot,dtbo,vbmeta}.img`
- On-device md5s verified after flash (DO NOT re-verify unless something booted wrong):
  - super (sda25, 6.5GB raw): `092e040b4cc94cd43e8df6630dd83bed` ✅
  - boot: `4eb479b8926a0720699147407fa650fc` ✅
  - dtbo: `3f69ac8905fc003cbb9f35715e863cdb` ✅
  - vbmeta first 8KB: `2b078d38f3a42aa9144dfd00c91c95cc` ✅ (partition is bigger than the
    8KB image — verify first 8KB only, full-partition md5 will NOT match, that's normal)
  - recovery: `5d79f9334bbaf84206d33b20f435f02b` ✅

## HOW v13 GOT BUILT (the detours — don't repeat them)

1. **`m target-files-package` DELETES its own output.** The final packaging step does
   `rm -rf out/target/product/d2s/obj/PACKAGING/target_files_intermediates` after moving
   lineage_d2s-ota.zip away. So after a full build, the TF zip is GONE and
   `sign-target.sh` (which globs for it) fails. Fix: re-run
   `m target-files-package` — it regenerates the TF zip in ~17 min (cached).
2. **`m target-files-package` fails on sepolicy neverallow** (system_server sys_module
   from exynos9820-common vendor sepolicy). Pass `SELINUX_IGNORE_NEVERALLOWS=true` —
   that's what the full build env used (sign-target.sh sets it).
3. **`sign-target.sh` is slow (~75-90 min for sign_target_files_apks)** at ~0.7-1 MB/s
   effective. Do NOT kill it early thinking it hung (same byte size written at two
   different timeouts fooled us — it was just slow). **Terminal-tool backgrounding
   (`nohup ... &`) is unreliable in this sandbox — jobs get reaped.** The reliable
   pattern: write a wrapper script with file_editor (NOT heredoc — heredocs get
   corrupted through the terminal tool), run it with
   `setsid /path/to/script.sh < /dev/null &`, then poll with sleep+pgrep+tail.
4. **`/tmp` is a 5.3GB tmpfs** — ota_from_target_files FinalizeMetadata ENOSPCs there.
   **AND `tempfile` silently ignores TMPDIR if the dir doesn't exist!** Create
   `mkdir -p /srv/android/tmp` FIRST, export TMPDIR, then run. (We lost ~2 runs to this.)
5. **`PartitionMapFromTargetFiles` is LOCALLY PATCHED** in build/make/tools/releasetools/
   common.py to fall back to `/srv/android/nopenix-d2s/out/tf-dir` for zip inputs
   (upstream ZipFile path crashes). If `out/tf-dir` was deleted (we did), stage-3 fails
   with `KeyError: 'system'`. Fix: `unzip -qo out/signed-target_files.zip -d out/tf-dir`.
6. **ota_from_target_files also needs host bins on PATH**: `unpack_bootimg` etc. →
   `export PATH=$PWD/out/host/linux-x86/bin:$PATH`.
   See working wrapper: `/srv/android/sign-stage3.sh`, `/srv/android/build-super13.sh`.
7. **super image**: `build_super_image.py` needs `toybox` — PATH must include
   `prebuilts/build-tools/linux-x86/bin` too. Then `simg2img super13.img super13-raw.img`,
   md5, `split -b 400M -d`.

## FLASH NOTES (things #4's recipe didn't mention)

- `adb root` needed in recovery first (default adbd is uid 2000 shell there in v13
  recovery; `adb root` switches to uid 0 — works, confirmed).
- Mount recipe that worked: plain `adb shell 'mount -t f2fs /dev/block/by-name/userdata /data'`
  AS ROOT (with uid 2000 it fails with "not in fstab" — that error is a red herring,
  it's a permissions thing).
- **On-device dd loop gotcha: `sed 's/superchunk-//'` + `$((0x$i))`-style math — we
  accidentally used hex interpretation, chunks 10-15 went to wrong offsets (2.4GB gap).
  The first full-partition md5 caught it. Always read-back-verify; write decimal
  offsets explicitly.**
- Whole super read-back: `adb shell 'md5sum /dev/block/by-name/system'` (by-name/system
  = sda25 = super). ~2-3 min for 6.5GB.
- USB pushes ran at 80-120 MB/s this session (passthrough was healthy — the ~1MB/s
  collapse seen in handover-4 did NOT recur; only the recovery.img push (67MB) was slow
  at 0.5 MB/s. Push smaller files first or retry if a push crawls).
- After flash: `rm -f /data/superchunk-* /data/*.img; sync` then `adb reboot`.

## NEXT SESSION TODO (in order)

1. **Establish what state the phone is in.** Screen check by user first (setup wizard?
   boot loop? RSA prompt?). Then `adb devices` / `lsusb`. If adb still absent with
   4ee7 present: replug, reboot phone, try again. Note: v13 should have `ro.secure=0`
   in system build.prop (gen_build_prop.py fix) — verify once adb works:
   `adb shell getprop ro.secure` and `adb root` → `adb shell id` should be uid 0.
2. **If boot hangs again (system_server)**: capture last_kmsg + tombstones per the
   established loop (handover-4 "remaining blocker" section). The hang suspects are
   unchanged — but NOTE the VINTF HAL fix (IKeyDisabler/IAdaptiveBacklight removed from
   manifest.xml) is IN v13, so if it hangs the same way, the touch-HAL theory is dead
   and system_server hang needs a fresh diagnosis (tombstones via adb root, which v13
   enables).
3. **When system boots + adb works**: finish handover-5 checklist (BT enable test —
   THIS is the v13 headline fix; audio, GNSS, camera, S-Pen), then setup wizard.
4. **Push device-tree fixes to NopeNix forks** (AGENTS.md rule 6 — only after v13
   confirmed on device): SPOOF_SAFETYNET init fix, manifest.xml VINTF fix, bluetooth
   glue (Android.bp + soong_config_set + libbt-vendor:64 in common.mk).
   The gen_build_prop.py ro.secure change is in build/ (crDroid source, not our fork) —
   decide local-patch-carry vs. document-only.
5. **OTA packaging + first release** (handover-5 items 4-5): OTA JSON via ota-json.sh,
   GitHub release, releases/ + ROADMAP.md updates.
6. Cleanup candidates when disk needed: out/signed-target_files.zip (3.3GB),
   out/tf-dir (6.2GB), /srv/android/flash-day/parts/super13*.img (9.5GB). /srv is a
   separate 492GB disk (59G free at handoff); / (out/) is 96G with ~11G free — the
   /tmp ENOSPC was tmpfs, NOT /srv.

## TOOLING LESSONS THIS SESSION (general)

- Terminal tool: multiple-think-calls-in-one-message + terminal = the terminal command
  can get silently DROPPED (tool validation error eats it). One tool per message when
  driving long shell pipelines.
- file_editor `create` cannot overwrite; use str_replace to edit scripts.
- `setsid script.sh < /dev/null &` + wrapper file is the only reliable backgrounding.
- sysfs USB reset via sudo: `echo 9-1 > /sys/bus/usb/drivers/usb/{unbind,bind}` —
  works (sudo available via $LOCAL_ROOT_PW) but did NOT revive this adbd.
