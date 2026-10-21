# REA — Samsung Shannon Modem Driver Reverse Engineering (d2s)

> Reverse-engineering workspace for getting the Samsung proprietary modem/RIL stack
> working on **d2s (Galaxy Note10+ SM-N975F, Exynos 9825)** under **Nopenix crDroid 16**
> (Android 16 / Lineage 23.2 base).
>
> This folder is the SINGLE HOME of all modem-RE work. Other tasks may run in this repo
> concurrently — everything we produce must stay inside `rea/` (do not touch docs/,
> manifests/, or the AOSP tree from this workstream; coordinate via this README).

## Target summary (first session, 2026-10-21)

- **Modem SoC**: Samsung Shannon **S5000AP** (strings in firmware: `S5000AP_S_20200113_055234`,
  build date `Aug  2 2023 08:15:43`).
- **Firmware source**: our own signed OTA already carries it —
  `firmware/SM-N975F/*` inside `/srv/android/flash-day/Nopenix-signed-ota.zip`
  (baseband `N975FXXS9HWHA`). Local copies in `bin/firmware/`:
  `modem.bin` (TOC container), `modem_debug.bin`, `cm.bin`, `uh.bin`, `param.bin`,
  `keystorage.bin`, `sboot.bin`, `dqmdbg.img`, `up_param.bin`.
- **modem.bin layout (parsed, verified)**: TOC header @0x10 (load `0x40008000`, size `0x410`,
  count 5), 32-byte entries at 0x20 + i*0x20:
  - `BOOT`   fileoff 0x420     load 0x40000000 size 0x1ff0     tail 0x4e410c07
  - `MAIN`   fileoff 0x2420    load 0x40010000 size 0x267f950  tail 0x60e35614
  - `VSS`    fileoff 0x2681d80 load 0x47800000 size 0x619e20   tail 0x8584888d
  - `NV`     fileoff 0x0       load 0x45600000 size 0x100000   tail 0
  - `OFFSET` fileoff 0x7aa00   load 0          size 0x85600    tail 0
  - `BOOT`/`MAIN` are ARM32 code (ARM vector table `7cf0 9fe5` = `ldr pc,[pc,#-0x7c]`).
  - Extracted sections in `bin/firmware/modem_BOOT.bin` / `modem_MAIN.bin`.
- **Kernel side (open source, in build tree)**:
  `kernel/samsung/exynos9820/drivers/misc/modem_v1/` — modem_v1 framework.
  d2s defconfig: `CONFIG_UMTS_MODEM_S5000AP=y`, `CONFIG_LINK_DEVICE_SHMEM=y`,
  `CONFIG_CP_SECURE_BOOT=y`. Device tree: `modem-s5000ap-sipc-pdata.dtsi`
  (SIPC 5.0, shmem link, `mif,modem_type = <11>`).
- **Userspace stack (all Samsung blobs)**:
  - `/vendor/bin/cbd` (cpboot-daemon) — **MISSING from current build** (see gap list below).
  - `/vendor/bin/hw/rild` + `libsec-ril.so` + `libril_sem.so` (present, from a54x pull).
  - `cass` (Crash Analysis Server, present), `secril_config_svc`, `sehradiomanager` (AOSP forks in `hardware/samsung/ril`).
- **Wire-up**: `init.baseband.rc` (from d2s blob tree) declares
  `service cpboot-daemon /vendor/bin/cbd -d -tss310 -bm -mm -P platform/13d60000.ufs/by-name/radio`
  → d2s boots the CP via the **ss310-style** boot path (Shannon SPI/shmem), not S5100.

## Key findings log (newest first)

- **2026-10-21 (S1)**: cbd availability across TheMuppets branches
  (`proprietary_vendor_samsung_exynos9820-common`): lineage-20/21/22.1 HAVE
  `proprietary/vendor/bin/cbd`; lineage-22.2/23.0/23.2 DO NOT (blob dropped upstream).
  crDroid 13.0 branch = byte-identical to TheMuppets lineage-20 (sha256 cc9252e6...).
  Downloaded all three; cbd-21 == cbd-22.1 (sha256 b3303b91..., only build-id bytes differ
  from -20). Analysis target: `rea/bin/blobs/cbd` (= 22.1 build).
- **2026-10-21 (S1)**: cbd blob symbol-ABI check against our Android 16 build PASSES:
  needs `liblog.so`, `libcutils.so`, `libc.so`, `libc++.so`, `libm.so`, `libdl.so`.
  `property_get`/`property_set`/`android_reboot` resolve from the vendor copy of
  `libcutils.so` (present in our vendor image, verified with nm). All `@LIBC`-versioned
  symbols exist in the runtime APEX bionic (klogctl, capset, statfs, etc. verified).
- **2026-10-21 (S1)**: Ghidra analysis of `start_shannon310_boot` (@0x15d748) shows the
  boot sequence: wait `vendor.cbd.rfs_check_done` prop → `prepare_boot_args` →
  `get_modem_state` ioctl 0x6f27 → `std_boot_modem_reset` → `std_security_req(non-secure)` →
  `shannon310_boot_xmit` → `std_security_req(secure, ptrs @+0x260/+0x28c)` →
  factory-prop SIM detect (`ds_detect` sysfs) → `std_boot_modem_on` → `std_boot_dload_on` →
  `std_boot_dload_start` (reset ipcmap, magic code) → `std_boot_finish_handshake` →
  `std_boot_dload_off`. Errors map to `-0xe`/`-0x13` etc.

## Identified gaps → plan (what must happen to get the modem working)

1. **cbd blob missing from the image** (proprietary-files.txt lists `-vendor/bin/cbd`
   but TheMuppets 23.2 tree doesn't have the file — it was silently skipped).
   → Restore from TheMuppets lineage-22.1 (verified AArch64, deps satisfiable).
   Not yet applied to the build tree (needs user OK per repo rules).
2. **init.baseband.rc exists in build** (from d2s blob tree) and expects `cbd`
   plus the `radio` partition at `13d60000.ufs/by-name/radio` (matches PIT).
3. Verify RIL HAL service definitions (`vendor.samsung.rilchip.slsi.rc`) match the
   `2_33` vintf manifests present.
4. Kernel: defconfig already has `CONFIG_UMTS_MODEM_S5000AP=y` — confirm the built
   kernel actually carries the s5000ap ctrl + shmem link drivers (check `modprobe`/`lsmod`
   on device or inspect vmlinux System.map).
5. OTAs must keep flashing `modem.bin` → `/dev/block/by-name/radio`
   (releasetools.py AddFirmwareImage already does this; confirmed in signed OTA).

## Analysis tool state

- REA/Ghidra session: `rea/bin/blobs/cbd` (sha256 b3303b91...), arm64.
- Key Ghidra function names discovered: see "findings log". Further decompiles go to
  `docs/decompiles/`.

## Decompilation exports

See `docs/decompiles/` for exported pseudocode of the important cbd functions
(regenerate with REA if needed; annotate addresses in comments).

## House rules for this folder

- Any binary, blob, capture, or dump you create goes under `bin/` (gitignore-safety:
  check `.gitignore` before committing binaries — prefer committing only text evidence).
- Every non-obvious finding gets a dated bullet in "Key findings log" above.
- If another session later changes direction, UPDATE this file before you finish —
  the next LLM must be able to resume from here alone.

## Session 2 additions (2026-10-21, same day, continued)

- **rild ↔ libsec-ril wiring verified**: `/vendor/bin/hw/rild` hardcodes `dlopen`
  of `libsec-ril.so` (strings: "libsec-ril.so", "RIL_Init argc = %d simSlotCount = %s",
  "RIL_register_socket"). `vendor.samsung.rilchip.slsi.rc` launches `ril-daemon` with no
  `-l` flag → default lib used. All 20 transitive NEEDED libs of `libsec-ril.so`
  verified PRESENT in the current build output (`vendor/lib64`, apex, system) —
  full list in `docs/ril-dependency-check.md`.
- **cbd dependency check**: needs liblog/libcutils/libc/libc++/libm/libdl only.
  `libcutils` (vendor copy) exports `property_get`/`property_set`/`android_reboot`
  (verified with nm on the built vendor/lib64/libcutils.so). liblog/libc/libm/libdl
  resolve from system+apex via default namespace. **cbds blobs are loadable as-is.**
- **ioctl ABI fully cross-verified** against kernel `modem_prj.h` (see
  `docs/cbd-ioctls-and-flow.md`): every ioctl cbd's shannon310 path uses exists in our
  16.0 kernel. No kernel-side ABI work needed.
- **prepare_boot_args decompiled and verified against our modem.bin**
  (`docs/decompiles/prepare_boot_args-shannon310.md`): TOC magic "TOC" at file offset 0,
  count at 0x1c (5, needs < 17 → passes), entries at 0x20 stride 0x20 (name/b_off/m_off/
  size/tail), m_off masked `& 0x3fffffff`, NV file = `/mnt/vendor/efs/nv_data.bin`
  (auto-created empty if missing), stage table stride 0x2c.
- **Modem bin analysis**: `modem.bin` TOC fully parsed (BOOT/MAIN/VSS/NV/OFFSET),
  MAIN = ARM32 (Cortex-A9 class, load 0x40010000), 40 MB. Shannon S5000AP.
  Splits exported: `bin/firmware/modem_BOOT.bin`, `modem_MAIN.bin`.

## Kernel-side verification (2026-10-21)

- `out/target/product/d2s/obj/KERNEL_OBJ/System.map` confirms the built d2s kernel
  contains the full modem_v1 stack:
  - `s5000ap_init_modemctl_device`, `s5000ap_on/off/shutdown/reset/boot_on/boot_off/
    boot_done/dump_start` (S5000AP ctrl compiled in ✓)
  - `shmem_create_link_device`, `shmem_security_request` (shmem link + security ✓)
  - `mcu_ipc_*`, `mif_*`, `modem_probe` (framework ✓)
- The ss310ap ctrl is ALSO linked (`ss310ap_init_modemctl_device`) — harmless; DT
  selects s5000ap via `mif,modem_type = <11>`.
- Conclusion: **no kernel-side gap**; kernel already matches the s5000ap path the cbd
  blob drives.

## Current gap list (single blocker)

1. `cbd` blob missing from image (restore from rea/bin/blobs/cbd = TheMuppets
   lineage-22.1 build, sha256 b3303b91...) — needs user approval before touching
   the vendor fork / proprietary-files.txt.

Everything else (rild, libsec-ril, libril_sem, cass, secril_config_svc,
sehradiomanager, init rc files, kernel drivers, DTS, modem.bin flashing in OTA)
is present and ABI-verified.
