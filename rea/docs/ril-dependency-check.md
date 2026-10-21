# RIL/modem userspace dependency check (2026-10-21)

Verified against the CURRENT build output (out/target/product/d2s, Android 16).

## libsec-ril.so (dlopen'd by /vendor/bin/hw/rild)

All 25 NEEDED entries resolved:

| lib | location | notes |
|---|---|---|
| libril_sem.so | vendor/lib64 | blob (from a54x pin) |
| libnetutils.so | vendor/lib64 | built |
| libsqlite.so | vendor/lib64 | built |
| libhardware_legacy.so | vendor/lib64 | built |
| libcrypto.so | vendor/lib64 | built |
| librilutils.so | vendor/lib64 | built (AOSP RIL utils) |
| libxml2.so | vendor/lib64 | built |
| libz.so | vendor/lib64 | built |
| libutils.so | vendor/lib64 | built |
| libjsoncpp.so | vendor/lib64 | built |
| libSemTelephonyProps.so | vendor/lib64 | blob |
| libSemDataProps.so | vendor/lib64 | blob |
| libvkmanager_vendor.so | vendor/lib64 | built |
| libengmode_client.so | vendor/lib64 | blob |
| libbase.so | vendor/lib64 | built |
| libbinder_ndk.so | system/lib64 | built |
| vendor.samsung.hardware.radio.channel-V1-ndk.so | vendor/lib64 | blob |
| libsecnativefeature.so | vendor/lib64 | blob |
| libfloatingfeature.so | vendor/lib64 | blob |
| libsemnativecarrierfeature.so | vendor/lib64 | blob |
| libprotobuf-cpp-full-3.9.1.so | vendor/lib64 | built (vendorcompat pkg) |
| libc++.so/libc.so/libm.so/libdl.so | apex/system | runtime |

## /vendor/bin/hw/rild

NEEDED: libcutils, liblog, libril_sem, libc++, libc, libm, libdl — all present.
Loads `libsec-ril.so` via dlopen (hardcoded string), logs "RIL_Init argc = %d
simSlotCount = %s", registers RIL sockets, "ril.halservice.registered."

## cbd (cpboot-daemon) — restored from TheMuppets lineage-22.1

NEEDED: liblog, libcutils, libc, libc++, libm, libdl — all resolvable.
vendor/lib64/libcutils.so exports property_get/property_set/android_reboot (nm-verified).

## cass (Crash Analysis Server, in image)

NEEDED (verified in build): resolves; service `cass` runs class core from cass.rc.

## Conclusion

RIL userspace stack is COMPLETE except for the missing `cbd` binary.
Restoring cbd (from rea/bin/blobs/cbd, sha256 b3303b91...) into
`vendor/samsung/exynos9820-common/proprietary/vendor/bin/cbd` + uncommenting the
`-vendor/bin/cbd` line in `device/samsung/exynos9820-common/proprietary-files.txt`
should close the last userspace gap. (Pending user approval — repo rules.)
