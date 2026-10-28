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
- Base: hardened image **with root: Magisk is installed on prod by design.**
  - Owner's established, known-good posture from the crDroid 12.9 era: rooted,
    root hidden with crDroid built-in stealth + Magisk's own hiding
    (Zygisk denylist for banking apps). Banking worked in that state.
  - Play Integrity is already lost (unlocked bootloader + custom keys) — the
    marginal cost of Magisk is accepted. Root is NOT seen as contradicting the
    hardening goal; "full control, full security, full usability" is the target.
  - **SELinux stays enforcing** on prod, including with Magisk.
  - Never publish permissive or rootless variants of prod; the prod image is
    rooted-by-design.
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
  baked into each line's build as a device-tree overlay RRO (crDroid 16 Updater
  does NOT read the `lineage.updater.uri` runtime prop — verified 2026-10-26,
  see `docs/ota.md` + `docs/branding.md`).
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
- After every prod OTA: **Magisk re-patch of the boot image is required before
  reboot** (our OTA packages rewrite `boot`, which would boot unrooted and may
  break the Magisk-patched chain). This procedure must be documented in the
  flash recipe and followed every time. (d2s is non-A/B: dedicated recovery
  partition.)

## Definition of done — prod (release gate)

- [ ] Patch level == latest upstream ASB level (or documented gap)
- [ ] Non-debug internals (no dup-sysprop hooks, SELinux enforcing confirmed)
- [ ] Magisk installed + Zygisk denylist configured for banking apps
- [ ] Subsystem checklist green
- [ ] Owner's banking apps tested; results recorded in `releases/`
- [ ] OTA JSON published to prod.json; Updater installs it in place
- [ ] Release note in `releases/` with sha256, patch level, app-test results

## Definition of done — dev (MET 2026-10-28)

- [x] Boots with all debug conveniences working (adb root = uid 0, no RSA friction)
- [x] Subsystem checklist green (BT/WiFi/LTE/sensors/S-Pen/camera/GNSS — GNSS
      outdoor confirmed by owner 2026-10-28)
- [x] OTA flow exercised on the dev channel: Updater found, downloaded, and
      installed round-3b in place (2026-10-28; Updater DB status=2,
      install_old_timestamp=1793135136, bootreason reboot,ota)
- [x] Root available for diagnosis (su + adb_root in dev builds, uid 0 verified)

## Sequencing (decided 2026-10-26)

**Current main goal: get the DEV build fully working as desired. Only then move on
to prod.** Do not start prod work (hardening, Magisk wiring, prod channel) until
the dev Definition of done is met. The next session's concrete task list is in
`docs/flash-day-handover-10.md` + handover-11 notes.
