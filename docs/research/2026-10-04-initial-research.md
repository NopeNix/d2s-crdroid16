# Research notes — 2026-10-04 (initial research session)

Append-only. Each session adds a dated section. These are raw findings backing docs/history.md.

## 2026-10-04

- Initial device confusion: user first thought "d2s" might be Galaxy A10s; research began
  on a10/A10s (SM-A107F, MT6762) — WRONG device. User corrected: d2s = Galaxy Note10+ EU
  (SM-N975F). All research redone; history.md reflects the correct device.
- Verified live via GitHub API: crdroidandroid/android_device_samsung_d2s (branches
  12.0–16.0), android_device_samsung_exynos9820-common (same), android_kernel_samsung_exynos9820 (same).
- crdroidandroid/vendor-named repos redirect: android_vendor_samsung_d2s →
  proprietary_vendor_samsung_d2s (renamed repo), branches 13.0/14.0 only; common variant branch 13.0 only.
- TheMuppets proprietary_vendor_samsung_d2s + _exynos9820-common have lineage-20 …
  lineage-23.2 branches → blob source decision (docs/blob-strategy.md).
- exynos9820-common lineage.dependencies lists 8 LineageOS dependency repos
  (slsi_sepolicy, hardware/samsung, 6x slsi-linaro) — encoded into manifests/nopenix.xml.
- crdroidandroid/android branch 16.0: default.xml = Lineage lineage-23.2 + AOSP
  android-16.0.0_r4; snippets/crdroid.xml overrides core repos; snippets also for kernels
  and lineage additions. Build README documents repo init + brunch flow.
- OTA JSON for d2s verified (crdroidandroid/android_vendor_crDroidOTA@16.0/d2s.json):
  maintainer deuspivete, last build 2026-04-26 v12.9, sha256 + sourceforge link recorded in history.md.
- d2s_changelog.txt read back to Dec 2025: monthly builds, FrEeRuNnErKeRnEl kernel used in
  most 2026 builds, final build switched to stock kernel. VoLTE/VoWiFi never working.
- Lineage Updater app JSON schema + lineage.updater.uri prop verified from
  crdroidandroid/android_packages_apps_Updater README (and LineageOS equivalent).
  [LATER CORRECTION 2026-10-26]: the crDroid 16 Updater rewrite does NOT read
  `lineage.updater.uri` — it reads the `updater_server_url` resource only; and the
  live JSON schema is flat `{"response":[...]}`, not the README's nested `files[]`.
  See docs/ota.md + handover-9.
- XDA thread 4714988 confirms official N10-series crDroid 12 (A16) thread by deuspivete;
  changelog posts match the GitHub changelog file.
- GitHub runner limits researched: ~84 GB disk / ~7 GB RAM / 6 h — insufficient for this
  build; local build + manual release push decided.
