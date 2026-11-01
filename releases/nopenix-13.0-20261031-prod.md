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
| Magisk zip | `Nopenix-magisk-v31.1-prod-20261031-d2s.zip` (sha256 `e432822a3297907458fa3e45645d0aa17790f811bfcb1dbdbe43d97612421c8a`) |

## Magisk zip notes (owner-facing)

- Sideloading it roots the phone; the next OTA removes root again (re-sideload
  after updating).
- SELinux must stay enforcing; banking apps on a rooted prod are untested —
  expect breakage, Play Integrity is already lost on this hardware anyway.
- On-device acceptance test still PENDING — do the first prod sideload only
  with the current state backed up.
