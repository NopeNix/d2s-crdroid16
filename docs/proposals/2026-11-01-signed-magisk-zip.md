# Proposal: Nopenix Signed Magisk Zip (official workstream, 2026-11-01)

> Status: APPROVED by owner 2026-11-01 (supersedes the rootless-only reading of
> the 2026-10-30 Magisk out-of-scope decision *for this artifact only* — see
> "Policy resolution" below). Prod ROM builds themselves stay rootless.

## Why

crDroid's own recovery only accepts packages signed with the Nopenix key set
(`docs/signing.md`). A stock Magisk APK/zip is signed by topjohnwu and is
rejected by `adb sideload`. Since we hold the keys, we ship a **flashable zip
containing a Magisk-patched boot.img, signed with our releasekey** — sideloadable
from our own recovery, no TWRP required, rebuilt automatically with every build
so it always matches the ROM it was made from.

## Design

### Zip layout

```
META-INF/com/google/android/update-binary     # POSIX shell script (we write it)
META-INF/com/google/android/updater-script    # minimal edify
magisk_new/boot.img                           # Magisk-patched boot image
magisk_new/magisk_version                     # e.g. "28.1"
```

- The zip is a plain shell-script package (not edify-driven), so `update-binary`
  does the real work; the updater-script is only the stub recovery prints about.
- Signed with `apksigner`-style `signapk.jar` (platform `releasekey.pk8` +
  `releasekey.x509.pem` from `~/.android-certs/`) — same key chain the recovery
  trusts, hence sideloadable on both dev and prod installs.

### Boot-image patching (build-time, headless)

1. Extract `boot.img` from the **signed target-files** zip (`IMAGES/boot.img`).
2. Run `magiskboot` (from the pinned Magisk release, see pinning below):
   `unpack boot.img` → inject `magiskinit`, `magisk64`, `magisk32`, `stub.xz`,
   `config` → `repack`. This reproduces exactly what the Magisk app's
   "Select and Patch a File" does, headlessly.
3. The resulting `boot.img` goes into the zip; the **ROM's own OTA still ships
   the unpatched boot** — Magisk is strictly opt-in by sideload, per line.

### update-binary safety rails

- **Abort on foreign ROMs**: read `ro.product.vendor.device` / fingerprint props;
  refuse to run unless the target boots a Nopenix image (mismatched boot = brick
  risk on d2s, A-only system-as-root — no slot fallback).
- **Dev (ro.nopenix.variant=dev)**: proceed silently.
- **Prod (ro.nopenix.variant=prod)**: print a prominent warning — "this is the
  prod/rootless daily driver; flashing Magisk roots it; the next OTA removes
  root; SELinux must stay enforcing" — then proceed. This is the owner's
  documented choice (see Policy resolution).
- Never touches userdata (sideload of this zip is not a destructive op — no
  rule-9 gate needed).

### Pinning / reproducibility

- Magisk version is PINNED in `scripts/make-magisk-zip.sh` (tag + sha256 of the
  release file, verified before use). Bumping the pin is a deliberate one-line
  change, recorded in the release note.
- Toolchain: `magiskboot` + `magiskinit` + stub assets extracted from the pinned
  Magisk APK (it is a zip; the binaries live under `lib/arm64-v8a/` /
  `assets/`). Cached on the build host under `/srv/android/magisk-toolchain/`.

## Policy resolution (owner decisions on record)

1. **Flashable on BOTH lines** (owner, 2026-11-01): the zip is sideloadable on a
   dev OR a prod install. Signature-wise this is automatic — both lines share
   the same Nopenix keys (`docs/signing.md`), so the recovery accepts the zip
   either way; the update-binary warning/proceed logic (above) is our seatbelt.
2. **Never served as a channel entry**: `ota/prod.json` and `ota/dev.json` never
   reference the magisk zip (the Updater would offer it as a normal update —
   wrong direction). It exists ONLY as a GitHub release asset. Flashing it on
   prod is the owner's explicit, manual, per-occurrence choice.
3. **Prod stays rootless at build time**: `WITH_SU=false`, no debug knobs, no
   Magisk inside the prod image (unchanged from 2026-10-30). This workstream
   adds an *opt-in artifact*, not a rooted prod build.
4. **Standing requirements still apply if flashed on prod**: SELinux stays
   enforcing; banking-app behavior on a rooted prod is untested/known-risk;
   Play Integrity is already lost on this hardware regardless.

## Re-flash after every OTA (important)

Every Nopenix OTA (dev or prod) ships its own unpatched boot.img and therefore
**removes Magisk root on the first reboot after the update**. The matching
magisk zip must be re-sideloaded after every update. Documented in
`docs/release.md` and every release note.

## Deliverables / wiring

- `scripts/make-magisk-zip.sh` — new. Assemble + sign + sha256 the zip; takes
  the signed TF zip as input; dev- and prod-friendly (same artifact either way).
- `scripts/nopenix-build.sh` — run the magisk-zip step per variant, stage the
  zip next to the OTA/recovery artifacts with the standard naming.
- `.github/workflows/nopenix-build.yml` — no functional change needed (the
  canonical script does the work; staging stays the CI stop point).
- `docs/signing.md` — new section: flashable-zip signing (key used, command).
- `docs/release.md` + `releases/README.md` — asset list gains the magisk zip
  (dev and prod releases both carry it); re-sideload reminder.

## Acceptance criteria

- [ ] `make-magisk-zip.sh` produces a zip that our recovery accepts via
      `adb sideload` (verified on-device).
- [ ] Zip aborts on a foreign ROM (test: attempt on stock — expect refusal).
- [ ] Zip warns on prod, proceeds on dev (verified on-device).
- [ ] `sha256sum` of the zip recorded in the release note.
- [ ] No ota/*.json entry ever references the magisk zip.
