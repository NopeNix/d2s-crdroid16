# Flash-Day Status — Handoff Note (2026-10-20, end of session)

> **SUPERSEDED** by docs/flash-day-handover-3.md (2026-10-22) — read that one first.
> This file is kept for historical context only. It documents the ORIGINAL flash-day
> attempt (Oct 20) with the OLD kernel (4.14.355 crdroidandroid fork, pre-SPL-fix,
> md5 82f4477c OTA). Most of its content has been superseded by subsequent sessions.

## Device
- Samsung Galaxy Note10+ SM-N975F (d2s, Exynos 9825), user's PERSONAL daily driver.
- Serial: RF8MC0SAXCJ
- Was on: official crDroid 12.9 (v12.9, Android 16, 2026-04-26 build)
- User made a full TWRP backup BEFORE anything (boot/system/vendor/data at minimum).
  User confirmed backup exists on their side. This is the revert path.

## What was built and signed (all on build host /srv/android/nopenix-d2s)
- out/Nopenix-signed-ota.zip — 1.52 GB, md5 82f4477ce628df6e553544e48c868270
- out/Nopenix-recovery-signed.img — 67 MB, md5 a9be748e6dedf7e7822d0e4ffb9b176c
- Both signed with ~/.android-certs (CN=Nopenix Release, sha256 fp
  12:1C:87:C0:2E:7E:E5:2F:A5:60:5D:99:63:06:5D:B6:E4:6A:57:B0:7E:0C:3A:A8:5E:AE:1A:6B:7F:53:26:AA)
- Copies staged in /srv/android/flash-day/ (+ pit/d2s.pit partition table backup)
- The OTA zip contains full system/vendor/product .new.dat.br images — it IS a
  complete base image, no external firmware download needed.

## What happened on flash day (chronological)
1. User flashed our Nopenix-recovery-signed.img via heimdall → SUCCESS.
   Recovery booted fine (Lineage recovery with our white Nopenix logo).
2. User sideloaded Nopenix-signed-ota.zip via adb sideload → SUCCESS (install completed).
3. Phone bootlooped on first boot.

## Root cause (CONFIRMED via /proc/last_kmsg pulled over adb from TWRP)
- init shutdown reason: `reboot,netbpfload-missing`
- netbpfload binary is NOT in /system/bin — it lives inside the
  com.android.tethering APEX (/apex/com.android.tethering/bin/netbpfload).
- The tethering capex IS in the build (out/tf-dir/SYSTEM/apex/com.android.tethering.capex).
- BUT apexd failed to decompress ALL capex files into /data/apex/decompressed/ —
  log spam: "Failed to open decompression destination /data/apex/decompressed/...:
  No such file or directory"
- Reason: /data still contained crDroid 12.9's FBE-encrypted userdata. Our 16.0
  build's vendor/keystore stack couldn't decrypt/mount it properly, /data/apex
  structure was never created, netbpfload never appeared → init's
  reboot_on_failure triggered → clean reboot loop (~11s per cycle).
- keystore2 also received SIGABRT early in boot (consistent with keymaster/FBE
  mismatch on old encrypted data).

## Fix applied (successful, verified over adb from TWRP)
- `adb shell twrp format data` → "Formatting Data using mkfs.f2fs... Done."
- This wipes ALL userdata (user was warned; they have the TWRP backup).
- Session ended while user was rebooting recovery to remount /data — the phone
  physically dropped and USB disconnected mid-step. Data IS formatted (the twrp
  format data command completed successfully before disconnection).

## WHAT THE NEXT SESSION MUST DO (in order)
1. `adb devices` — phone should show as `recovery` (TWRP or our Lineage recovery).
   If not visible: ask user to replug cable / re-enter recovery.
2. If in TWRP: optionally re-verify /data is empty:
   `adb shell ls /data/apex 2>/dev/null; adb shell ls /data | head`
   /data should be essentially empty or freshly formatted f2fs.
   If /data still has old content (e.g. TWRP restored something), re-run:
   `adb shell twrp format data`
3. Put phone into sideload mode:
   - TWRP: `adb shell twrp sideload` (or Advanced > ADB Sideload in GUI)
   - Our Lineage recovery: menu "Apply update" > "Apply from ADB"
4. `adb sideload /srv/android/flash-day/Nopenix-signed-ota.zip`
   (takes several minutes; watch for success/failure percentage)
5. Reboot: `adb reboot` or recovery menu Reboot > System.
6. First boot takes 5–15 min (APEX decompression, dexopt). Be patient.
   Watch: if bootloop returns, pull /proc/last_kmsg again over TWRP and check
   for a DIFFERENT failure reason (netbpfload should now work with clean /data).
7. After successful boot: verify Settings > About shows Nopenix branding, check
   the Updater app points to our OTA JSON, test basics (WiFi, LTE, camera, fingerprint).

## If the fix DOESN'T work (bootloop persists after format data + sideload)
- Pull /proc/last_kmsg + /sys/fs/pstore/* via TWRP adb and analyze.
- Check for new init shutdown reasons (grep 'shutdown_command' and
  'reboot_on_failure').
- Possible additional issues: SELinux neverallow regressions from our
  SELINUX_IGNORE_NEVERALLOWS=true build (policy may be invalid at runtime),
  or a missing vendor HAL.
- Ultimate fallback: user restores their TWRP backup of crDroid 12.9
  (boot+system+vendor+data) → back to working daily driver, no harm done.
- Second fallback: Odin-flash full stock Samsung firmware (user downloads on
  their PC from samfw.com — samfw is fine from residential IPs, only this
  datacenter VM is blocked).

## Environment state on build host
- Source tree: /srv/android/nopenix-d2s (fully synced, ~229 GB)
- Out dir: out/target/product/d2s (last successful build + signing artifacts)
- Signing keys: /home/user/.android-certs/ — CRITICAL, back these up to the
  user's vault! Losing them = every future OTA needs manual sideload.
- Flash tools: adb, fastboot, heimdall (apt), udev rule 51-android.rules
- USB passthrough works: phone appears to guest VM when user plugs it in.
  Sometimes needs replug to re-enumerate after mode changes.
- nanosamfw (FUS client) at /tmp/nanosamfw — use /usr/bin/python3 (not the
  uv venv python). Stock firmware downloads blocked from this IP anyway.

## Build fixes that are LOCAL-ONLY (should become fork PRs eventually)
All documented in MEMORY.md 2026-10-13/14 entries. Summary:
- exynos9820-common: soong_config bool fix, module renames (AIDL HALs),
  audio.primary.universal9825, sepolicy dedup vs slsi, manifest.xml AIDL HALs
- hw/samsung: namespace imports for vendor blob visibility
- vendor Android.bps: check_elf_files:false on prebuilts
- vendor/lineage: protobuf_vendorcompat un-excluded, EPE allowlist,
  clean_headers.sh sched header removal
- .repo/repo: manifest_xml.py phantom-project tolerance
Do NOT lose these on a re-sync — they're in the working tree, not committed
to the forks yet.

## Key files
- Hub repo: /home/user/d2s-crdroid16 (this file is docs/flash-day-status.md)
- Build host scripts: /srv/android/build-start.sh, /srv/android/sign-target.sh,
  /srv/android/slim-project.sh, /srv/android/slim-all.sh
- OTA JSON template: hub repo scripts/ota-json.sh
- Release process: hub repo docs/release.md
