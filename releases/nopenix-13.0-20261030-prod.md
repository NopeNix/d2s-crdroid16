# Release: nopenix-13.0-20261030 (PROD, first prod build)

> **Status: FLASHED on device, verification IN PROGRESS.** Not yet published to
> GitHub Releases / `ota/prod.json` — prod DoD gate still open (Magisk + denylist
> pending, banking-app tests pending, full subsystem sign-off pending).
> This note is the draft record of the build; publish items get ticked when done.

## Build facts

| Field | Value |
|---|---|
| Zip | `nopenix-13.0-20261030-d2s.zip` |
| Size | 1,514,692,112 bytes |
| SHA-256 | `b8dd62f64de4caf07b7b70f5cc73724d8715222ee5e7e0d2e086d45aac924511` |
| Post-timestamp | `1793366117` (2026-10-30 13:15 UTC build) |
| SPL / SDK | 2026-10-01 / 36 |
| Buildtype | Release (prod channel) |
| Variant | `ro.nopenix.variant=prod` |
| Base | crDroid 16.0 / Lineage 23.2, **user flavor** (first prod line build ever) |
| Includes | Audio fix (`1d502b6`, SLSI primary HAL now built — see handover-13) |

## Hardening verification (on-device, post-flash)

- `ro.build.type=user`, `ro.secure=1`, `ro.debuggable=0`, `ro.adb.secure=1`
- `ro.nopenix.variant=prod`, `ro.nopenix.version=13.0`, `ro.lineage.build.version=23.2`
- SELinux **Enforcing**; `ro.control_privapp_permissions=enforce`
- `init.debug.rc` ABSENT; no `WITH_SU` (no su, no adb_root service)
- adb requires RSA auth (owner authorized)
- 2 SELinux denials total, both from agent's own shell probes — system clean

## Flash log (agent-driven, 2026-10-30)

1. Reboot to recovery via `adb reboot recovery` from system (dev 20261030 build).
2. Owner-authorized wipe of /data (fresh f2fs on sda32) — policy: wipe entering
   prod (docs/dev-prod.md). NOTE: recovery itself also asks for confirmation of
   the data wipe — second independent consent gate, good.
3. Pushed signed OTA in 4 × 400 MB chunks (46 MB/s), per-chunk md5 verified,
   assembled on-device, full-zip sha256 matched host.
4. `update-binary` run detached (fd3 progress pipe): **script succeeded**;
   system/vendor/product/odm/vbmeta patched.
5. Flash artifacts removed from /data; rebooted into prod.
6. Owner completed recovery wipe prompt + enabled adb + authorized RSA.

## Subsystem status at first boot (pre-Setup-Wizard)

- Audio: **SLSI HAL routing active** (`audio_hw_primary`: routes to speaker for
  media, standby transitions, PCM paths). Owner to confirm by ear.
- LTE IN_SERVICE (Telekom.de, voice+data HOME, VoLTE supported), WiFi up,
  35/35 sensors running, camera 0/1/2 enumerated, GNSS bound.
- No crashes/ANRs/tombstones; SYSTEM_LAST_KMSG clean (normal watchdog shutdown).
- Log noise = Setup-Wizard-not-run-yet (provider misses) + transient adbd_auth —
  expected on first boot, clears after setup.

### Watch item (first prod boot)

`audio_hw_proxy: cannot find ABOX Spk AmpL Power Mixer Control` (8×) — proxy
HAL misses one amplifier mixer control. Media playback routes fine; possible
impact: speakerphone/in-call volume path. Verify during a call; investigate in
`exynos9820-common` if in-call audio is off.

## Prod DoD checklist (docs/dev-prod.md) — live tracking

- [x] Patch level == latest upstream ASB (2026-10-01, matches dev line)
- [x] Non-debug internals (no dup-sysprop hooks, SELinux enforcing confirmed)
- [ ] Magisk installed + Zygisk denylist configured for banking apps
- [ ] Subsystem checklist green (owner functional pass incl. call audio watch item)
- [ ] Owner's banking apps tested; results recorded here
- [ ] OTA JSON published to prod.json; Updater installs it in place
- [x] Release note (this file)

## Artifacts on host

- OTA zip: `/srv/android/ota61/nopenix-13.0-20261030-d2s.zip`
- Signed TF: `/srv/android/nopenix-d2s/out/signed-target-files.zip` (hyphen)
- Signed recovery: `/srv/android/nopenix-d2s/out/Nopenix-recovery-signed.img`
- STALE pre-audio-fix prod zip archived as
  `/srv/android/ota61/STALE-audio-broken-20261029-d2s.zip` (do NOT publish)
