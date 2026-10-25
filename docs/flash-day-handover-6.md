# Flash-Day Handover #6 — 2026-10-25 (NEWEST — READ THIS ONE)

> Written mid-session; the host received a root `wall` broadcast "The system will reboot
> now!" at 18:34 UTC. Host was still up 25 min later, but RE-VERIFY HOST ALIVE before
> trusting anything below. If the host rebooted: /srv/android (build tree, ccache, flash-day
> artifacts) and the adb USB passthrough should survive a VM reboot — recheck `lsusb`,
> `adb devices`, and that /srv/android/nopenix-d2s is mounted.

## SESSION #6 SUMMARY (what happened after first full boot success)

### Subsystem verification on device (v12 build, booted since ~13:00)
Verified GOOD via adb (while device was attached):
- **Sensors**: full sensor list populated (LSM6DSO accel/gyro, AK09918C mag, LPS22H baro,
  TMD4910 prox/lux, step detectors) — `dumpsys sensorservice` healthy.
- **Camera**: camera provider up; devices 0,1,2,3,52 (5 cameras) registered.
- **Audio**: android.hardware.audio.service + audioserver running. (No audible test yet —
  ask user to play a sound / check speakers next session.)
- **GNSS**: lhd + gpsd + vendor.samsung.hardware.gnss@2.1-service running; location
  providers (gps/fused/passive) registered. No fix test yet.
- **S-Pen**: `sec_e-pen` input device registered with /vendor/usr/idc/sec_e-pen.idc.
- **Mobile data/telephony**: confirmed working (previous session; cbd/rild up,
  Telekom.de, fraenk SIM LOADED).
- Battery: 100%, USB powered, health good.

### BUG FOUND: Bluetooth completely broken (crash-looping)
- `svc bluetooth enable` -> com.android.bluetooth crashes; bluetooth stays OFF.
- Root cause chain (logcat): `android.hardware.bluetooth@1.0-impl: Open unable to open
  libbt-vendor.so (dlopen failed: library "libbt-vendor.so" not found)` ->
  `Unable to call initializationComplete(ERR)` -> `BluetoothDeathRecipient::serviceDied`
  -> com.android.bluetooth dies -> AdapterService restart loop.
- **Official v12.9 DOES ship /vendor/lib64/libbt-vendor.so** (verified by string search
  inside official-v12.9.zip's vendor.new.dat).
- Root cause in tree: our fork of device/samsung/exynos9820-common (lineage-22.x-era base)
  is missing the lineage-23.2 bluetooth glue. Upstream lineage-23.2 common.mk has:
      $(call soong_config_set,brcm_libbt,custom_bt_config,//$(COMMON_PATH):vnd_exynos9820.txt)
      PRODUCT_PACKAGES += ... libbt-vendor:64
  and bluetooth/Android.bp (filegroup vnd_exynos9820.txt -> bluetooth/libbt_vndcfg.txt).
  Our fork had neither -> libbt-vendor never built -> not in vendor image.

### FIXES APPLIED THIS SESSION (all LOCAL-ONLY in /srv/android/nopenix-d2s, not pushed)
1. **Bluetooth**: created device/samsung/exynos9820-common/bluetooth/Android.bp
   (filegroup, mirrors upstream) and added the soong_config_set + `libbt-vendor:64`
   to common.mk's Bluetooth block. Needs a rebuild to land in the vendor image.
2. **adb root**: extended build/soong/scripts/gen_build_prop.py — when
   BuildBrokenDupSysprop (our flash-day escape hatch, set in d2s BoardConfig.mk) is on,
   it now ALSO skips `ro.secure=1` (emits ro.secure=0). Reason: adbd caches its
   debuggable check at its early start BEFORE system/build.prop lands, so the runtime
   ro.debuggable=1 never reaches it; ro.secure=0 is the only reliable path.
   (Backup of the pre-patch file: /tmp/gen_build_prop.py.bak — may be lost on reboot.)

### INCIDENT: phone vanished from USB
- Right after an `adb root` attempt (~19:05 device time; adbd restarted, USB gadget
  unbound/rebound per logcat), the phone dropped COMPLETELY off the bus (`lsusb` shows no
  04e8/18d1 at all — not even charging mode). Did not return for 10+ minutes.
- Prior pattern: this environment's USB passthrough is fragile (heimdall handshake
  failures in earlier sessions had the same smell).
- ACTION FOR USER: physically check the phone (screen on? charging?), replug the cable,
  or reboot the phone. Then run `lsusb | grep 04e8` + `adb devices` to re-establish.
- NOTE: while unrooted, `adb root` on this build silently fails (see fix #2 — needs
  rebuild). Don't burn time on adb root until the rebuilt image is flashed.

## NEXT STEPS (in order)
1. **Re-establish adb** with the phone (user action: replug/unlock).
2. **Rebuild v13**: `bash /srv/android/build-start.sh` (background, hours). Picks up the
   bluetooth + ro.secure fixes. Artifacts land in out/target/product/d2s; sign with
   /srv/android/sign-target.sh as before.
3. **Flash v13** using the proven recipe in docs/flash-day-handover-4.md (chunked push +
   dd for super/boot/dtbo/vbmeta/recovery; verify md5s; never heimdall for super).
4. **On v13 verify**: BT turns on (Settings or `svc bluetooth enable`), `adb root` gives
   uid 0, then finish handover-5 checklist items still open (audio playback test, GNSS
   fix test, camera still open).
5. **Setup wizard**: drive it via adb input taps (or skip) once rooted properly.
6. **OTA packaging + release**: follow handover-5 items 4-5 (rebuild matched
   recovery/vbmeta, publish first Nopenix release, update releases/ + ROADMAP.md).
7. **Push device-tree fixes to forks** only after v13 is confirmed working on device
   (AGENTS.md rule 6): SPOOF_SAFETYNET fix, manifest.xml VINTF fix, bluetooth glue,
   gen_build_prop.py ro.secure change (that one is in build/ — NOT a fork we own; crDroid
   source. Decide then whether it stays a local patch).
