# cbd ioctl map (verified against kernel source 2026-10-21)

Cross-check of the ioctls the cbd blob (22.1 build, sha256 b3303b91) issues against
`kernel/samsung/exynos9820/drivers/misc/modem_v1/modem_prj.h`.
`_IO('o', x)` == request number `0x6f00 + x`.

| cbd request | kernel macro | meaning | present in our kernel? |
|---|---|---|---|
| 0x6f19 | IOCTL_MODEM_ON | power CP on (pda_active=1, cp power on) | YES (modem_io_device.c:685) |
| 0x6f21 | IOCTL_MODEM_RESET | CP reset | YES (modem_io_device.c:701) |
| 0x6f22 | IOCTL_MODEM_BOOT_ON | enter download/boot mode | YES (:712) |
| 0x6f23 | IOCTL_MODEM_BOOT_OFF | leave boot mode | YES (:720) |
| 0x6f24 | IOCTL_MODEM_BOOT_DONE | boot handshake done | YES |
| 0x6f27 | IOCTL_MODEM_STATUS | query modem state | YES (:734) |
| 0x6f28 | IOCTL_MODEM_DL_START | start download transfer | YES (:763) |
| 0x6f47 | IOCTL_MODEM_GET_CP_BOOTLOG | fetch CP bootlog | YES (CONFIG_LINK_DEVICE_SHMEM) |
| 0x6f48 | IOCTL_MODEM_CLR_CP_BOOTLOG | clear CP bootlog | YES |
| 0x6f53 | IOCTL_SECURITY_REQ | SMC security request (mode, param2, param3) | YES (modem_io_device.c:930 → shmem_security_request) |

Conclusion: **the lineage-22.1/13.0 cbd binary is wire-compatible with the exynos9820
modem_v1 kernel driver in our 16.0 kernel tree.** No kernel changes needed for the
ioctl ABI.

## decompiled function map (Ghidra, image base 0x100000)

std_boot_prepare_args   0x14f4a0  opens /dev/umts_boot0 (argv->dev name @+0x38), stores fd
std_boot_close_args     0x14f670
std_boot_load_loader    0x14f6b0
std_boot_modem_on       0x14fbe8  ioctl(fd, 0x6f19)
std_boot_modem_reset    0x14fca8  ioctl(fd, 0x6f21)
std_boot_finish_handshake 0x14fd68 (uses 0x6f24 boot-done + fin msg)
std_boot_dload_on       0x150048  ioctl(fd, 0x6f22)
std_boot_dload_start    0x150108  ioctl(fd, 0x6f28)
std_boot_dload          0x1501c8  (the actual xmit loop)
std_boot_dload_off      0x151188  ioctl(fd, 0x6f23); then 0x6f48 on success / 0x6f47 on fail
std_boot_finalize       0x151268
start_shannon310_boot   0x15d748  main SS310/S5000AP boot path (see README flow)
shannon310_boot_xmit    0x15cf90
shannon310_boot_xmit_bin 0x15c968
start_shannon5100_boot  0x161e58  (5G path, not needed for d2s)
upload_shannon310_modem 0x161c38  (forced-upload path)

security_req struct passed to 0x6f53 (from cbd @ 0x15d748 flow):
  { int mode; uint32_t param2; uint32_t param3; } (modem_sec_req in kernel)
  non-secure: mode=2 param2=0 param3=0  (bypass/CRC check path)
  secure:     mode=0 param2=*(b+0x260) param3=*(b+0x28c) (real secure boot params)

## Boot flow (start_shannon310_boot, verified pseudocode)

1. `check_board_revision()`
2. log "CP boot device", "CP binary file", "CP NV file"
3. boot link check: param_1+4 (boot_link) must be 9 (SHMEM) or 3 (SPI)
4. main link check: param_1+8 (main_link): 10=MIPI-LLI, 9=SHMEM, 6=C2C
5. wait for property `vendor.cbd.rfs_check_done` == "1" (50 x 100ms, then "TIMEOUT" log)
6. `boot_wake_lock(1)`
7. `prepare_boot_args()` → open boot dev, read TOC, check NV (`/mnt/vendor/efs/nv_data.bin`)
8. `store_srinfo(...)` → ioctl 0x6f27 get_modem_state
9. if state==0 → std_boot_modem_reset (0x6f21)
10. std_security_req(mode=2,...)   [non-secure]
11. shannon310_boot_xmit(stage 0)  [BOOT stage, sends bootloader]
12. std_security_req(mode=0, p2, p3) [secure]
13. get_factory_prop() → echo N > /sys/devices/platform/10000.mif_pdata/sim/ds_detect
14. std_boot_modem_on (0x6f19)
15. std_boot_dload_on (0x6f22)
16. std_boot_dload_start (0x6f28)
17. std_boot_finish_handshake (0x6f24, boot_done + fin)
18. std_boot_dload_off (0x6f23; then 0x6f48 on success, 0x6f47 on failure)
19. restore_srinfo
```
Error returns: -0xe (prepare_boot_args fail), -0x13 (link not supported), etc.
```

## Next steps (S2)

- [ ] Export `prepare_boot_args`, `shannon310_boot_xmit_bin` decompiles (TOC parsing +
      NV handling) → `docs/decompiles/`
- [ ] Verify cass + rild service boot chain on device (needs flash test).
- [ ] Confirm kernel has modem_v1 + s5000ap ctrl compiled (System.map check after build).
- [ ] Plan the `cbd` blob insertion into the build (needs user OK; touches proprietary tree).
