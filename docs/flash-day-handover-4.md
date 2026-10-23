# Flash-Day Handover #4 — 2026-10-23 ~23:00 UTC (READ THIS ONE, not #2/#3)

> Newer than docs/flash-day-handover-3.md (which is still useful for flash mechanics).
> MEMORY.md top entries (2026-10-22/23) cover the diagnosis history in detail.

## CURRENT STATE

### What works
- Full build+sign+flash pipeline proven. dd-based flashing via chunked adb push works
  reliably (see "Flash recipe" below). All partition md5s verify.
- Phone BOOTS: kernel 4.14.356, boot animation RENDERS (gralloc/mali fixed!), display
  works, /data f2fs mounted, APEXes activate, netbpfload OK (no netbpfload-missing).
- Camera HAL dlopen FIXED (exynos5::Fence shim, verified on flash via erofs mount of
  vendor region).

### The remaining blocker: system_server hangs in early boot
- Boot reaches `SystemServerTiming: StartDreamManagFull` then NOTHING for 15+ min.
- Watchdog fires `WAITED_UNTIL_PRE_WATCHDOG` at ~33min, dumps native stacks via
  tombstoned INTERCEPT (in-memory only — LOST on reboot, "skipping tombstone file
  creation due to intercept"). Then user force-resets.
- Watchdog MAIN thread spams 82x "Waited one second for
  vendor.lineage.touch.IKeyDisabler/default" — touch HAL
  (vendor.lineage.touch-service.samsung) never registers in servicemanager. sec_ts
  touch IC IS alive in kernel (spam present), so nodes should exist.
- Keystore2: `await_boot_completed Pending 6617s Overdue` = system_server never finishes.
- adbd in system: `FUNCTIONFS_BIND timed out` repeatedly → USB adb never enumerates in
  SYSTEM boot (works fine in recovery!). init.debug.rc forces sys.usb.controller=
  10c00000.dwc3 + config=adb at 'on boot'; ffs ep0 opens but UDC bind never completes.
- Kernel panic at end of each hang = USER force-reset (VOL_DOWN+POWER,
  hard_reset_hook_callback — benign, NOT a kernel bug).

### Build lineage (all at /srv/android/nopenix-d2s, out/Nopenix-*)
1. v1 22:xx Oct22: sepolicy fix only (graphics_device allow) — SF crash-looped (gralloc)
2. v2: + init.debug.rc (logcat→kmsg streamer + forced adbd) — revealed evidence
3. v3 (Oct23 13:02, flashed 13:44): + gralloc.universal9825 PRODUCT_PACKAGES +
   PRODUCT_SOONG_NAMESPACES gralloc3 → phone booted to MTP! but camera HAL dlopen
   failed (wrong shim namespace exynos:: vs exynos5::) → bootanim loop
4. v4 (Oct23 22:22, CURRENT ON FLASH, md5 b5e02f17 OTA / 9c277226 recovery): camera shim
   namespace FIXED to exynos5. Still: bootanimation loop, system_server hang as above.
   NOTE: adb shows "unauthorized" — SYSTEM build.prop has ro.adb.secure=1 ro.debuggable=0
   (Lineage PRODUCT_NOT_DEBUGGABLE_IN_USERDEBUG=true overrides the WITH_ADB_INSECURE
   system_ext prop; ro.adb.secure=0 IS in system_ext but system/build.prop wins at
   runtime per prop precedence). Flash-day device.mk now patched with
   PRODUCT_SYSTEM_PROPERTIES ro.debuggable=1 (NOT yet built!).

## IMMEDIATE NEXT STEPS (in order)

1. **REBUILD with ro.debuggable=1**: device/samsung/d2s/device.mk already patched
   (PRODUCT_SYSTEM_PROPERTIES += ro.debuggable=1). Full pipeline:
   `bash /srv/android/build-start.sh` → `m target-files-package` → `bash
   /srv/android/sign-target.sh` (~90 min total). Then flash (recipe below).
2. **On the hang-reproduced boot**: with ro.debuggable=1 + ro.adb.secure possibly still
   1, adb unauthorized again? If unauthorized persists even with ro.debuggable=1, ALSO
   need ro.adb.secure=0 in SYSTEM (add PRODUCT_SYSTEM_PROPERTIES ro.adb.secure=0 too —
   I deliberately set 1, change to 0 if needed).
3. **When adb works in system**: `adb root` → wait for the hang (~35 min in) →
   - `adb shell cat /data/tombstones/*` (Watchdog dumps may go there once not intercepted)
   - `adb shell dumpsys activity` / `debuggerd -b <pid>` for system_server
   - Check which thread holds the monitor; likely a binder call into a hung HAL.
   - Prime suspects: (a) touch HAL deadlocks or dies silently — check
     `ps -A | grep touch` and try `vendor.touch-hal` logs; (b) any
     android.hardware.* HAL hung (Watchdog dumped 6516/6521/6526/6527/6654 =
     android.hardwar* + vendor.samsung.* procs — identify them via
     `cat /proc/<pid>/cmdline`).
4. **Also check IKeyDisabler wait spam**: if touch HAL is the hang cause, the fix may be
   removing vendor.lineage.touch-service.samsung from PRODUCT_PACKAGES (test boot
   without it) or fixing its startup (it needs /sys/class/sec/sec_touchkey/input/enabled).
5. **USB adb in system (separate bug)**: FUNCTIONFS_BIND timeout — check whether
   /config/usb_gadget/g1/UDC gets written (init.usb.configfs.rc writes it on
   ffs.ready=1 && config=adb && configfs=1). May need explicit `write
   /config/usb_gadget/g1/UDC 10c00000.dwc3` in init.debug.rc (I appended a block for
   this — verify it fired). Samsung USB HAL (android.hardware.usb.gadget-service.samsung)
   may fight our forced config.

## Flash recipe (proven, use exactly this)
- Build super: `PATH=out/host/linux-x86/bin:$PATH python3 build/make/tools/releasetools/
  build_super_image.py out/signed-target_files.zip /srv/android/flash-day/parts/super.img`
  then `simg2img super.img super-raw.img`, `md5sum super-raw.img`, `split -b 400M -d
  super-raw.img chunk-` (16 chunks).
- Phone in RECOVERY with adb: `adb shell mount -t f2fs /dev/block/by-name/userdata /data`
- Push 16 chunks as /data/superchunk-XX, VERIFY: `adb shell md5sum /data/superchunk-*` vs
  host `md5sum chunk-*` (python compare, mismatches MUST be 0 — flaky USB can corrupt!).
- Write: one adb shell for-loop `dd if=$c of=/dev/block/sda25 bs=1M seek=$((i*400))
  count=$blk conv=notrunc` (sda25 = super = by-name/system). Then read-back verify
  `adb shell md5sum /dev/block/by-name/system` == super-raw md5.
- boot/dtbo/vbmeta/recovery: extract from signed target_files zip
  (IMAGES/boot.img, IMAGES/dtbo.img, IMAGES/vbmeta.img; Nopenix-recovery-signed.img from
  out/) → adb push → `dd ... of=/dev/block/by-name/{boot,dtbo,vbmeta,recovery}`
  conv=notrunc. Verify boot md5 = first 55MB readback.
- `adb shell rm -f /data/superchunk-* /data/*.img; sync` then `adb reboot`.
- NEVER use heimdall for super (too slow/flaky); heimdall only for recovery/vbmeta in
  fresh Download Mode. NEVER trust a single adb push >~800MB (USB passthrough collapses
  to ~1MB/s and corrupts — chunk to 400MB).

## Key facts (do not re-derive)
- super partition = /dev/block/sda25 = by-name/system. Vendor extent starts sector
  4689920 (dd bs=512 skip=4689920 count=393000 to extract vendor). lpdump layout:
  system@2048, system_ext@2277376, vendor@4689920, product@5083136, odm@10119168.
- userdata = sda32 (raw f2fs we formatted; TWRP-era metadata GONE — /data is plaintext
  f2fs, readable in recovery; files pushed there persist across recovery reboots).
- last_kmsg timestamps: if UTC clock differs from boot's internal clock, match via
  keystore2 "Started: <UTC>" line.
- Signing: sign-target.sh does sign_target_files_apks + ota_from_target_files +
  recovery extract. If host reboots mid-sign, signed-target_files.zip survives (verify
  with unzip -t) — only stage 3 (ota_from) needs re-run:
  `PATH=out/host/linux-x86/bin:$PATH python3 build/make/tools/releasetools/
  ota_from_target_files.py -k ~/.android-certs/releasekey out/signed-target_files.zip
  out/Nopenix-signed-ota.zip` (PATH needs unpack_bootimg!).
- Signing keys: /home/user/.android-certs (10 RSA2048, CN=Nopenix Release). BACK THESE UP.
- Full local fixes list: MEMORY.md 2026-10-13/14 entries (repo/build gotchas) +
  2026-10-22/23 (flash-day). All LOCAL-ONLY in /srv/android/nopenix-d2s — do not push.
- Artifacts: /srv/android/flash-day/{Nopenix-signed-ota.zip (b5e02f17),
  Nopenix-recovery-signed.img (9c277226), pit/d2s.pit, last_kmsg_round*.txt, lk*.txt}.
- Phone: SM-N975F serial RF8MC0SAXCJ. In recovery with adb = ask user. Download mode
  = fresh re-entry fixes heimdall handshake failures.
