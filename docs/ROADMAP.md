# ROADMAP — status and next steps

Legend: ⚪ todo · 🟡 in progress · 🟢 done · 🔴 blocked

## Phase 0 — Research & repo setup 🟢
- [x] Identify device, maintainer, official build history (docs/history.md)
- [x] Fork device/common/kernel/blob repos to NopeNix
- [x] Hub repo structure, AGENTS.md, MEMORY.md, docs
- [x] Local manifest written (manifests/nopenix.xml)

## Phase 1 — First build 🟡 (next!)
- [ ] Build host prepared (Ubuntu, deps, repo tool) — build-guide.md §1–2
- [ ] `repo sync` with our local manifest
- [ ] Blob layout verification: TheMuppets lineage-23.2 vs proprietary-files.txt (blob-strategy.md)
- [ ] Signing keys generated (signing.md)
- [ ] Branding wired: version strings, updater URI, zip naming (branding.md)
- [ ] `brunch d2s` succeeds end-to-end
- [ ] Boot test on device

## Phase 2 — OTA pipeline 🟡 (partially prepared)
- [x] OTA JSON format documented; ota-json.sh written
- [ ] First Nopenix release: zip + recovery.img + JSON on GitHub
- [ ] Manual first flash on the phone (ota.md upgrade path)
- [ ] In-place OTA via Updater verified

## Phase 3 — Security-patch cadence 🟪 (routine)
- [ ] Monthly: `repo sync` crDroid 16.0 upstream → rebuild → release (patch-level bump)
- [ ] Track upstream security merges: crdroidandroid 16.0 branches carry the ASB patches
- [ ] Watch for crDroid upstream abandoning 16.0 → decide: pin vs. rebase to Lineage 23.2 directly

## Phase 4 — Optional hygiene
- [ ] CI for docs (markdown lint) — cheap, doable on GitHub runners
- [ ] Verify what "stock kernel" in v12.9 means; decide our kernel stance (default: use
      crdroidandroid kernel 16.0 branch as-is)

## Decisions log
- 2026-10-04: hub-and-forks repo model (code in forks, docs/manifests here)
- 2026-10-04: TheMuppets lineage-23.2 blobs default (docs/blob-strategy.md)
- 2026-10-04: local builds only (GH runners insufficient); releases via GitHub Releases
- 2026-10-04: keep PRODUCT_NAME `lineage_d2s`; brand via props (docs/branding.md)
