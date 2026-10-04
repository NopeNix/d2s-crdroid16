# Blob strategy (decided 2026-10-04)

## Context

The crDroid-official blob repos lag behind the ROM base:

- `crdroidandroid/proprietary_vendor_samsung_d2s` → branches `13.0`, `14.0` only
- `crdroidandroid/proprietary_vendor_samsung_exynos9820-common` → branch `13.0` only

crDroid 16.0 is built on **Lineage 23.2** (Android 16). Blobs that old risk framework/HAL
mismatches, and older blobs mean older vendor-side security content.

## Decision

Default source for both blob trees: **`TheMuppets`** pre-extracted blobs, branch
**`lineage-23.2`**:

- `TheMuppets/proprietary_vendor_samsung_d2s`
- `TheMuppets/proprietary_vendor_samsung_exynos9820-common`

Rationale: newest Samsung firmware extraction, matches the base, publicly mirrored,
no need to extract blobs from a stock firmware ourselves for the first builds.

The `NopeNix` forks of the crDroid blob repos still exist as **fallback** if TheMuppets
layout turns out incompatible with the 16.0 device trees' `proprietary-files.txt`
expectations.

## Fallback path (if first build fails on blobs)

1. Try crDroid `14.0` blob branches in the NopeNix forks.
2. If still broken: extract blobs from the latest stock firmware (N975FXXS9HWHA per
   `proprietary-files.txt`) using the tree's own `extract-files.sh` against a firmware zip.
   Document that process here once attempted.

## Open verification (first build)

- [ ] Confirm TheMuppets `lineage-23.2` blob directory layout matches
      `proprietary-files.txt` paths in the 16.0 device trees (blob list drift check).
- [ ] If mismatches: record them here + in MEMORY.md, adjust `proprietary-files.txt`
      in our fork or switch blob source.

> Agents: when you resolve an item above, update this file (with user approval) and
> append the learning to MEMORY.md.
