# Flash-Day Handover #14 — 2026-10-30 ~19:30 UTC (READ THIS ONE FIRST)

> Supersedes handover #13. **PROD LINE: FIRST PROD BUILD BUILT, FLASHED, BOOTED.**
> DoD gate open — Magisk + banking tests pending (§4). Audio detour CLOSED
> (handover-13); the audio fix is in this prod build.

> **⚠️ ADDENDUM (2026-10-30 ~23:00 UTC) — read after this header, before §4:**
> The §3 prod.json entry and §4 checklist below were overtaken by events the
> same evening. The first prod build baked the DEV channel URL (root cause:
> `NOPENIX_OTA_URI` computed but never consumed — Updater RRO hardcodes
> dev.json). Fixed in d2s `88bd604`, prod rebuilt+signed (ts 1793395784, sha
> e0e7b924…bf993), **verified on device via a real in-place OTA** (offered via
> a temporary dev.json transition entry, installed, rebooted clean, zero
> crashes; on-device RRO now bakes prod.json). prod.json + release assets are
> the NEW build; transition entry removed. New mandatory pre-publish gate:
> `scripts/verify-ota-channel.sh` (hub) = run-sign-prod.sh stage 5.
> Full story: `releases/nopenix-13.0-20261030-prod.md` §Updater-channel-fix.
> **§4 item 5 (publish) is DONE — remaining DoD: Magisk + denylist, owner
> functional pass (call audio!), banking tests. Item 6's Magisk re-patch
> applies once Magisk is installed.**

## TL;DR — STATE NOW

- Phone runs **nopenix prod 13.0, build 20261030** (user flavor, hardened):
  `ro.build.type=user`, `ro.secure=1`, `ro.debuggable=0`, `ro.adb.secure=1`,
  SELinux enforcing, `ro.nopenix.variant=prod`, `init.debug.rc` ABSENT,
  SPL 2026-10-01. Owner authorized adb (RSA) post-boot.
- **Audio fix included and confirmed working in logs** (SLSI `audio_hw_primary`
  routing active). Build post-timestamp 1793366117, sha256 b8dd62f6…24511.
- **NOT published yet**: no GitHub release, `ota/prod.json` still empty. That
  is deliberate — prod DoD gate (§4 below) must complete first.
- One **watch item**: `audio_hw_proxy: cannot find ABOX Spk AmpL Power Mixer
  Control` — check speakerphone/in-call audio before sign-off.

## 1. What happened this session (prod session #2)

1. **Rebuilt prod with the audio fix** (exynos9820-common `1d502b6` was already
   in the local tree). Build 2h22m (`run-tf-prod.sh` → tf-prod.log), pre-sign
   verification of the TF: audio HAL 32+64-bit present
   (`VENDOR/lib64/hw/audio.primary.universal9825.so`, `libaudio-ril.so`,
   `libaudioproxy.so`, `mixer_paths.xml`) + all prod props green.
2. **Fixed the sign script stage-4 typo** (handover-12 gotcha): recovery.img now
   extracted from the HYPHEN zip (`out/signed-target-files.zip`); the
   underscore zip is stale dev.
3. **Signed** (~30 min; `run-sign-prod.sh` → sign-prod.log): STAGE2_RC=0,
   STAGE3_RC=0, ALL_DONE. Signed TF re-verified (variant=prod, user flavor,
   init.debug.rc absent, audio HAL present).
4. **Archived the stale pre-audio-fix prod zip** as
   `/srv/android/ota61/STALE-audio-broken-20261029-d2s.zip` (never publish it).
5. **Staged** `/srv/android/ota61/nopenix-13.0-20261030-d2s.zip`
   (1,514,692,112 bytes, sha256 b8dd62f64de4caf07b7b70f5cc73724d8715222ee5e7e0d2e086d45aac924511).
6. **Generated the prod.json entry** via `scripts/ota-json.sh <zip> 23.2 Release`
   (timestamp 1793366117 from signed metadata). Ready to append at publish.
7. **FLASHED dev→prod** (agent-driven, owner-in-the-loop at 2 gates):
   - `adb reboot recovery` from system; adb root works in recovery (uid 0).
   - **/data wiped** (fresh f2fs on sda32) WITH explicit owner OK (new standing
     rule: ALWAYS ask the owner before wiping /data — recorded in MEMORY.md).
   - Recovery ALSO asked the owner to confirm data deletion (second gate).
   - Pushed 4 × 400 MB chunks (46 MB/s), per-chunk md5 OK, assembled on
     device, full sha256 matched host.
   - update-binary detached run → **script succeeded** (system, vendor,
     product, odm, vbmeta patched). Flash artifacts cleaned from /data.
   - `adb reboot` from recovery loops back into recovery (quirk) — owner
     rebooted to system from the recovery menu instead.
8. **First prod boot verified** (adb): all props per TL;DR + audio HAL routing
   active, LTE IN_SERVICE (Telekom), WiFi up, 35/35 sensors, cameras enumerated,
   GNSS bound, ZERO crashes/ANRs/tombstones, SELinux denials: only 2 (agent's
   own shell).
9. **Full log audit** (18,350 lines): everything benign (setup-wizard noise,
   transient adbd_auth, self-fixing SmsApplication perms) EXCEPT the ABOX
   Spk AmpL watch item above.

## 2. Environment facts (stable, re-verified this session)

- Build wrappers: `/srv/android/run-tf-prod.sh` (prod), `/srv/android/run-tf61.sh`
  (dev), sign: `/srv/android/run-sign-prod.sh` (prod, FIXED stage-4) and
  `run-sign61.sh` (dev). Logs: tf-prod.log / sign-prod.log in /srv/android.
- Chunked-flash workspace: `/srv/android/prod-flash/` (split -b 400M -d,
  host-md5.txt pattern).
- d2s non-A/B: recovery = sda15, misc = sda19, userdata = sda32 (f2fs).
- `dd`/`head` on /dev/block/sda19 from recovery shell (uid 2000) → Permission
  denied; `adb root` in recovery restarts adbd which then DROPS OFF adb and
  doesn't return — do NOT call `adb root` twice in recovery; work with the
  first uid-0 session or use the menu (owner present).

## 3. ota/prod.json entry (copy-paste ready, publish AFTER DoD)

```json
{
  "maintainer": "Nopenix",
  "oem": "Samsung",
  "device": "Galaxy Note10+",
  "filename": "nopenix-13.0-20261030-d2s.zip",
  "download": "https://github.com/NopeNix/d2s-crdroid16/releases/latest/download/nopenix-13.0-20261030-d2s.zip",
  "timestamp": 1793366117,
  "sha256": "b8dd62f64de4caf07b7b70f5cc73724d8715222ee5e7e0d2e086d45aac924511",
  "size": 1514692112,
  "version": "23.2",
  "buildtype": "Release",
  "os_patch_level": "2026-10-01",
  "os_sdk_level": 36
}
```

Release note draft: `releases/nopenix-13.0-20261030-prod.md` (tick the DoD
boxes as they complete).

## 4. NEXT SESSION — finish the prod DoD gate

1. **Owner: complete Setup Wizard** on the phone (cuts ~5.5k benign log errors).
2. **Owner: Magisk Direct Install + Zygisk denylist** for banking apps
   (docs/dev-prod.md "Magisk procedure"). Verify root + denylist afterwards
   (banking app test = denylist proof).
3. **Owner: functional pass** — call audio (esp. speakerphone — the ABOX
   watch item), BT, camera, GNSS (outdoor), S-Pen, WiFi/LTE speed sanity.
4. **Agent: record results** in `releases/nopenix-13.0-20261030-prod.md`,
   tick DoD boxes.
5. **Agent: publish** (only when gate green): GitHub release
   `nopenix-13.0-20261030` with the zip + recovery.img (upload detached:
   `nohup setsid gh release upload … --clobber > log &`, verify byte-accuracy),
   append the §3 entry to `ota/prod.json`, push hub main.
6. Future prod OTAs now flow via Updater in place (chain proven on dev);
   **remember Magisk re-patch after every prod OTA reboot**.

## 5. Rules that bit us this session (already in MEMORY.md, keep applying)

- ALWAYS ask owner permission before wiping /data (standing rule, 2026-10-30).
- Verify mtime + variant props of BOTH TF and signed output before trusting a
  sign stage (hyphen/underscore incident).
- OTA JSON timestamp = signed META-INF post-timestamp, never file mtime.
- `adb reboot` from recovery may loop back to recovery — hand the final reboot
  to the owner at the recovery menu.
