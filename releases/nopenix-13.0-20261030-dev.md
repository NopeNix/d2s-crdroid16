# Nopenix dev 13.0 (2026-10-30, ts 1793348962) - d2s

**Audio fix release.** The SLSI primary audio HAL (`audio.primary.universal9825`)
was never built — the build fell back to the generic AOSP HAL that opens the
ABox PCM but performs no Samsung routing (mixer_paths / ABox / madera) → silent
output. Fixed by parsing the `libaudio/audiohal` soong namespace and wiring the
`exynos_audio` soong vars (`PROXY_LIBRARY=libaudioproxy`,
`PREDEFINED_LOW_CAPTURE_DURATION=20`), matching the LineageOS lineage-23.2
official d2s config. Fork commit `1d502b6` on
`android_device_samsung_exynos9820-common` (`nopenix/dev-fixes-16.0`).

- SPL: 2026-10-01
- Build timestamp: 1793348962
- sha256: `c2ac045f5c471c4fd3fb231155d5ff09cf2adbf2ace4527627f1ba74598aa34b`
- Release: https://github.com/NopeNix/d2s-crdroid16/releases/tag/nopenix-dev-13.0-20261030
- Channel: ota/dev.json (Nightly)
