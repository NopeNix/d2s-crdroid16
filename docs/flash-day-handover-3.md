# Flash-Day Handover #3 — 2026-10-22 ~07:00 UTC (READ THIS ONE, not #2)

> This is the freshest handover. handover-2.md and flash-day-status.md are older.
> MEMORY.md top entries cover the same ground.

## CURRENT STATE — what actually happened this session

### Artifacts (all built, signed, verified, staged in /srv/android/flash-day/)
- **Nopenix-signed-ota.zip** — md5 f2813d9b8c6ffc6e18984f5617ea0699, 1520015484 bytes.
  Contains boot kernel **4.14.356-openela-rc1-g693d1da93597** (the LineageOS kernel that
  official crDroid 12.9 shipped — this fixes the netbpfload/bootloop #3 bpfloader failure).
- **Nopenix-recovery-signed.img** — md5 00e4b9c73424c7ceabdb7bae06efed7a, 67633152 bytes.
  Same new kernel, AVB-signed (SHA256_RSA4096, rollback index 1), verified with avbtool.
- **vbmeta-signed.img** — md5 8192 bytes, extracted from the OTA zip. AVB flags=3
  (verification disabled), rollback index 1775001600 = 2026-04-01 (matches ROM SPL fix).
- PIT backup: pit/d2s.pit (KEEP — partition table backup).
- last_kmsg_round2.txt — kernel log from bootloop #3 (netbpfload/schedcls failure).

### Build state
- Kernel tree /srv/android/nopenix-d2s/kernel/samsung/exynos9820 is on branch
  **official-v129** @ 693d1da93597 (fetched from LineageOS repo; fast-forward descendant
  of our old pin, 1937 commits ahead). This is the fix for bootloop #3 — the old
  crdroidandroid fork kernel (4.14.355) lacked the UAPI __sk_buff gso_segs/gso_size
  fields that the 25Q4 Tethering APEX's schedcls programs need.
- Full rebuild completed successfully (33 min): out/Nopenix-signed-ota.zip +
  out/Nopenix-recovery-signed.img (both new md5s above), signed with Nopenix keys
  (CN=Nopenix Release, fp 12:1C:87:C0...26:AA).
- cbd (cpboot-daemon, modem fix) was built and is installed to vendor/bin/cbd
  (out/target/product/d2s/vendor/bin/cbd). Verified in installs-lineage_d2s.mk.
- SPL textproto: vendor/lineage/release/flag_values/bp4a/RELEASE_PLATFORM_SECURITY_PATCH.textproto
  = 2026-04-01 (verified). vbmeta rollback index matches (1775001600).

### Signing gotchas (all fixed, scripts updated)
- build/make/tools/bin/ now contains apexd_host, deapexer, debugfs_static, fsck.erofs,
  libc++.so (copied from out/host/linux-x86/bin — sign_target_files_apks needs them).
- sign-target.sh works. bacon target DELETES target_files_intermediates after packaging
  (line 27 of vendor/lineage/build/tasks/bacon.mk) — run `m target-files-package` BEFORE
  sign-target.sh if the intermediates are gone.

### Phone state RIGHT NOW (as of session end)
- **In Download Mode** (lsusb: 04e8:685d Samsung Download mode, bus 009 device 034).
- heimdall `detect` → "Device detected" ✓ but `flash` → **"Failed to send handshake!" /
  "Failed to receive handshake response. Result: -7"** (LIBUSB_ERROR_TIMEOUT).
- Tried: verbose+debug logging, modprobe cdc_acm, multiple retries. Consistent failure.
- Earlier heimdall flash of TWRP recovery SUCCEEDED earlier in the session, so
  passthrough CAN work — something regressed. Possibly the phone's download mode
  needs a fresh re-entry (power off → Vol- + Vol+ + cable), or the KVM USB passthrough
  lost bulk-transfer reliability.
- **Phone has the OLD bootlooping ROM still installed** (bootloop #3 kernel) and the
  old recovery (TWRP was flashed earlier, then heimdall-swapped back to Lineage
  recovery at some point per handover-2 notes — actual state uncertain).

## IMMEDIATE NEXT STEPS (in order)

1. **Fix the heimdall handshake** (or bypass):
   a. Ask user to fully power off the phone, then re-enter Download Mode fresh
      (Vol- + Vol+ + cable). Sometimes fixes stale gadget state.
   b. If still failing: **bypass the VM** — copy vbmeta-signed.img + (optionally
      recovery-signed.img) to a location the user's host PC can reach, and have the
      user run heimdall directly on the HOST (outside the KVM guest). This removes
      the USB passthrough from the equation entirely.
   c. Alternative: flash via TWRP if reachable — TWRP can dd-write vbmeta? (No —
      TWRP lacks heimdall. But `dd if=vbmeta-signed.img of=/dev/block/by-name/vbmeta`
      from TWRP root shell WOULD work if TWRP is reachable via adb.)
2. **Flash vbmeta-signed.img** (this carries the SPL 2026-04-01 rollback index that
   matches the ROM — critical for keymaster/FBE).
3. **Flash Nopenix-recovery-signed.img** to RECOVERY (gives us Lineage recovery with
   the exynos9820.retrofit_dynamic_partitions edify function).
4. **Boot Lineage recovery** → "Apply update from ADB" → sideload
   Nopenix-signed-ota.zip. DO NOT sideload from TWRP (it lacks the retrofit function).
5. Reboot, wait 5–15 min first boot (APEX decompression + dexopt).
6. If bootloop AGAIN: pull /proc/last_kmsg + /sys/fs/pstore/* from TWRP adb, grep
   'shutdown_command' / netbpfload / keymaster / apexd, diagnose fresh.
7. On success: verify Settings>About Nopenix, Updater URL, LTE (cbd modem fix is now
   in this build!), WiFi, fingerprint, camera, S Pen. Generate OTA JSON
   (scripts/ota-json.sh), update docs/ota.md + releases/ + ROADMAP (Phase 2 done).

## Key technical facts (do not re-derive)

- **SPL fix**: ROM build.prop + vbmeta declare 2026-04-01 to match TEE root-of-trust
  (bootloader reports 202604 from last stock firmware). Verified in sign2.log flow.
- **Bootloop #3 root cause**: old crdroidandroid kernel 4.14.355 lacked UAPI
  __sk_buff gso_segs/gso_size fields; 25Q4 Tethering APEX schedcls programs access
  skb->gso_segs(164)/gso_size(176) → verifier "invalid bpf_context access off=176".
  Official 12.9 used LineageOS kernel 693d1da93597 which HAS these fields.
- **cbd modem fix**: cpboot_v3 built from source, in vendor/bin/cbd. namespace
  `hardware/samsung_slsi-linaro/exynos/cpboot_v3` added to PRODUCT_SOONG_NAMESPACES
  in exynos9820-common/common.mk (Nopenix comment marker present).
- **bacon deletes target_files_intermediates** — run `m target-files-package` before
  sign-target.sh.
- **TWRP cannot sideload this OTA** (lacks retrofit dynamic partitions support).
- adb root WORKS in our Lineage recovery (uid 0 u:r:su:s0).
- /metadata = omr partition. Stale metadata-encryption key there caused bootloop #2
  (keymaster INVALID_KEY_BLOB) — was wiped with `rm -rf /metadata/vold`.
- All local build fixes (see MEMORY.md 2026-10-13/14) are LOCAL-ONLY in
  /srv/android/nopenix-d2s — do not lose on re-sync, do not push to forks without
  user approval (AGENTS.md rule 6).

## Fallbacks

- TWRP restore of user's 12.9 backup (they confirmed making one).
- Odin-flash stock firmware on user's host PC (samfw.com blocked from this VM IP but
  fine from residential).

## Files to know

- Hub repo: /home/user/d2s-crdroid16 (this file: docs/flash-day-handover-3.md)
- Build tree: /srv/android/nopenix-d2s (~229 GB)
- Artifacts: /srv/android/flash-day/{Nopenix-signed-ota.zip, Nopenix-recovery-signed.img,
  vbmeta-signed.img, pit/d2s.pit, last_kmsg_round2.txt}
- Signing keys: /home/user/.android-certs/ (CRITICAL — back up to user's vault!)
- TWRP build: /srv/android/twrp/out/target/product/d2s (EFS-vulnerable build, warn user)
- sign script: /srv/android/sign-target.sh
- build script: /srv/android/build-start.sh
- Modem RE workspace: /home/user/d2s-crdroid16/rea/ (README.md, STATUS.md)
