# Signing — keys, AVB, and recovery trust

> To be executed at first-build time. This file documents the plan; update it with
> reality once done (ask user approval per AGENTS.md).

## Keys we need

Generate an AOSP cert set once, store in `~/.android-certs/` (OUTSIDE all repos):

```bash
cd <source root>
subject='/C=DE/ST=Bavaria/L=Nuremberg/O=NopeNix/OU=NopeNix/CN=Nopenix Release/[email protected]'
mkdir ~/.android-certs
for cert in bluetooth cyngn-app media networkstack nfc platform releasekey sdk_sandbox shared verity; do
  ./development/tools/make_key ~/.android-certs/$cert "$subject"
done
ln -sf releasekey.pk8 ~/.android-certs/testkey.pk8
ln -sf releasekey.x509.pem ~/.android-certs/testkey.x509.pem
```

(Adjust subject; the cert list is the LineageOS 19.1+ standard set per the LineageOS wiki.)

## Build-time wiring

- `vendor/lineage-priv/keys/` (gitignored / outside repo): copy pk8/x509.pem there and a
  `keys.mk` with `PRODUCT_DEFAULT_DEV_CERTIFICATE := vendor/lineage-priv/keys/releasekey`.
  Alternative: sign post-build with `sign_target_files_apks -o -d ~/.android-certs` (the
  LineageOS 19.1+ path, includes the long `--extra_apks` list — prefer the wiki procedure).
- AVB: Samsung d2s flow does not use AVB enforcement while bootloader-unlocked with
  vbmeta verification disabled at flash time. Set `BOARD_AVB_KEY_PATH` /
  `BOARD_AVB_ALGORITHM` only if we later ship a locked-bootloader path — out of scope for now.

## Recovery trust chain (why the first flash is manual)

- Official crDroid 12.9's recovery contains crDroid's release key(s) only.
- Our zips signed with Nopenix keys are rejected by that recovery → **the first Nopenix
  install must be: flash OUR recovery (built with our keys via `PRODUCT_EXTRA_RECOVERY_KEYS`
  / same cert dir), then adb sideload once.**
- All subsequent Nopenix → Nopenix updates work in-place through the Updater app
  (same signing key chain) — see `docs/ota.md`.

## Storage & hygiene

- `~/.android-certs/` never enters git. Back it up privately; losing it means every
  future OTA needs another manual sideload (new key = untrusted by installed recovery).
- Note in each release which key fingerprint signed it.

## Dev/prod stance (updated 2026-10-30; supersedes the 2026-10-26 "Magisk by design" stance)

- Both lines sign with the SAME Nopenix key set; dev/prod separation is enforced by
  OTA channels + discipline, not signatures (accepted, single-phone project).
- Own keys + unlocked bootloader ⇒ no Google Play Integrity — accepted.
- **PROD is rootless** (owner decision 2026-10-30: no Magisk, no denylist, no
  banking-app root hiding). Prod must NOT carry the flash-day debug hooks
  (dup-sysprop escape hatch, adb-root enablement); SELinux stays enforcing.
  The 2026-10-26 "PROD carries Magisk root by design" stance is historical.
