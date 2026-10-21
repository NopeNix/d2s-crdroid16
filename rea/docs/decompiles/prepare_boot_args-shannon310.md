# prepare_boot_args (shannon310 path) — @0x15ead0 in cbd (22.1)

Ghidra decompile summary (verified 2026-10-21). This is the function that parses
`modem.bin`'s TOC and prepares the dload control table.

## What it does (in order)

1. `std_boot_prepare_args(param_1, 5)` — opens the boot device (e.g. `/dev/umts_boot0`),
   zeroes a 0xc60-byte control area at DAT_0016f8c8, stores {args, fd, dev_type=5}.
   Failure → log "std_boot_prepare_args fail" and return NULL.
2. Opens the **CP binary file** = args->bin_path (`+0x58`), e.g. `/dev/mbin0` symlink to
   the `radio` partition. Failure → "BIN(%s) open fail".
3. `read(bin_fd, buf+0x14, 0x200)` — reads the TOC header block (512 bytes).
4. Validates:
   - `strcmp(buf+0x14, "TOC") == 0` — magic must be literally `TOC` at block start
     (file offset 0; matches our modem.bin parse).
   - TOC entry count @ control+0x30 (= file offset 0x1c) must be **< 0x11 (17)** —
     the `count < 17` branch is the GOOD path (builds the stage table); `>= 17` fails
     with "invalid TOC: Total TOC count is %d". Our modem.bin has count = 5 → OK.
5. Builds per-stage dload control entries (stride 0x2c in a control table, TOC entries
   stride 0x20), for each entry logging:
   `stage=%u, name:%s b_off=0x%08x, m_offset=0x%08x b_size=0x%08x`
   - b_off = TOC entry +0x20 (offset in bin file)
   - m_offset = TOC entry +0x24 & 0x3fffffff (load addr, masking top 2 bits!)
   - b_size = 8 bytes @ +0x28 (size + flags combined)
   - NV entry: fd = NV file fd (`/mnt/vendor/efs/nv_data.bin`); else fd = bin_fd
   - `strcmp(name,"VSS")` marks vss entries.
6. NV file open failure with ENOENT → `create_empty_nv(nv_path, size)` → retry.
7. On any failure: `std_boot_close_args`, `close(bin_fd)`, return NULL.

## Gotchas learned

- **m_offset masking `& 0x3fffffff`**: top 2 bits of the TOC load addr are FLAGS
  (e.g. 0x80000000 = raw/encrypted flag?) — treat load addresses as
  `addr & 0x3fffffff` when comparing with our modem.bin parse (0x40010000 → 0x00010000).
- TOC entry field offsets within the 0x20-byte entry:
  +0x00 name[12], +0x0c b_off(u32), +0x10 m_off(u32), +0x14 size(u32), +0x18 tail(u32)
  (consistent with our modem.bin parse: BOOT b_off=0x420 m_off=0x40000000 size=0x1ff0).
  Note decompiler shows +0x0c/+0x10/+0x14 relative to `buf+0x14` base — same fields.
- NV file = `/mnt/vendor/efs/nv_data.bin` (read fd stored per stage; cbd sends REG NV
  to CP during boot handshake).
- Stage table stride is 0x2c; per-stage struct starts at control+stage*0x2c+0x214 area.

## Local decompile (full Ghidra output)

Saved: `prepare_boot_args-shannon310.c` (in this folder).

## Stage count derivation (correction 2026-10-21, verified against our modem.bin)

```
stages = count - 1           # 5-1 = 4 for our modem.bin
if (nv_path[0] != '\0')      # NV configured (d2s: /mnt/vendor/efs/nv_data.bin)
    stages = 2               # !!! shrinks to 2 when NV is present?? 
```
Read carefully: the decompile shows `*(int *)(lVar11 + 0xc) = iVar9;` then conditional
`if (cVar4 != 0) { iVar5 = 2 } else { iVar5 = iVar9 }`. The exact semantics still need a
careful re-read of the assembly — flag for S2. The per-stage loop runs
`stage < stages+1` times regardless.

Header note: TOC header @file 0x10 = {load 0x40008000, toc_size 0x410, 0, count 5}.
toc_size 0x410 > 0x10+5*0x20=0xb0 — remaining bytes in the 0x410 TOC region
(file 0xb0..0x410) are zeros in our image (verified) — reserved space.

