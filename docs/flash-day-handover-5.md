# Flash-Day Handover #5 — 2026-10-24 (READ THIS ONE — newest)

> **Status: FIRST FULL BOOT SUCCESS. Phone boots to a working home screen with adb, WiFi, LTE data, and SIM registration.** RIL/modem/cbd work (the Option-B build from `rea/STATUS.md`) is CONFIRMED WORKING on device.
> Newer than docs/flash-day-handover-4.md (that one covers the previous system_server hang / adb-unauthorized blockers).

## CURRENT STATE (verified on device)

### What works (2026-10-23 ~23:00–24:00 UTC)
- Full boot: kernel 4.14.356, boot animation → **home screen (Launcher3) renders**
- sys.boot_completed=1, no watchdog kills, no system_server hang
- **adb works in system** (unauthorized issue gone — was `SPOOF_SAFETYNET` in init, see "Root causes fixed this session")
- **WiFi**: wlan0 up, DHCP lease obtained, internet reachable via device
- **Mobile data + telephony registration**:
  - `cbd` (cpboot_v3, Option-B open-source build) and `rild` both running (uid radio)
  - `gsm.operator.alpha` = Telekom.de, `gsm.network.type` = LTE
  - `gsm.sim.operator.alpha` = fraenk, `gsm.sim.state` = LOADED
  - `gsm.version.baseband` = N975FXXS9HWH6, `ril.modem.board` = SHANNON5000
  - `gsm.version.ril-impl` = Samsung RIL v5.0
- Display HWC composition working, touch input works, EmergencyDialer screen rendered full-screen during setup wizard (was the visible screen at the time)
- f2fs /data persists across recovery↔system reboot cycles (files pushed there stay)
- Setup wizard (org.lineageos.setupwizard) launches on first boot and waits for user input — normal behavior

### Root causes fixed this session (both landed in v12 build at /srv/android/nopenix-d2s)
1. **adb "unauthorized"**: crDroid's `SPOOF_SAFETYNET` feature in init sets `ro.debuggable=0` + `ro.adb.secure=1` at runtime via `write` command in init's Android.bp `SPOOF_SAFETYNET` block — this **overrode** our device.mk `PRODUCT_SYSTEM_PROPERTIES ro.debuggable=1` (init props are write-once and init's write happens later than build.prop parsing). Fix: disable `SPOOF_SAFETYNET` in the device tree's init rc (or set `ro.debuggable=1` via a later init stage than SPOOF_SAFETYNET's). Verified: adb now returns success (no unauthorized) in system.
2. **system_server hang**: d2s lacks the sysfs nodes needed for the device tree's `IKeyDisabler` / `IAdaptiveBacklight` / other interfaces declared in `manifest.xml` (VINTF). HALs for those never registered (their service names weren't in servicemanager), but the VINTF manifest **claimed** they existed. `PhoneWindowManager.updateSettings()` then calls `waitForDeclaredService` on `vendor.lineage.touch.IKeyDisabler/default` and blocks forever → `WAITED_UNTIL_PRE_WATCHDOG` → system_server hang → boot loop. Fix: remove the unsupported interfaces from `manifest.xml` (the HALs don't exist on d2s). Verified: system_server starts normally, no hang, no watchdog.
   *(Full investigation trace: handover #4, "system_server hangs in early boot" + "Prime suspects".)*

### What's NOT yet done
- **adb root** still doesn't fully elevate (ro.secure=1 is emitted from gen_build_prop.sh for user builds — needs a small tweak to the device tree or `unsecure` flag in build config)
- Some cosmetic/subsystem checks still pending (see "Next steps")

## IMMEDIATE NEXT STEPS (in order)

1. **Verify remaining subsystems on device** (should all just work since HALs registered):
   - `ps -A | grep -E "sensors|camera|audio|bluetooth|gps"` — confirm HALs running
   - `dumpsys sensors` — confirm sensor list is populated
   - `dumpsys audio` / play a test sound / dial a test call
   - `dumpsys bluetooth` — confirm BT stack starts
   - `dumpsys location` / `gps` — confirm GNSS works
   - S-Pen on d2s: `dumpsys input` for pen events (S-Pen removal was an earlier session's change, may need testing)
   - Camera: open a camera app / `dumpsys media.camera`
2. **Setup wizard**: since adb works, drive it via adb (`adb shell input tap/keyevent`) or disable the wizard via adb if it blocks re-boot loops (only needed for OTA-from-WiFi testing, not for normal use)
3. **adb root / ro.secure**: if adb root is wanted for future debugging, patch gen_build_prop.sh or set `unsecure` in the build config (small change, not urgent)
4. **OTA packaging**: once subsystems verified, generate a final Nopenix-signed-ota.zip with the current working build (the one at /srv/android/flash-day/Nopenix-signed-ota.zip md5 b5e02f17 is v4, the one now running is v12 — rebuild+re-sign to have a matching artifact). Also generate Nopenix-recovery-signed.img + vbmeta-signed.img to match.
5. **Publish release**: once OTA is rebuilt, follow docs/release.md + docs/ota.md to publish v12.9-continuation as the first Nopenix release. Update releases/ dir + ROADMAP.md.
6. **Sync repo state**: the device tree fixes (SPOOF_SAFETYNET, manifest.xml VINTF fixes, device.mk ro.debuggable, etc.) live LOCAL-ONLY in /srv/android/nopenix-d2s — do NOT push yet (per AGENTS.md rule 6). When a working release is confirmed, commit the device-tree fixes to the NopeNix/* fork branches (16.0) via PR.

## Flash recipe (unchanged from handover #4 — reuse it verbatim)
Use the "Flash recipe (proven, use exactly this)" section in docs/flash-day-handover-4.md. It's been exercised 3x successfully. Key reminders:
- chunked adb push (400MB chunks) to /data + dd for super (sda25), boot, dtbo, vbmeta, recovery
- verify all md5s after push AND after dd read-back
- never heimdall for super
- TWRP is NOT usable for the OTA sideload — use our Lineage recovery (Nopenix-recovery-signed.img)
- fresh re-entry to Download Mode fixes heimdall handshake failures

## Key facts (carry forward — do NOT re-derive)
- super partition = /dev/block/sda25 = by-name/system. Vendor extent starts sector 4689920.
- userdata = sda32 (raw f2fs we formatted; files pushed there persist across recovery reboot)
- Signing keys: /home/user/.android-certs (10 RSA2048, CN=Nopenix Release). BACK THESE UP.
- Build tree: /srv/android/nopenix-d2s (LOCAL-ONLY fixes, do not push yet).
- Signing: /srv/android/sign-target.sh does sign_target_files_apks + ota_from_target_files + recovery extract.
- Phone: SM-N975F serial RF8MC0SAXCJ. In recovery with adb = ask user. Download mode = fresh re-entry fixes heimdall handshake.
- Build lineage for this session (v11→v12): all at /srv/android/nopenix-d2s, signed OTAs at /srv/android/flash-day/
- Baseband unchanged this session: N975FXXS9HWH6 (radio partition, shannon5000, SIPC protocol)

## Gotchas learned this session (append to MEMORY.md too)
- crDroid's `SPOOF_SAFETYNET` init feature **silently overrides** device.mk `PRODUCT_SYSTEM_PROPERTIES ro.debuggable=1` — the init rc runs AFTER build.prop parsing and props are write-once. Always check for `SPOOF_SAFETYNET` if a debuggable build comes out not-debuggable on device.
- **A VINTF manifest.xml that declares HALs whose nodes don't exist on the device** (e.g. copied from a device tree for a different IC) makes PhoneWindowManager block in `waitForDeclaredService` → system_server hang / boot loop. Symptom: `Waited one second for vendor.lineage.touch.IKeyDisabler/default` spam (82x) + `WAITED_UNTIL_PRE_WATCHDOG`. Always cross-check manifest.xml declared HALs against what the device's sysfs nodes actually support.
- f2fs /data files persist across recovery reboots even after `adb reboot recovery` — the f2fs is not re-mounted by the recovery and the contents stay intact (files pushed to /data in recovery can be read back from /data in system, and vice versa).
