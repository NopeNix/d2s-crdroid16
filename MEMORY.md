# MEMORY.md — LLM learnings log (append-only, newest first)

> Rules: Every agent MUST append new gotchas/pitfalls/facts here (no permission needed for
> appending). Never delete or rewrite existing entries. Date-prefix each entry. Keep it short.
> Longer write-ups belong in `docs/` (ask permission for those).

- 2026-10-24 — **FIRST FULL BOOT SUCCESS. Handover #5 (docs/flash-day-handover-5.md) — READ THAT.**
  Phone boots to home screen with adb, WiFi, LTE (Telekom.de, fraenk SIM LOADED), and cbd+rild
  running (Option-B cpboot_v3 WORKS on device, baseband N975FXXS9HWH6, SHANNON5000).
  Two root causes fixed in v12 build: (1) crDroid's SPOOF_SAFETYNET init feature overrides
  device.mk ro.debuggable=1 at runtime → adb unauthorized; disable it in device tree init.
  (2) d2s manifest.xml declared IKeyDisabler/IAdaptiveBacklight HALs whose sysfs nodes don't
  exist → PhoneWindowManager blocks in waitForDeclaredService → system_server hang. Remove
  unsupported HAL interfaces from manifest.xml. Flash recipe unchanged (handover #4).
  Device tree fixes are LOCAL-ONLY in /srv/android/nopenix-d2s — do not push yet.
- 2026-10-22 — HANDOVER #3 written: docs/flash-day-handover-3.md (READ THIS ONE).
  Full rebuild with Lineage kernel 693d1da93597 SUCCEEDED. New artifacts staged in
  /srv/android/flash-day/: Nopenix-signed-ota.zip md5 f2813d9b8c6ffc6e18984f5617ea0699
  (boot kernel 4.14.356-openela-rc1-g693d1da93597), Nopenix-recovery-signed.img md5
  00e4b9c73424c7ceabdb7bae06efed7a, vbmeta-signed.img (flags=3, rollback 1775001600).
  cbd modem daemon built and included (vendor/bin/cbd). Phone is in DOWNLOAD MODE;
  heimdall detect works but flash handshake FAILS (libusb timeout on interface 1,
  tried verbose/debug, modprobe cdc_acm, retries — consistent). Likely USB passthrough
  regression. NEXT: re-enter download mode fresh, or have user run heimdall on HOST
  PC to bypass passthrough, or dd vbmeta from TWRP if reachable. Then boot Lineage
  recovery, sideload OTA (NOT from TWRP). Full details in handover-3.md.
- 2026-10-22 — HANDOVER #2 (docs/flash-day-handover-2.md): session was context-bound.
  Verified current artifacts: Nopenix-signed-ota.zip md5 5e284e13..., recovery img md5
  07c9e60e... (OLDER handovers/MEMORY entries cite 82f4477c/a9be748e — those are pre-
  SPL-fix artifacts, do not confuse). Phone was NOT connected: adb empty, lsusb no 04e8,
  heimdall print-pit failed 3x (no device). NOTHING was changed this session. Next LLM:
  ask user to replug phone → TWRP (verify /data still formatted) → heimdall-flash OUR
  recovery → sideload in OUR Lineage recovery (user TWRP lacks retrofit dyn-partitions
  support). Then follow handover doc steps 4–6.
  2026-10-20 — FLASH-DAY STATUS
- 2026-10-21 — BOOTLOOP #3 ROOT CAUSE (bpfloader-failed): After SPL fix + format data + successful
  sideload (16:04, our Lineage recovery, exit 0), phone STILL bootloops: init reboots with
  'reboot,bpfloader-failed'. netbpfload loads 9 tethering maps OK, then FAILS loading program
  schedcls_tether_downstream6_ether with EPERM and NO avc denials. On-device reproduction via
  custom static aarch64 bpf harness (/tmp/bpf_test*.c, cross-compiled with
  aarch64-linux-gnu-gcc) captured the verifier log: "invalid bpf_context access off=176 size=4".
  CHAIN: (1) kernel = 4.14.355-openela (Phoenix merge, ae1152aa0a33) whose kernel/sys.c newuname()
  FAKE-unames "5.4.186" for comm bpfloader/netbpfload/netd (Lineage policy since 2024, commit
  04ab1a48); (2) netbpfload therefore selects the 5_4-variant tether progs; (3) 25Q4 Connectivity
  (May-2025+ commits 954bc98a22/5d79fdffd3/84c89b1498) made the 5_4 progs access skb->gso_segs(164)
  and skb->gso_size(176); (4) the 4.14 kernel's UAPI __sk_buff is only 168 bytes (no
  tstamp/wire_len/gso fields) so verifier rejects off>=168. ro.build.type=user also suppresses the
  verifier log dump (isUser() check in loadCodeSections). /metadata = omr partition (fstab).
  Wiped stale /metadata/vold metadata-encryption key (created 2026-10-18 by 202609-SPL build,
  unwrappable after SPL downgrade) → fixed the keymaster INVALID_KEY_BLOB bootloop #2.
  adb root WORKS in our recovery (uid 0 u:r:su:s0). Fix being developed: verify official 12.9's
  offload.o (downloading from sourceforge) to determine whether official predated gso commits.

- 2026-10-21 — BOOTLOOP #3 REAL FIX: kernel tree was pinned to the WRONG SOURCE. The official
  crDroid d2s v12.9 (20260426) kernel is **4.14.356-openela-rc1-g693d1da93597** from
  **LineageOS/android_kernel_samsung_exynos9820** commit 693d1da93597 (NOT the crdroidandroid
  fork we pinned, which is stuck at 4.14.355 ae1152aa0a33 = Dec 2024; crdroidandroid's 16.0
  kernel branch never got the later Lineage commits). Official's tethering offload.o is
  byte-identical to ours (md5 f39685c7...) — so the programs were never the difference; the
  KERNEL was. Lineage's 693d1da93597 kernel adds to UAPI __sk_buff: tstamp/wire_len/gso_segs/
  gso_size fields (matching the bionic layout the APEX progs compile against) + verifier
  convert_ctx_access cases for them (bpf_convert_shinfo_access) — making the 5_4-variant progs
  verify cleanly on the fake-5.4 uname. FIX APPLIED: fetched 693d1da93597 from LineageOS repo
  into the kernel tree (fast-forward descendant, 1937 commits ahead, 0 behind), checked out
  branch official-v129, reverted the temporary device.mk ro.bpf.kver_override experiment, and
  kicked off full rebuild (brunch d2s, log: /srv/android/nopenix-rebuild.log). After build:
  sign via /srv/android/sign-target.sh, flash boot via heimdall or re-sideload OTA.
  Gotchas: SourceForge download needs curl -L + resume (-C -) for 1.5GB; sdat2img transfer-list
  format = "new <argcount>,s1,e1,s2,e2..." where argcount IS the count of following numbers
  (pairs of start,end blocks); system.img from .new.dat+transfer.list extracts via debugfs.


- 2026-10-21 — MODEM FIX IMPLEMENTED (Option B, user-approved): added
  `soong_config_set(cbd,protocol,sipc)` + `soong_config_set_bool(cbd,use_legacy_sipc_ioctl,true)`
  to exynos9820-common BoardConfigCommon.mk and `cbd` to RIL PRODUCT_PACKAGES in
  common.mk (AOSP working tree /srv/android/nopenix-d2s). Source-built cbd comes from
  hardware/samsung_slsi-linaro/exynos/cpboot_v3 (Apache-2.0), ABI-verified against our
  4.14 kernel (all ioctls+structs match; see rea/STATUS.md). NOT yet rebuilt/flash-tested.
  Fork has other uncommitted changes from earlier sessions — do NOT commit those with
  modem work.

- 2026-10-21 — MODEM/RE SESSION (`rea/` workspace): all Samsung modem RE work lives in
  `rea/` (README.md = entry point, STATUS.md = handoff). Root cause of missing modem:
  **`/vendor/bin/cbd` (cpboot-daemon) is missing from the image** — proprietary-files.txt
  lists `-vendor/bin/cbd` but TheMuppets 23.2 tree dropped that blob (22.2+). Two fixes:
  (A) restore blob from rea/bin/blobs/cbd (TheMuppets lineage-22.1, sha b3303b91...) or
  (B, recommended) build open-source `cpboot_v3` exactly as upstream Lineage 23.2
  exynos9820-common does (2 soong_config lines in BoardConfigCommon.mk + `cbd` in
  PRODUCT_PACKAGES). Full ABI verification (ioctls, structs, TOC parse) done — see
  `rea/docs/cbd-ioctls-and-flow.md`, `rea/STATUS.md`. Kernel side has NO gap
  (s5000ap + shmem + modem_v1 compiled, System.map verified). All libsec-ril deps
  present (25/25). Modem = Shannon S5000AP, baseband N975FXXS9HWHA (already in OTA).
  DO NOT touch build tree for this without user approval.

- 2026-10-20 — FLASH-DAY STATUS (end of session, READ THIS FIRST): Phone = user's
  personal daily driver SM-N975F (d2s), serial RF8MC0SAXCJ. Sequence so far: (1) built
  signed OTA + recovery, (2) user flashed our recovery — WORKED, (3) sideloaded our
  signed OTA — BOOTLOOP, (4) root cause IDENTIFIED from last_kmsg: 'reboot,netbpfload-missing'
  — netbpfload binary lives in com.android.tethering APEX (capex present in build) but
  apexd FAILED to decompress apexes into /data/apex/* because /data still held crDroid
  12.9's OLD encrypted userdata (FBE keys mismatch with our 16.0 build). NOT a kernel or
  vendor issue. (5) FIX APPLIED: TWRP 'twrp format data' executed successfully over adb,
  (6) user was rebooting recovery to remount /data when USB dropped (phone physically
  dropped, cable disconnected). NEXT SESSION MUST: adb connect, confirm recovery/TWRP,
  then adb sideload /srv/android/flash-day/Nopenix-signed-ota.zip (md5 82f4477c...),
  then reboot and watch first boot. If still bootloops: pull /proc/last_kmsg + pstore,
  check netbpfload/apexd again. Fallback: TWRP restore of user's 12.9 backup.
- 2026-10-20 — TWRP is on the phone now (user installed it; shows as omni_d2s, kernel
  4.14.113-g55f042627, TWRP 'twrp' CLI works over adb: 'twrp format data' etc). TWRP
  recovery identifies as 'recovery' in adb devices. heimdall NOT usable simultaneously
  (device must be in download mode for heimdall, recovery for adb).
- 2026-10-20 — Flash-day artifacts live in /srv/android/flash-day/: Nopenix-signed-ota.zip
  (1.52GB, md5 82f4477ce628df6e553544e48c868270), Nopenix-recovery-signed.img (67MB, md5
  a9be748e6dedf7e7822d0e4ffb9b176c), pit/d2s.pit (device partition table backup - KEEP!).
  User's TWRP backup of 12.9 exists on their side (they confirmed making it).
- 2026-10-20 — adb/heimdall installed on host: apt adb fastboot heimdall-flash; udev rule
  /etc/udev/rules.d/51-android.rules for vendor 04e8+18d1. USB passthrough to this KVM
  guest WORKS (user physical cable -> host -> guest). Phone appears as 04e8:6860 (MTP/adb)
  or 04e8:685d (download mode). Sometimes needs cable replug to re-enumerate.
- 2026-10-20 — Stock firmware download attempts ALL BLOCKED from this datacenter IP:
  samfw.com (403), sourceforge (403), samsung FOTA fota-cloud-dn.ospserver.net (403),
  samsung-firmware.org (DNS fail). Samsung FUS API (neofussvr.sslcs.cdngc.net) WORKS for
  nonce+inform but returns Status 401 (auth rejected) on NF_DownloadBinaryInform —
  Frija-style auth (plain nonce + make_signature + logic_check) tried ~8 variants incl.
  correct SESSION cookie; likely requires IMEI-registered device_id or newer FUS protocol.
  NOT NEEDED anyway: our own signed OTA zip IS the base image (contains full
  system/vendor/product .new.dat.br images). TWRP format data + sideload = clean install.
- 2026-10-20 — nanosamfw tool cloned to /tmp/nanosamfw (python FUS client), patched
  fus/crypto.py (Cryptodome instead of Crypto, latin-1 nonce fallback, safe derive_key).
  /usr/bin/python3 has pycryptodome/tqdm/requests via apt python3-* packages. Default
  'python3' is a uv venv WITHOUT these - use /usr/bin/python3 for FUS work.
- 2026-10-20 — SPL MISMATCH ROOT CAUSE (post-format bootloop): TEE keymaster refused
  to unwrap FBE key: key_os_patchlevel(202609) > TEE _os_patchlevel(202604) — the
  bootloader/TEE reports the ROOT OF TRUST from the last STOCK firmware (SPL 2026-04,
  One UI 5.1 base) and REJECTS any keymaster operation with a HIGHER patch level.
  Fix: rebuilt with RELEASE_PLATFORM_SECURITY_PATCH=2026-04-01 (patched
  vendor/lineage/release/flag_values/bp4a/RELEASE_PLATFORM_SECURITY_PATCH.textproto,
  which crDroid had set to 2026-09-01). Verified: out build.prop now shows
  security_patch=2026-04-01. NOTE: with SPL 202604 the ROM CLAIMS an older SPL than
  our actual patch set — acceptable for a test device, flag for future review (the
  ASB content in our tree is still newer; only the DECLARED SPL is downleveled).
- 2026-10-20 — Second sideload FAILED with 'updater process ended with 1: the current
  recovery does not support dynamic partitions'. Analysis: d2s PIT has NO super
  partition (SYSTEM/VENDOR/PRODUCT are real partitions) — the ROM uses the RETROFIT
  dynamic partitions path. The OTA updater-script calls two custom edify functions:
  exynos9820.retrofit_dynamic_partitions() (device-specific, defined in
  device/samsung/exynos9820-common/recovery/recovery_updater.cpp, baked into the
  OTA's update-binary via TARGET_RECOVERY_UPDATER_LIBS) and update_dynamic_partitions()
  (built into Lineage recovery + modern TWRP). The custom fn IS embedded in our OTA's
  update-binary (verified: strings shows exynos9820.retrofit_dynamic_partitions). The
  failure likely came from the USER'S TWRP build lacking retrofit support, or from
  running sideload in a recovery that doesn't execute the embedded update-binary
  extensions. NEXT: confirm which recovery showed the error, and/or sideload in OUR
  Lineage recovery (which we built WITH the extension). If our recovery also fails,
  check that librecovery_updater_exynos9820 was actually linked into the OTA
  update-binary (obj/PACKAGING/target_files_intermediates/*/OTA/ bin dir).

- 2026-10-20 — SPL MISMATCH ROOT CAUSE (post-format bootloop): TEE keymaster refused
  to unwrap FBE key: key_os_patchlevel(202609) > TEE _os_patchlevel(202604) - the
  bootloader/TEE reports the ROOT OF TRUST from the last STOCK firmware (SPL 2026-04,
  One UI 5.1 base) and REJECTS any keymaster operation with a HIGHER patch level.
  Fix: rebuilt with RELEASE_PLATFORM_SECURITY_PATCH=2026-04-01 (patched
  vendor/lineage/release/flag_values/bp4a/RELEASE_PLATFORM_SECURITY_PATCH.textproto,
  which crDroid had set to 2026-09-01). Verified: out build.prop now shows
  security_patch=2026-04-01. NOTE: with SPL 202604 the ROM CLAIMS an older SPL than
  our actual patch set - acceptable for a test device, flag for future review (the
  ASB content in our tree is still newer; only the DECLARED SPL is downleveled).
- 2026-10-20 - Second sideload FAILED with 'updater process ended with 1: the current
  recovery does not support dynamic partitions'. Analysis: d2s PIT has NO super
  partition (SYSTEM/VENDOR/PRODUCT are real partitions) - the ROM uses the RETROFIT
  dynamic partitions path. The OTA updater-script calls two custom edify functions:
  exynos9820.retrofit_dynamic_partitions() (device-specific, defined in
  device/samsung/exynos9820-common/recovery/recovery_updater.cpp, baked into the
  OTA's update-binary via TARGET_RECOVERY_UPDATER_LIBS) and update_dynamic_partitions()
  (built into Lineage recovery + modern TWRP). The custom fn IS embedded in our OTA's
  update-binary (verified: strings shows exynos9820.retrofit_dynamic_partitions). The
  failure likely came from the USER'S TWRP build lacking retrofit support, or from
  running sideload in a recovery that doesn't execute the embedded update-binary
  extensions. NEXT: confirm which recovery showed the error, and/or sideload in OUR
  Lineage recovery (which we built WITH the extension). If our recovery also fails,
  check that librecovery_updater_exynos9820 was actually linked into the OTA
  update-binary.

- 2026-10-14 — SIGNED ARTIFACTS DONE (Phase 2 core): out/Nopenix-signed-ota.zip
  (1.52 GB, md5 82f4477c...) + out/Nopenix-recovery-signed.img (67 MB, md5 a9be748e...),
  both signed with ~/.android-certs (10 RSA2048 certs, subject CN=Nopenix Release,
  sha256 fp 12:1C:87:C0...26:AA, valid to 2056). Verified: otacert subject == our

- 2026-10-14 — SIGNED ARTIFACTS DONE (Phase 2 core): out/Nopenix-signed-ota.zip
  (1.52 GB, md5 82f4477c...) + out/Nopenix-recovery-signed.img (67 MB, md5 a9be748e...),
  both signed with ~/.android-certs (10 RSA2048 certs, subject CN=Nopenix Release,
  sha256 fp 12:1C:87:C0...26:AA, valid to 2056). Verified: otacert subject == our
  releasekey cert; ~every APK re-signed with releasekey; white Nopenix logo verified
  inside recovery ramdisk (res/images/logo_image.png, 1024x640 grayscale, white fill,
  transparent bg). NOTE for recovery: logo_image.png in Lineage recovery is rendered
  on black bg in charge/splash mode.
- 2026-10-14 — Signing toolchain gotchas (all unblocked, fixes are build-local):
  sign_target_files_apks needs (a) TOP env + lunch lineage_d2s-bp4a-userdebug,
  (b) SELINUX_IGNORE_NEVERALLOWS=true (neverallow system_server sys_module from
  exynos9820-common system_server.te), (c) PYTHONPATH += external/avb,
  system/apex/apexer, system/update_engine/scripts, (d)
  PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION=python (host protobuf 5.x vs old generated
  pb2), (e) regenerated ota_metadata_pb2.py with protoc 3.21 (upstream pb2 used
  legacy descriptor API → map<string,string> property_files assignment crashed),
  (f) upstream common.py PartitionMapFromTargetFiles crashes when input is a
  ZipFile/zip path (expects extracted dir) — patched to resolve against out/tf-dir;
  sign script unzips target_files to out/tf-dir first. Script: /srv/android/sign-target.sh.
- 2026-10-14 — Recovery logo custom: replaced logo_image.png in bootable/recovery
  res-{mdpi..xxxhdpi}/images with user SVG rendered white (ImageMagick: -fill white
  -colorize 100, resize 70% of canvas height, gravity center). d2s is header v1 boot
  image: ramdisk at page+ksz (page=2048, from header offsets 8/16), gzip+cpio unpack.

- 2026-10-13 — FIRST NOPENIX BUILD SUCCEEDED on the build host (/srv/android, 500G ext4 at
  /dev/vda raw, 31G RAM + 24G swap at /srv/android/swapfile needed for soong OOM).
  Product: crDroidAndroid-16.0-20261013-d2s-v12.12.zip (1.52 GB) + recovery.img (67 MB).
  Full chain: lunch lineage_d2s-bp4a-userdebug (crDroid's aosp_target_release=bp4a — NOT
  ap3a! ap3a => SDK35 => missing sdk:36 variants => uprobestats crtbegin failures).
- 2026-10-13 — Dep-repo era pins are MANDATORY: lineage-23.2 branch HEADs move; the d2s
  trees (Jan 2025) need Apr-2026 dep state. Pins live in build host
  .repo/local_manifests/pin-hw.xml (capture to manifests/ later): hw/samsung 7eda6c8,
  hw/lineage/interfaces e59aaa7, hw/lineage/compat 98b61d0, slsi_sepolicy 49927582,
  slsi config fa6c5de, exynos 7cbe68f, exynos5 7a7c982, graphics dece8a0,
  interfaces aa39734, openmax 15ab308.
- 2026-10-13 — Local build fixes applied (build-local, should become fork PRs):
  (1) exynos9820-common: usage_64bit soong_config_set→set_bool; common.mk/common_pie_launched.mk
  stale @1.0 HIDL module names → AIDL names (livedisplay-service.samsung-exynos,
  powershare-service.samsung, touch-service.samsung), audio.primary.exynos9820→
  audio.primary.universal9825 (slsi name-substitution by TARGET_BOARD_PLATFORM),
  fastcharge@1.0 dropped (sunset upstream), gralloc.exynos9820/libbt-vendor dropped;
  manifest.xml HIDL lineage HALs → AIDL entries; sepolicy/vendor: removed spen type/attr/
  service/file_context dups now provided by pinned slsi sepolicy (kept cpdebug_efs_file —
  slsi does NOT declare it); (2) hw/samsung Android.bp soong_namespace imports += vendor
  samsung namespaces (keymaster blob visibility); (3) vendor Android.bps: check_elf_files:
  false on prebuilts (era-mismatched blobs fail strict check); (4) vendor/lineage
  config/common.mk: removed '-prebuilts/misc/protobuf_vendorcompat' from
  PRODUCT_SOURCE_ROOT_DIRS (libsec-ril needs libprotobuf-cpp-full-3.9.1-vendorcompat);
  added audio.primary.universal9825 to EPE allowlist; (5) vendor/lineage/tools/
  clean_headers.sh: rm generated linux/sched{.h,/types.h} (bionic sched_param redefinition);
  (6) .repo/repo/manifest_xml.py: manifest -r tolerant of phantom platform/* projects
  (emits zero SHA) — build-manifest.xml informational only.
- 2026-10-13 — repo/build gotchas: `repo sync` w/o --no-clone-bundle downloads FULL
  bundles (~60GB clang) ignoring clone-depth! Always: `repo sync -c --force-sync
  --no-clone-bundle --no-tags`. repo only applies clone-depth to NEW clones; use
  slim-project.sh (/srv/android, shallow-replaces pack by SHA) to slim fat packs whose
  worktree is valid. soong_build needs >31G RAM => swap required. `repo manifest -r` /
  repo status can show phantom platform/* projects after local-manifest overrides —
  harmless with the patched manifest_xml.py.
- 2026-10-13 — bacon zip is signed with AOSP testkey by default (zip-signed flow);
  proper release = sign_target_files_apks with ~/.android-certs (10 Nopenix RSA2048
  certs generated, no passphrases, subject CN=Nopenix Release) — Phase 2.

- 2026-09-03 — Blob check DONE (Phase 1): TheMuppets lineage-23.2 blobs are complete for
  the 16.0 device trees. Proprietary-files.txt lists 6 "missing" entries but none are
  needed: the 5 d2s 32-bit vendor/lib libs (libTOFProc_interface, libbauthserver,
  libbauthtzcommon, libdatazip, libiu456_datapath_processor) were deliberately deleted
  in TheMuppets b98d195 "Regenerate for elfchecks" (Android.bp ships arm64 src only);
  `cbd` was dropped from the blob repo in 9064571 "Build cbd from source" — Lineage
  universal9820-common (lineage-23.0) builds cbd as a source module
  (PRODUCT_PACKAGES += cbd in common.mk). Caution: the crDroid 16.0 exynos9820-common
  tree does NOT contain that cbd source module (no PRODUCT_PACKAGES entry, no
  Android.bp module) — prebuilt cbd from NopeNix common 13.0 may be required if RIL
  fails. Verdict: don't fall back to crDroid 13.0/14.0 blobs (21-entry gap incl. the
  whole kang'd AIDL RIL stack); keep TheMuppets.
- 2026-09-03 — Forks are verbatim copies of upstream: NopeNix/android_device_samsung_d2s@16.0
  and _exynos9820-common@16.0 proprietary-files.txt are byte-identical to
  crdroidandroid 16.0. All 8 hardware deps in nopenix.xml exist at lineage-23.2 on
  LineageOS (raw-file 404s on empty repos are normal; use the git-trees API to probe).
- 2026-09-03 — This sandbox cannot host a build: 29 GB disk (6.8 GB free), 15 GB RAM.
  repo sync + brunch d2s must run on the user's 250 GB+/32 GB host per build-guide.md.

- 2026-10-04 — The official d2s maintainer is Pedro Araujo "deuspivete" (not FreeRunner2017 —
  FreeRunner is a different Note10-series maintainer from earlier ROMs). deuspivete's local
  manifest / exact build recipe was never published; OTA JSON in crdroidandroid/android_vendor_crDroidOTA
  (branch 16.0, `d2s.json`) links the three device repos but not blobs.
- 2026-10-04 — crdroidandroid proprietary blob repos (proprietary_vendor_samsung_d2s &
  _exynos9820-common) only have branches 13.0/14.0, far behind the Lineage-23.2 base of
  crDroid 16. TheMuppets has lineage-23.2 blobs for both → default blob source (decided).
- 2026-10-04 — GitHub-hosted runners cannot build this ROM (~84 GB disk, ~7 GB RAM, 6 h job
  limit vs 150+ GB / 16+ GB RAM needs). Builds happen locally; releases pushed manually.
- 2026-10-04 — Updater app (crDroid/Lineage) matches OTA JSON `version` against
  `ro.lineage.build.version` — do NOT rename PRODUCT_NAME away from `lineage_d2s` or OTA
  version matching breaks. Brand via props/display strings instead (see docs/branding.md).
- 2026-10-04 — First Nopenix build cannot be OTA'd directly from official crDroid 12.9:
  official recovery trusts crDroid release keys only. Path = flash our recovery + sideload
  once manually; afterwards Updater works (see docs/ota.md).
- 2026-10-04 — VoLTE/VoWiFi are known-broken on the exynos9820 family in all these ROMs;
  do not treat as a regression we introduced.
- 2026-10-04 — Beware confusion: `a10` / A10s (SM-A107F) are DIFFERENT Samsung devices.
  crDroid's `d2s` = Galaxy Note10+ (SM-N975F). Some XDA threads mix these; trust the OTA JSON
  and device repos, not thread titles.
- 2026-10-22 — Bootloop #4 root cause: userdata partition had NO valid fs (no f2fs magic @1024,
  no ext4 @1080 — leftover encrypted garbage from TWRP-era wipes). vold never mounts /data
  (fs_mgr skips: invalid f2fs magic), apexd fails "Failed to open decompression destination
  /data/apex/decompressed/com.android.tethering@...apex: No such file or directory" →
  tethering APEX never activates → netbpfload missing BPF progs → exit 1 → init
  reboot_on_failure 'reboot,netbpfload-missing'. Diagnosis chain: last_kmsg (pstore
  dmesg-ramoops-0.enc.z is encrypted, but /proc/last_kmsg readable in recovery) shows
  apexd+init msgs. FIX: from Lineage recovery (adb root works):
  `make_f2fs -g android /dev/block/by-name/userdata 60062720` (vold was never triggered
  because fstab rec has no force_format; system's mount_with_alternatives only warns).
  Verified magic + `mount -t f2fs -o ro`. LESSON: after TWRP `format data`, ALWAYS verify
  fs magic at offset 1024 (f2fs) before first system boot; TWRP format may leave
  garbage if interrupted (this box: TWRP "format data completed" 2026-10-20 but USB
  dropped mid-session — partition was never actually fully formatted).
- 2026-10-22 — heimdall handshake failure after long Download-Mode idle: control xfer OK
  (detect works) but bulk xfer fails ("Failed to send handshake"). Fix = fresh Download
  Mode re-entry (user replug). Then flash succeeds. usbreset via sysfs does NOT help.
  Keep artifacts staged in /srv/android/flash-day/ (md5s in handover-3 are current).
- 2026-10-22 — Flash-day session 3 (rounds 6-8): (1) gralloc sepolicy fix (allow
  hal_graphics_allocator_default → graphics_device dir/file/chr_file in
  device/samsung/exynos9820-common/sepolicy/vendor/hal_graphics_allocator_default.te)
  removed ALL avc denials but SF STILL SIGABRT-loops → root cause still unknown,
  need logcat. (2) Sideload OTA of 8aed06b3 build failed 3× DIFFERENTLY: 2×
  "Error in /sideload/package.zip (killed by signal 7)" deterministic time_total=31
  (both times in post-panic recovery), 1× adb connection drop mid-transfer. The
  successful installs earlier were from fresh recovery boots. (3) BCB route
  (--update_package=/data/ota.zip) works but recovery serves /data packages via
  FUSE as /sideload/package.zip, then setup_install_mounts() fails
  "Failed to unmount /data: Device or resource busy" (fuse daemon holds fd) →
  /data-hosted OTA via BCB is a dead end on this recovery. /cache too small
  (600MB) for 1.5GB zip. (4) WORKING FLASH PATH: chunked adb push (split -b 400M;
  single pushes >~800MB collapse to ~1MB/s on this KVM passthrough; chunks run
  100-1000MB/s each!) → `cat /data/chunk-* > /dev/block/by-name/system` + md5sum
  verify block device vs host file. Flashed boot/dtbo/vbmeta/super all verified.
  super.img built locally: build_super_image.py out/signed-target_files.zip →
  sparse 2.95GB → simg2img → 6.5GB raw; lpdump confirmed layout matches device
  (single-slot Samsung: partitions named system/vendor/product/odm/system_ext,
  no _a suffix). (5) fastbootd from VM unusable: Samsung gadget advertises
  bInterfaceProtocol=1 (AOSP fastboot wants 3) — patched host fastboot.cpp to
  accept protocol 1 & rebuilt (out/host/linux-x86/bin/fastboot); still flaky:
  gadget re-enumerates every command, then USB dropped off bus entirely.
  (6) adb server respawns (watchers/canvas) and re-claims USB device via usbfs,
  starving fastboot — kill adb server right before fastboot. (7) init.debug.rc
  round 1: logcat -f /dev/kmsg crashed instantly ("Connection reset by peer");
  adbd never seen. Round 2 = `logcat | tee /dev/kmsg` + explicit `start adbd`.
  (8) Lineage userdebug: ro.adb.secure=1 + ro.debuggable=0 UNLESS
  WITH_ADB_INSECURE=true at build time. (9) /data is PLAINTEXT raw f2fs (no
  metadata encryption active — /metadata/vold exists but empty-ish); pushed
  files read back md5-clean; FBE-looking dirs exist under /data/misc (per-dir
  policies) but /data root is unpolicied → staging files readable across
  recovery reboots.
- 2026-10-23 — Bootloop #7 (bootanimation loop) root cause: missing libshim_camera.so. The
  libexynoscamera3 blob (TheMuppets 23.2) links against libshim_camera expecting BOTH the
  old GraphicBufferMapper::unlock(const native_handle*) symbol AND exynos::Fence class
  symbols (_ZN7exynos55FenceC1Ei, C1Eunique_fd, 4waitEi + vtable). The in-tree shim
  (device/samsung/exynos9820-common/shims/libcamera) only provides unlock; exynos9825.mk
  (which d2s inherits) does NOT add libshim_camera to PRODUCT_PACKAGES (only the -r
  variant does). Camera HAL dlopen fails → vendor.camera.provider SIGSEGV (fault addr 0x10)
  → kernel panic. FIX: (1) extended shims/libcamera/GraphicBufferMapper.cpp with a faithful
  exynos::Fence class (ABI from disassembling deuspivete's official v12.9 libshim_camera.so:
  layout vptr+int+int fd, vtable 2 slots (dtor, deleting dtor), wait()=sync_wait+close+return
  -errno, fd=-1 → return 0); added libbase to shim shared_libs; (2) added libshim_camera
  to exynos9825.mk. KEY EVIDENCE PATH: logcat→kmsg streamer (init.debug.rc tee /dev/kmsg)
  FINALLY captured the dlopen failure line. Official v12.9 vendor mount workflow: brotli -d
  vendor.new.dat.br, apply transfer.list 'new' ranges to flat img, mount -t erofs,loop —
  worked for direct comparison (md5 libGLES_mali identical, so blob set matches).
- 2026-10-23 — gralloc.universal9825.so (SLSI gralloc3 legacy hw module) was missing from
  our build → mali "Invalid handle" → skia EGL_BAD_ALLOC (0x300c) → RenderEngine SIGABRT
  loop (bootloop #6). TWO fixes: (1) PRODUCT_PACKAGES += gralloc.universal9825 in
  exynos9820-common/common.mk Display section; (2) CRITICAL: the slsi gralloc3
  Android.bp declares its OWN soong_namespace, so soong never parsed it — must add
  PRODUCT_SOONG_NAMESPACES += hardware/samsung_slsi-linaro/exynos/gralloc/gralloc3.
  (gralloc4 has no namespace block → parsed under parent ns → worked). Verified against
  official v12.9 vendor image which contains gralloc.universal9825.so (89.5KB).
  After fix: phone BOOTS ANDROID (MTP enumeration, boot animation renders!).
- 2026-10-23 (later) — Camera shim FIX #1 FAILED silently: I wrote the Fence shim in
  namespace `exynos` but the blob needs `exynos5` (_ZN7exynos55FenceC1Ei = exynos5::Fence).
  Lesson: VERIFY exported symbol names against the blob's UND list BEFORE building
  (readelf --dyn-syms on the .so, decode the mangled name). The shim now exports the right
  names after renaming namespace exynos → exynos5 (verified with a test compile:
  _ZN7exynos55FenceC1Ei + _ZN7exynos55Fence4waitEi produced). Bootloop #8 (bootanimation
  loop persists) root cause was this same dlopen failure repeating.
  Rebuild in flight: rebuild-shim2.log / sign10.log.
- 2026-10-23 (afternoon) — Flash-state verification workflow that saved us: dd + md5 per
  400MB chunk BEFORE writing to super; then read-back verify region-by-region. Confirmed
  the 13:30 dd flash DID land the exynos5Fence shim (erofs mount of raw vendor region
  extracted from sda25: sector 4689920, 393000 sectors). The user's "still looping"
  report came BEFORE the new flash was applied — phone hadn't booted the new build yet.
  ALSO: /proc/last_kmsg only updates after panic/reboot from a FAILED boot; the 11:29
  kmsg was stale. AVB check: dev vbmeta boot hash (49917952 bytes, salt b65c5b...) =
  sha256(salt+boot[:49917952]) ✓ — boot image valid for its vbmeta.
- 2026-10-23 (evening) — Bootloop #9 (bootanimation loop, gralloc+camera shim build):
  camera dlopen FIXED (no dlopen errors in 19:23 boot kmsg!). New failure: system_server
  hangs >33min in early boot (last progress marker SystemServerTiming: StartDreamManagFull
  19:18:01), Watchdog fires WAITED_UNTIL_PRE_WATCHDOG, dumps native stacks via
  tombstoned intercept (in-memory, LOST on reboot — not written to /data due to
  'skipping tombstone file creation due to intercept'). Watchdog MAIN thread itself
  spams 82x 'Waited one second for vendor.lineage.touch.IKeyDisabler/default' — touch
  HAL (vendor.lineage.touch-service.samsung) never registers in servicemanager. Also:
  adbd in system gets 'FUNCTIONFS_BIND timed out' → USB adb never enumerates in system
  boot (configfs/UDC wiring issue; recovery adb works fine). Kernel panic at end was
  USER force-reset (VOL_DOWN+POWER at 19:23:21, hard_reset_hook in interrupt — benign).
  NEXT: build with WITH_ADB_INSECURE=true (ro.adb.secure=0, ro.debuggable=1) → when hang
  hits, adb root works in system → capture /data/tombstones + full java stack of
  system_server. ALSO fix init.debug.rc UDC write ordering + verify touch HAL start
  (it needs /sys/class/sec/sec_touchkey nodes — check sec_ts driver state at that point).
  Build in flight: rebuild-insec.log / sign11.log.
- 2026-10-23 (night) — Handover #4 written: docs/flash-day-handover-4.md (also at
  /srv/android/flash-day/HANDOVER-4.md). READ THAT FIRST. State: v4 build (exynos5
  camera shim) on flash; phone boots but system_server hangs at StartDreamManager,
  Watchdog fires, stacks lost (tombstoned intercept). Touch HAL never registers
  (82x IKeyDisabler waits). adbd in system: FUNCTIONFS_BIND timeout (USB adb broken in
  system, works in recovery). NEXT: rebuild w/ ro.debuggable=1 (device.mk patched,
  NOT built), then capture tombstones/java stacks via adb in system. Flash recipe +
  all gotchas in handover-4. v4 md5s: OTA b5e02f17, recovery 9c277226.
