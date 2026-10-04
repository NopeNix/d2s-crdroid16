# How the official crDroid d2s builds were made (research, verified 2026-10-04)

This is the ground truth this project builds on. Every claim here was verified against
the live repos/pages on 2026-10-04 unless marked "unverified".

## Device

| Fact | Value |
|---|---|
| Marketing name | Samsung Galaxy Note10+ |
| Model | SM-N975F / SM-N975F/DS (EU edition is N975F) |
| Codename | `d2s` |
| SoC | Exynos 9825 (family common tree: exynos9820, covering 9820/9825) |
| Not to be confused with | Galaxy A10 (`a10`, Exynos 7885) / Galaxy A10s (SM-A107F, MT6762) |
| LineageOS official | Yes — wiki: https://wiki.lineageos.org/devices/d2s/ |
| Fingerprint | In-display (FOD), TARGET_HAVE_FOD := true |
| S Pen | Supported (TARGET_HAVE_SPEN := true) |

## The official ROM

- **Version**: crDroid v12.x = Android 16 (crDroid `16.0` branch), official device page:
  https://crdroid.net/d2s/12 — the page itself now shows "outdated or no longer supported".
- **Maintainer**: Pedro Araujo, GitHub/Telegram handle **deuspivete**
  (telegram: https://t.me/metamorfoseado). Verified via the OTA JSON `d2s.json` in
  `crdroidandroid/android_vendor_crDroidOTA` branch `16.0` and his XDA thread
  "[ROM][OFFICIAL][16] UPDATE crDroid 12 N10 Series [AOSP][ENCRYPTION]" (thread 4714988).
  Note: **FreeRunner2017** is a different (earlier) Note10-series maintainer — do not mix them up.
- **Last official build**: `crDroidAndroid-16.0-20260426-d2s-v12.9.zip`
  (1,512,496,634 bytes; sha256 008ce86137ef49fd25e1334714cead364aec41681e6b3e85eef7e492095bd02d)
  hosted at sourceforge.net/projects/crdroid/files/d2s/12.x/ — downloads for all monthly
  builds 12.5→12.9 (2026-01-11 → 2026-04-26) still live.
- **Recovery** for install/updates also published there: `d2s/12.x/recovery/recovery.img`.
- **Changelog**: `crdroidandroid/android_vendor_crDroidOTA`, branch `16.0`, file `d2s_changelog.txt`.
  Final entries: 26-04-2026 ("Sync with latest source, Introduce Sandbox, Reworked
  TrickyStore & Play Integrity Fix, **Switch to stock kernel**"), 12-04-2026
  ("FrEeRuNnErKeRnEl latest changes"), 28-03-2026 ("Android 16 - March 2026 Security updates").
- **Known issue** (documented across all these builds): VoLTE / VoWiFi do not work on the
  exynos9820 family.

## Source layout (verified)

`crdroidandroid/android` branch `16.0` is the repo manifest:
- `default.xml`: base LineageOS `lineage-23.2` + AOSP pinned at `refs/tags/android-16.0.0_r4`.
- `snippets/crdroid.xml`: overrides ~40 core repos (frameworks/base, build, packages/apps/*
  incl. `packages/apps/Updater`, `bootable/recovery`, lineage-sdk, …) with `crdroidandroid/*`
  forks at `refs/heads/16.0`. Additional snippets: `kernel-6.x.xml`, `lineage.xml`.
- Build README (`README.mkdn`): `repo init -u https://github.com/crdroidandroid/android.git -b 16.0 --git-lfs --no-clone-bundle`,
  then `repo sync`, then `. build/envsetup.sh && brunch <device>`.

Device stack (all verified live, branches `16.0`):

| Layer | Repo | Notes |
|---|---|---|
| Device tree | `crdroidandroid/android_device_samsung_d2s` | last real change Jan 2025 ("CrDroid 15" rename commit); stable carry-over to 16.0 |
| Common tree | `crdroidandroid/android_device_samsung_exynos9820-common` | actively maintained thru Feb 2026 on 16.0: NFC AIDL HAL switch, common SPenActions app/SPen service, libssl pinned from VNDK 33 for gpsd, audio mixer_paths fixes |
| Kernel | `crdroidandroid/android_kernel_samsung_exynos9820` | 16.0; changelog shows builds switched between FrEeRuNnErKeRnEl (custom, KernelSU-next) and **stock kernel** — the final v12.9 used stock |
| d2s blobs | `crdroidandroid/proprietary_vendor_samsung_d2s` | **branches only 13.0 / 14.0** — lags the 23.2 base |
| common blobs | `crdroidandroid/proprietary_vendor_samsung_exynos9820-common` | **branch only 13.0** |
| HW deps | `LineageOS/android_device_samsung_slsi_sepolicy`, `LineageOS/android_hardware_samsung`, `LineageOS/android_hardware_samsung_slsi-linaro_{config,exynos,exynos5,graphics,interfaces,openmax}` | referenced via the common tree's `lineage.dependencies`; use `lineage-23.2` |

Device-tree details (from the repos themselves):
- `lineage_d2s.mk`: PRODUCT_NAME `lineage_d2s`, PRODUCT_MODEL SM-N975F, inherits
  `device/samsung/d2s/device.mk` → `device/samsung/exynos9820-common/exynos9825.mk`,
  and `vendor/samsung/d2s/d2s-vendor.mk`. crDroid flags set inline (Aperture camera, UDFPS,
  blur, face unlock, quick tap, …).
- `BoardConfig.mk`: inherits `exynos9820-common/BoardConfig9825.mk` +
  `vendor/samsung/d2s/BoardConfigVendor.mk`; kernel config `exynos9820-d2s_defconfig`;
  density 560; fingerprint force-calibrate flag.
- `proprietary-files.txt`: blob list pinned against Samsung package **N975FXXS9HWHA**
  with per-file pinned hashes for a few (camera libs from N975FXXS7GVB1) and blob-fixup
  shims (vaultkeeper, camera3 patch, sensors hidltransport removal, sfpex shim).
- `extract-files.sh` chain: device script delegates to the common tree's script (extraction
  from a stock firmware zip is the fallback path when pre-extracted blobs don't exist).

## What was NOT public

- deuspivete's **local manifest** (which exact blob branch he synced for the 16.0 builds).
  The OTA JSON links only the three device repos. Since the ROM base is Lineage 23.2 and
  TheMuppets publishes `lineage-23.2` blobs for both d2s and exynos9820-common, that is
  our best-guess default — see `docs/blob-strategy.md` for the decision and fallbacks.
- Any signing-key setup he used (crDroid official release keys, presumably; irrelevant
  for us since our builds carry our own keys — see `docs/signing.md`).

## Unverified / to confirm during first build

- Exact kernel branch state the v12.9 "stock kernel" switch refers to.
- Whether TheMuppets lineage-23.2 blob layout matches what the 16.0 device trees expect
  (extract-files/proprietary-files drift). First build will surface mismatches.
