# Release: nopenix-13.0-20261030 (PROD, first prod build)

> **Status: PUBLISHED to GitHub Releases + `ota/prod.json` (2026-10-30).** DoD
> gate CLOSED 2026-10-30: Setup Wizard done, owner functional pass GREEN
> (incl. call audio — ABOX watch item benign). Magisk + Zygisk denylist +
> banking apps OUT OF SCOPE for this build (owner decision 2026-10-30): the
> 20261030 prod build runs rootless. Note: `docs/dev-prod.md` previously
> described prod as rooted-by-design — see the dated note there.

## Build facts

| Field | Value |
|---|---|
| Zip | `nopenix-13.0-20261030-d2s.zip` |
| Size | 1,514,693,730 bytes |
| SHA-256 | `e0e7b924cb91a56ca4837e883b1764ff81af2fe02a2fa0ec24442573152bf993` |
| Post-timestamp | `1793395784` (2026-10-30 21:29 UTC build) |
| SPL / SDK | 2026-10-01 / 36 |
| Buildtype | Release (prod channel) |
| Variant | `ro.nopenix.variant=prod` |
| Base | crDroid 16.0 / Lineage 23.2, **user flavor** (first prod line build ever) |
| Includes | Audio fix (`1d502b6`, SLSI primary HAL now built — see handover-13) |
| | **Updater channel fix** (d2s `88bd604`: Updater RRO now bakes `ota/prod.json` for prod — see below) |

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

### Watch item (first prod boot) — **RESOLVED 2026-10-30**

`audio_hw_proxy: cannot find ABOX Spk AmpL Power Mixer Control` (8×) — proxy
HAL misses one amplifier mixer control. Media playback routes fine. **Owner
functional pass (2026-10-30) green incl. call audio** — no speakerphone/in-call
impact; do NOT open an `exynos9820-common` investigation for this.

## Prod DoD checklist (docs/dev-prod.md) — live tracking

- [x] Patch level == latest upstream ASB (2026-10-01, matches dev line)
- [x] Non-debug internals (no dup-sysprop hooks, SELinux enforcing confirmed)
- [x] ~~Magisk installed + Zygisk denylist configured for banking apps~~ **OUT OF SCOPE** (owner decision 2026-10-30: prod runs without root; no banking-app root hiding needed)
- [x] Subsystem checklist green (owner functional pass 2026-10-30: call audio GREEN — ABOX watch item benign; BT, camera, GNSS, S-Pen, WiFi/LTE all working)
- [x] ~~Owner's banking apps tested~~ **OUT OF SCOPE** (no Magisk/denylist ⇒ no banking-app testing applicable)
- [x] OTA JSON published to prod.json (2026-10-30); in-place OTA install VERIFIED on device (ts 1793395784 build installed via Updater, rebooted clean)
- [x] GitHub release `nopenix-13.0-20261030` published (zip + recovery.img)
- [x] Release note (this file)

## Artifacts on host

- OTA zip: `/srv/android/ota61/nopenix-13.0-20261030-d2s.zip`
- Signed TF: `/srv/android/nopenix-d2s/out/signed-target-files.zip` (hyphen)
- Signed recovery: `/srv/android/nopenix-d2s/out/Nopenix-recovery-signed.img`
- STALE pre-audio-fix prod zip archived as
  `/srv/android/ota61/STALE-audio-broken-20261029-d2s.zip` (do NOT publish)
- STALE first prod zip (baked dev.json channel URL — the bug this rebuild
  fixes) archived as `/srv/android/ota61/STALE-dev-channel-baked-20261030-d2s.zip`

## Updater channel fix + rebuild (same day, second prod build)

Root cause of the missed prod.json update: `nopenix.mk` computed the channel
URL into `NOPENIX_OTA_URI` but never consumed it — the overlay `strings.xml`
was hardcoded to `ota/dev.json`, so EVERY build (prod included) baked the dev
channel into the Updater auto-RRO. Proven via `strings` on the signed-TF RRO.

Fix (d2s `88bd604`): channel-specific overlay dirs
`overlay/updater/{dev,prod}/packages/apps/Updater/.../strings.xml`, selected
via `DEVICE_PACKAGE_OVERLAYS` in `nopenix.mk`. NOTE: the overlay path must
mirror the target package's source path or aapt2 silently drops the override
(first rebuild had this; caught by the new check script).

New mandatory pre-publish gate: `scripts/verify-ota-channel.sh <signed-tf>
<channel>` (wired as `run-sign-prod.sh` stage 5) — asserts the Updater RRO
bakes the intended channel URL; FAILs on mismatch, missing URL, or conflicting
URLs. It caught both failure modes above before publish.

## OTA install (VERIFIED 2026-10-30/31, on device)

1. DONE: phone (running the stale dev-channel-baked prod build, ts 1793366117)
   polled `ota/dev.json`, was offered this build via a temporary dev.json
   transition entry (same filename/sha/ts 1793395784), installed it via the
   Updater, rebooted clean.
2. DONE: post-OTA on-device verification — ts 1793395784 running,
   `/vendor/overlay/Updater__*.apk` bakes ota/prod.json, 0 crashes/ANRs/
   tombstones/avc denials, SELinux enforcing, LTE IN_SERVICE (Telekom), audio
   routing healthy. Data preserved.
3. DONE: transition entry removed from dev.json. The phone is a
   prod-channel device permanently.
