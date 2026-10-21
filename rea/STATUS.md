# REA modem-RE status — handoff notes (written 2026-10-21)

This is the resume file. If you are a new LLM session picking up this workstream,
start here (after rea/README.md).

## What this workstream is

Getting Samsung's proprietary modem stack working on d2s (SM-N975F) for our
crDroid 16 / Android 16 Nopenix build. Scope decided 2026-10-21:

- **In scope**: the CP boot daemon (`cbd`), RIL userspace (`rild`, `libsec-ril.so`,
  `libril_sem.so`, `cass`, `secril_config_svc`, `sehradiomanager`), init wiring
  (`init.baseband.rc`, `vendor.samsung.rilchip.slsi.rc`, `init.vendor.rilcommon.rc`),
  kernel modem_v1 ABI compatibility, `modem.bin` TOC/firmware format.
- **Explicitly OUT of scope** (per project goal discipline): no new features, no
  VoLTE/VoWiFi work yet (known broken on whole family), no 5G (d2s is LTE-only HW
  path for our model — radio2/modem_5g.bin absent).

## Status: userspace stack is ABI-complete, ONE file missing

Everything is verified working-compatible EXCEPT the `cbd` blob was dropped from
TheMuppets 23.2 extraction and is therefore missing from our image while
`init.baseband.rc` still starts `cpboot-daemon /vendor/bin/cbd ...`.

Candidates downloaded and compared (all in `bin/blobs/`):

| file | source | sha256 |
|---|---|---|
| cbd-20 | TheMuppets exynos9820-common lineage-20 | cc9252e6... (== crDroid 13.0 blob) |
| cbd-21 | TheMuppets lineage-21 | b3303b91... |
| cbd-22.1 | TheMuppets lineage-22.1 | b3303b91... (== cbd-21, 16-byte build-id diff vs -20) |
| cbd-crdroid-13.0 | crdroidandroid 13.0 | cc9252e6... (== cbd-20) |

Analysis target: `bin/blobs/cbd` = 22.1 build (b3303b91...).

## Verified facts (do not re-derive)

1. **ABI**: cbd's ioctl set (0x6f19/21/22/23/24/27/28/45/46/47/48/53) all exist in
   our 16.0 kernel `modem_prj.h`. Kernel has `s5000ap_*` + `shmem_*` + `mcu_ipc_*`
   compiled (System.map verified). Full detail: `docs/cbd-ioctls-and-flow.md`.
2. **TOC format of modem.bin / radio partition**: magic "TOC" at 0, header
   {load 0x40008000, toc_size 0x410, ?, count 5} at 0x10, entries 0x20 stride 0x20
   {name12, b_off, m_off(&0x3fffffff), size, tail}. Our N975FXXS9HWHA modem.bin:
   BOOT@0x420→0x40000000 (0x1ff0), MAIN@0x2420→0x40010000 (0x267f950),
   VSS@0x2681d80→0x47800000 (0x619e20), NV (size 0x100000), OFFSET (0x85600).
   cbd's `prepare_boot_args` (0x15ead0) parses exactly this (count<17 required → 5 passes).
3. **Boot flow** of `start_shannon310_boot` (0x15d748) — documented in
   `docs/cbd-ioctls-and-flow.md`. Key property: waits for `vendor.cbd.rfs_check_done`.
   Sends REG NV from `/mnt/vendor/efs/nv_data.bin` during handshake.
4. **All libsec-ril.so deps present** in current build (25/25) —
   `docs/ril-dependency-check.md`.
5. **OTA firmware flashing path is already correct**: releasetools.py writes
   modem.bin → /dev/block/by-name/radio via AddFirmwareImage; confirmed present in
   the signed OTA at /srv/android/flash-day/Nopenix-signed-ota.zip
   (firmware/SM-N975F/modem.bin, sha256 1d361a30...).

## Proposed fix (needs USER APPROVAL before touching build tree)

### Option A — restore blob cbd (fast path)
1. Copy `rea/bin/blobs/cbd` → the vendor fork working tree
   (`/srv/android/nopenix-d2s/vendor/samsung/exynos9820-common/proprietary/vendor/bin/cbd`)
   and commit to the NopeNix fork's blob branch per blob-strategy docs.
2. In `device/samsung/exynos9820-common/proprietary-files.txt`, remove the leading
   `-` from `-vendor/bin/cbd` (line ~81).
3. Rebuild, verify `/vendor/bin/cbd` in the image, flash test.

### Option B — build open-source cpboot_v3 (upstream Lineage 23.2 parity) ← RECOMMENDED
Discovered in session 2: the tree ALREADY CONTAINS an Apache-2.0 source cbd at
`hardware/samsung_slsi-linaro/exynos/cpboot_v3/` (cc_binary "cbd", with
`cld` loopback binary), and **upstream Lineage 23.2 exynos9820-common wires it in**;
our crDroid fork dropped those lines when it pinned prebuilt rild blobs:

```
# upstream BoardConfigCommon.mk (lineage-23.2), lines ~154:
$(call soong_config_set,cbd,protocol,sipc)
$(call soong_config_set_bool,cbd,use_legacy_sipc_ioctl,true)

# upstream common.mk RIL section:
PRODUCT_PACKAGES += \
    cbd \
    secril_config_svc \
    sehradiomanager
```

Compatibility of cpboot_v3 with our 4.14 kernel verified (all checked 2026-10-21):
- ioctl ABI: with `LEGACY_SIPC_IOCTL`, `IOCTL_POWER_RESET=_IO('o',0x21)`,
  `IOCTL_MODEM_DL_START=_IO(0x28)`, `IOCTL_REQ_SECURITY=_IO('o',0x53)` — matches
  kernel `_IO` definitions (kernel copies 16-byte `modem_sec_req` from arg; both
  structs identical).
- `IOCTL_LOAD_CP_IMAGE=_IO(0x40)`: kernel `shmem_xmit_boot` copies
  `struct modem_firmware {u64 binary; u32 size; u32 m_offset; u32 b_offset;
  u32 mode; u32 len}` (24 B packed) — cpboot_v3 `cp_image` non-legacy layout is
  byte-identical.
- TOC parse: `BootDumpModap.cpp` masks `m_offset & CP_MEMORY_MASK` — same
  `& 0x3fffffff` semantics as the blob's `prepare_boot_args`.
- Defaults for `-t ss310` (BootDumpModap): `node_boot=/dev/umts_boot0`,
  `path_nv_data=/mnt/vendor/efs/nv_data.bin`, `first_stage_toc_type=TOC_TOC` —
  exactly matches blob behavior and our `init.baseband.rc` invocation
  (`-P platform/13d60000.ufs/by-name/radio` → `/dev/block/platform/13d60000.ufs/by-name/radio` ✓).
- Upstream diff context: lineage-20 used blob cbd + HIDL radio; 23.x uses source
  cbd + AIDL radio. Our fork is a 23.2 base → Option B matches upstream intent.

Steps for Option B:
1. Add the two `soong_config_set` lines to
   `device/samsung/exynos9820-common/BoardConfigCommon.mk` (RIL section).
2. Add `cbd` (and optionally `cld`) to the RIL `PRODUCT_PACKAGES` block in
   `device/samsung/exynos9820-common/common.mk`.
3. Optionally REMOVE `-vendor/bin/cbd` from proprietary-files.txt (not needed then).
4. Rebuild; verify binary appears in vendor/bin; flash test.

Flash test checklist (both options):
- `ps -A | grep -E 'cbd|rild|cass'`
- `logcat | grep -iE 'cbd|mif|sec-ril'` — expect the boot flow logs from
  `docs/cbd-ioctls-and-flow.md` ("Prepare arguments, read TOC, check NV" etc.)
- `dmesg | grep -iE 'mif|modem_v1|s5000ap'` — CP boot handshake
- `getprop gsm.version.baseband` → N975FXXS9HWHA
- `dumpsys telephony.registry` for service state.

## Open questions for next session

- ~~whether `vendor.cbd.rfs_check_done` is set by something~~ RESOLVED: cpboot_v3
  Type.h defines `VPROP_RFS_CHECKDONE "vendor.cbd.rfs_check_done"` — grep who SETS it
  (likely the RFS/nv validator daemon `secril_config_svc` or rild). If nothing sets
  it, cbd waits 5s then proceeds with "TIMEOUT" log (non-fatal).
- `cass` (28KB blob) purpose + whether it needs the missing `diag-daemon` service
  (referenced only in `vendor.samsung.rilchip.slsi.rc` onrestart; the service is
  declared nowhere — init logs an error at restart, non-fatal).
- Long-term: document the "dropped blob" pattern (TheMuppets 23.2 tree silently
  lacks binaries that proprietary-files.txt lists) — a FULL list diff of
  proprietary-files.txt vs TheMuppets 23.2 tree was NOT yet done (only RIL section
  verified); do it before trusting other subsystems.

## Concurrency note

Other agents may edit the repo concurrently. Keep ALL RE work in `rea/`.
Binaries live in `rea/bin/` (gitignored). Text evidence in `rea/docs/`, `rea/evidence/`.
