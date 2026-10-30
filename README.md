# d2s-crdroid16 — Nopenix crDroid 16 for Galaxy Note10+ (d2s)

Community continuation of the official **crDroid 16 (Android 16) builds for the Samsung
Galaxy Note10+ (SM-N975F, codename `d2s`, Exynos 9825)**. The official maintainer
(deuspivete) stopped after the 2026-04-26 build (v12.9). This project rebuilds from the
same public sources, adds current Android security patches, brands the result **Nopenix**,
and serves OTA updates to the phone directly.

**Scope: security-patch continuation only. No new features.**

**Two build lines** (decided 2026-10-26, see `docs/dev-prod.md`): **dev** — an
open, intentionally insecure playground (userdebug, adb-root) that is the current
main goal; **prod** — the owner's hardened daily driver with Magisk root and
encrypted data, banking-app ready. Known limit (both): unlocked bootloader + custom
keys ⇒ Google Play Integrity cannot pass — accepted.

## Repo map

- `AGENTS.md` — entry point for AI agents (read first)
- `MEMORY.md` — append-only gotcha/pitfall log written by agents
- `docs/` — all documentation:
  - `history.md` — how the official crDroid d2s builds were made (research)
  - `blob-strategy.md` — which vendor-blob repos we use and why
  - `build-guide.md` — full local build walkthrough
  - `ota.md` — OTA server format, hosting, and the official-12.9 → Nopenix upgrade path
  - `branding.md` — where/how the "Nopenix" identity is injected
  - `signing.md` — keys, AVB, recovery trust
  - `device/` — device facts (specs, partitions, firmware)
  - `dev-prod.md` — the dev/prod two-line policy: channels, hardening, release gates
  - `daily-driver.md` — (superseded by dev-prod.md, kept for history)
  - `research/` — dated raw research notes (append-only)
  - `ROADMAP.md` — project status and next steps
- `manifests/nopenix.xml` — repo local-manifest (the missing piece the official maintainer never published)
- `scripts/` — sync / build / OTA-JSON helper scripts
- `releases/` — one markdown note per published Nopenix build

## The related fork repos (the actual ROM code)

`NopeNix/android_device_samsung_d2s`, `NopeNix/android_device_samsung_exynos9820-common`,
`NopeNix/android_kernel_samsung_exynos9820`, `NopeNix/proprietary_vendor_samsung_d2s`,
`NopeNix/proprietary_vendor_samsung_exynos9820-common` — all forks of `crdroidandroid/*`,
used at branch `16.0` (blobs: see `docs/blob-strategy.md`).

## Status

**DEV LINE COMPLETE (DoD met 2026-10-28; audio fixed + owner-confirmed 2026-10-30)**: SPL 2026-10-01, all subsystems green, Updater in-place OTA proven end-to-end (latest dev release installed in place 2026-10-30). Now: prod line per `docs/flash-day-handover-13.md`. See `docs/ROADMAP.md`.
