# d2s device facts

## Identity

- Samsung Galaxy Note10+ (EU = SM-N975F; dual-SIM SM-N975F/DS)
- Codename: `d2s` | Exynos 9825 (Samsung "beyond/dream2" platform, shared with S10/Note10 family)
- Related codenames sharing the exynos9820-common tree: d1 (Note10), d1x (Note10 5G), d2x (Note10+ 5G), beyond* (S10 series), f62

## Build-relevant facts (from device tree, verified 2026-10-04)

- Kernel defconfig: `exynos9820-d2s_defconfig` (kernel repo `NopeNix/android_kernel_samsung_exynos9820`, branch 16.0)
- Display density: 560 | Resolution 1440x3040 | Boot animation half-res, width 1440
- In-display fingerprint (FOD/UDFPS): yes, with `TARGET_SEC_FP_REQUEST_FORCE_CALIBRATE := true`
- S Pen: supported (common tree carries SPenActions + SPen HAL sepolicy)
- Launched with Android 9 (P) → `product_launched_with_p`
- Non-A/B device (uses `non_ab_device.mk`) — recovery-based updates, not A/B virtual partitions
- Blobs reference Samsung firmware package N975FXXS9HWHA (camera libs pinned from N975FXXS7GVB1)
- Known broken on the whole family: VoLTE / VoWiFi

## Flashing facts

- Samsung Download Mode: Vol Down + Bixby + USB cable
- Flashing tool: Odin (Windows) or heimdall (Linux); recovery flashes to RECOVERY partition
- vbmeta: Lineage wiki for d2s documents a vbmeta-disable step when first installing custom recovery from stock — see wiki.lineageos.org/devices/d2s/install for the authoritative first-install-from-stock flow
- Firmware requirement: crDroid 16-era builds require a recent-enough Samsung firmware base (check wiki "Update firmware on d2s" page)

## Links

- Lineage wiki device page: https://wiki.lineageos.org/devices/d2s/
- Lineage wiki install: https://wiki.lineageos.org/devices/d2s/install/
- Lineage wiki firmware update: https://wiki.lineageos.org/devices/d2s/fw_update/
- crDroid device page (now EOL): https://crdroid.net/d2s/12
- Official XDA thread: https://xdaforums.com/t/rom-official-16-update-crdroid-12-n10-series-aosp-encryption.4714988/
