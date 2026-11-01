# Release: nopenix-13.0-20261031 (PROD)

> Second prod build. Same hardening posture as 20261030 (rootless, SELinux
> enforcing, user flavor). New: ships the **signed Magisk zip** release asset
> (official workstream 2026-11-01). Prod builds remain rootless — the magisk
> zip is an opt-in artifact, NEVER served via `ota/prod.json`; flashing it on
> the daily driver is the owner's explicit manual choice (the zip prints a
> prod warning on install).

## Build facts

| Field | Value |
|---|---|
| Zip | `nopenix-13.0-20261031-d2s.zip` |
| Size | 1,514,690,794 bytes |
| SHA-256 | `258c3175c224386b2791c73d30662a6dc92538dea169e2ee13f31627a7b9961e` |
| Post-timestamp | `1793455983` |
| SPL / SDK | 2026-10-01 / 36 |
| Buildtype | Release (prod channel) |
| Variant | `ro.nopenix.variant=prod` |
| Magisk zip | `Nopenix-magisk-v31.1-prod-20261031-d2s.zip` (sha256 `d03c1be302adf7c7caf0c70697dc9d679aba9e783d6508aced9db7bdd96d0288`) |
| Rooted OTA | `nopenix-13.0-20261031-d2s-ROOTED.zip` (sha256 `0441f304036012682dffca1f174ec0fc942414e47a69839871616284275c5b1d`) |

## Magisk zip notes (owner-facing)

- Sideloading it roots the phone; **as of the 2026-11-01 release-matrix decision
  this is no longer the primary root path** — prefer the `-ROOTED` OTA (root
  survives updates). The magisk zip stays as the auxiliary path to root an
  already-installed rootless build without a full OTA.
- SELinux must stay enforcing; banking apps on a rooted prod are untested —
  expect breakage, Play Integrity is already lost on this hardware anyway.

## ROOTED flavor (owner decision 2026-11-01)

- `nopenix-13.0-20261031-d2s-ROOTED.zip`: the SAME build with a Magisk-patched
  boot baked in (`scripts/make-rooted-ota.sh`). Installing it via Updater or
  sideload = root that survives future rooted OTAs. Unroot = install rootless.
- Offered via `ota/prod.json` as a second entry (`version: 23.2-rooted`);
  the Updater lists both flavors. Requires `crdroid.updater.allow_downgrading`
  (d2s fork `7df95c5`) — present from the NEXT build; on the current phone the
  rooted entry carries timestamp+60 so it stays selectable after either install.
- ✅ **On-device acceptance test DONE (owner, 2026-11-01)**: flashed
  `nopenix-13.0-20261031-d2s-ROOTED.zip` via recovery with ZERO errors; boots,
  `magiskd` running as root, Magisk app v31.1 "Installed", `/product/bin/su`
  present, SELinux Enforcing, incremental `1793461862` = ROOTED build.
