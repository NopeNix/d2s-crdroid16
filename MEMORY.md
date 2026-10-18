# MEMORY.md — LLM learnings log (append-only, newest first)

> Rules: Every agent MUST append new gotchas/pitfalls/facts here (no permission needed for
> appending). Never delete or rewrite existing entries. Date-prefix each entry. Keep it short.
> Longer write-ups belong in `docs/` (ask permission for those).

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
