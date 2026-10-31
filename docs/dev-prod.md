# Dev / Prod two-line build policy (decided 2026-10-26)

> Supersedes `docs/daily-driver.md` as the target statement (that file's daily-driver
> content is folded in here). Both lines serve one physical phone: the owner's
> Samsung Galaxy Note10+ (d2s).

## The two lines

### Dev line — the playground (CURRENT MAIN GOAL)

- **Purpose**: diagnose and test everything we need, with as little human
  interaction as possible. Intentionally insecure: **it is designed as a
  playground and never holds sensitive data.** No security hardening required.
- Base: `userdebug` + `BUILD_BROKEN_DUP_SYSPROP=true` (the flash-day debug knobs:
  adb-root works, dup-sysprop escape hatch on, `ro.secure` handling per the
  gen_build_prop.py patch in `build/soong/scripts/gen_build_prop.py`).
- **OTA channel is part of dev**: dev builds ARE published to the dev OTA channel —
  we must be able to debug Updater/OTA flow on the dev line. (Corrections to the
  earlier "dev never publishes" idea: wrong, OTA needs dev traffic.)
- Human-in-the-loop gates are accepted: where a step needs the human (boot to
  recovery, enable adb, accept RSA prompt, tap Allow), the agent asks and the human
  performs it. Everything else is automated.
- Dev builds are identified by `ro.nopenix.variant=dev` and OTA type `nightly`.

### Prod line — the daily driver

- **Purpose**: the owner's personal phone — banking apps, real SIM, real data.
- ⚠️ **2026-10-30 owner decision — POLICY UPDATE**: Magisk + Zygisk denylist +
  banking-app root hiding are **OUT OF SCOPE for prod**. The 20261030 prod
  build runs rootless and passed its full functional gate (call audio green).
  The rooted-by-design stance below describes the OLD 12.9-era posture and is
  kept for history — do NOT re-introduce Magisk without a fresh owner decision.
- Base: hardened image. Historical posture (crDroid 12.9 era, superseded):
  - Rooted, root hidden with crDroid built-in stealth + Magisk's own hiding
    (Zygisk denylist for banking apps). Banking worked in that state.
  - Play Integrity is already lost (unlocked bootloader + custom keys).
  - **SELinux stays enforcing** on prod, including with Magisk.
  - Never publish permissive variants of prod.
- Owner **encrypts the device whenever prod is in use** (FBE / standard Android
  disk encryption at first boot with screen lock).
- Prod builds are identified by `ro.nopenix.variant=prod` and OTA type `release`.

## Hard requirements (both lines unless noted)

1. **Security patch level tracks crDroid 16.0 upstream ASB cadence.** Dev carries
   new patch levels first; prod follows once dev proved them. A stale patch level
   is a release blocker for prod.
2. **Subsystem checklist** before any build is declared "working": BT, LTE, WiFi,
   audio, sensors, S-Pen, camera, GNSS (see v13 verification, 2026-10-26, in
   MEMORY.md — all green except GNSS-outdoor not yet tested).
3. **Signing**: both lines use the same Nopenix key set (see `docs/signing.md`).
   NOTE (honest policy statement): dev/prod separation is enforced by OTA channels
   and discipline, NOT by different signatures — a dev zip can be flashed over a
   prod install. Single-phone project; accepted.
4. **Debug-only hacks never ship in prod**: the dup-sysprop escape hatch,
   adb-root enablement, and any flash-day debugging hooks stay out of prod builds.

## OTA channel design

- Two JSON files in this repo: `ota/dev.json` (type `nightly` entries) and
  `ota/prod.json` (type `release` entries).
- Devices point at their channel via the **`updater_server_url` string resource**
  baked into each line's build through a **channel-specific device-tree overlay**
  (`overlay/updater/{dev,prod}/…`, selected by `DEVICE_PACKAGE_OVERLAYS` in
  `nopenix.mk`; crDroid 16 Updater does NOT read the `lineage.updater.uri`
  runtime prop — verified 2026-10-26, see `docs/ota.md` + `docs/branding.md`).
  The baked channel is verified before every publish with
  `scripts/verify-ota-channel.sh <signed-tf> <channel>` (mandatory gate, wired
  into `run-sign-prod.sh` stage 5; added 2026-10-30 after the first prod build
  baked the dev URL — root cause: `NOPENIX_OTA_URI` was computed but never
  consumed).
- The Updater matches updates by **`timestamp` + `os_sdk_level`** (the JSON
  `version` field is display-only; the channel split is by URI) — verified
  2026-10-26, see `docs/ota.md`.
- **Release policy**: dev zips may be published to dev.json freely (that is the
  point); prod zips go to prod.json + GitHub Releases only after the
  Definition of done below.
- Naming: dev zips branded `nopenix-dev-*`, prod zips `nopenix-<version>-*`.

## Single-phone data discipline

Dev and prod are software lines; the hardware is one phone that also runs prod's
data. Rules:

- Before a dev session: confirm with the owner whether userdata is wiped or
  carried over. Default for the dev line: **wipe userdata on entering a dev
  session and again before returning to prod** (clean state, no sensitive data
  on dev, as designed). Owner may explicitly accept a carry-over session.
- Never publish to prod.json anything built from a dirty/experimental tree.
- ⚠️ 2026-10-30: **No Magisk on prod** (owner decision — see policy update above).
  After a prod OTA the new boot boots rootless by itself: **no Magisk re-patch
  is required**. The procedure below is retained only as historical reference /
  for a future owner decision to re-introduce root.

## Magisk procedure (prod) — HISTORICAL REFERENCE ONLY (no Magisk on prod, 2026-10-30)

Retained in case a future owner decision re-introduces root. Magisk is NOT
baked into the build. On-device install once per install, re-patch after OTA:

1. **First install** (once, per clean install): install the Magisk APK as a
   normal user app → Magisk → Install → **Direct Install (Recommended)** →
   reboot. This patches the current boot image in place; the original boot.img
   backup stays in `/data/adb/` (Magisk-managed).
2. **After every prod OTA** (d2s is non-A/B, so the Updater reboots straight
   into the new, unrooted boot): the OTA rewrites `boot`, which wipes the
   Magisk patch. Root comes back by opening Magisk → Install → **Direct
   Install** → reboot. Magisk app itself lives in `/data` and survives OTAs
   (as long as userdata is not wiped); Zygisk denylist config is app-side and
   also survives.
3. **If userdata is wiped** (e.g. returning from a dev session): reinstall the
   Magisk APK first (it is not in the OTA zip), then step 1.
4. **Banking apps**: Zygisk + denylist must be re-verified after each OTA; the
   prod release checklist records test results per build.
5. Emergency unroot: flash the unpatched boot.img from the matching target-files
   (available in the GitHub release assets) via recovery.

## Definition of done — prod (release gate)

- [x] Patch level == latest upstream ASB level (or documented gap)
- [x] Non-debug internals (no dup-sysprop hooks, SELinux enforcing confirmed)
- [x] ~~Magisk installed + Zygisk denylist configured for banking apps~~ **OUT OF SCOPE** (owner decision 2026-10-30 — prod runs without root; checklist template kept for future builds)
- [x] Subsystem checklist green (owner functional pass 2026-10-30, incl. call audio)
- [x] ~~Owner's banking apps tested~~ **OUT OF SCOPE** (no Magisk ⇒ no denylist testing applicable)
- [x] OTA JSON published to prod.json; Updater installs it in place (VERIFIED on device 2026-10-30)
- [x] Release note in `releases/` with sha256, patch level, app-test results

## Definition of done — dev (MET 2026-10-28)

- [x] Boots with all debug conveniences working (adb root = uid 0, no RSA friction)
- [x] Subsystem checklist green (BT/WiFi/LTE/sensors/S-Pen/camera/GNSS — GNSS
      outdoor confirmed by owner 2026-10-28)
- [x] OTA flow exercised on the dev channel: Updater found, downloaded, and
      installed round-3b in place (2026-10-28; Updater DB status=2,
      install_old_timestamp=1793135136, bootreason reboot,ota)
- [x] Root available for diagnosis (su + adb_root in dev builds, uid 0 verified)

## Sequencing (decided 2026-10-26)

**Current main goal: the PROD line** (dev is done, DoD met 2026-10-28, audio
fixed + owner-confirmed 2026-10-30). The next session's concrete task list is in
`docs/flash-day-handover-13.md`.
