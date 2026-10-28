# Release process (local build → GitHub release)

> Releases follow the **dev/prod policy** (`docs/dev-prod.md`): prod releases must
> pass `docs/dev-prod.md` §"Definition of done — prod" (current ASB patch level,
> hardened build + Magisk, subsystem checklist, banking-app test results).
> Dev builds publish to the dev channel (`ota/dev.json`, type `Nightly`) freely —
> that is by design; OTA debugging happens on dev. Magisk note: prod OTAs rewrite
> `boot`, so document the Magisk re-patch step after every prod OTA.

1. **Build** per `docs/build-guide.md` (signed per `docs/signing.md`).
2. **Name**: `nopenix-<dev|prod>-<version>-<YYYYMMDD>-d2s.zip` (e.g.
   `nopenix-dev-13.0-20261026-d2s.zip`, per `LINEAGE_VERSION` in
   `device/samsung/d2s/lineage_d2s.mk` — see docs/branding.md).
3. **OTA JSON**: generate the flat `{"response":[...]}` entry (schema per
   `docs/ota.md` + `ota/README.md`) and add it (newest first) to `ota/dev.json`
   (dev line) or `ota/prod.json` (prod line). ⚠ `scripts/ota-json.sh` still
   emits the OLD nested `files[]` format — update it or hand-edit the entry
   (ota/dev.json 2026-10-26 entry is the working reference).
   Commit + push to `main`.
4. **GitHub Release** on `NopeNix/d2s-crdroid16`:
   - tag: `nopenix-dev-<version>-<date>` (e.g. `nopenix-dev-13.0-20261026`)
   - assets: the ROM zip + `recovery.img` (so users can do the first-flash path)
   - body: security patch level, changelog diff vs previous, sha256 of the zip,
     banking-app compatibility test results (prod only)
5. **Note**: add `releases/nopenix-<version>.md` with the same content for the record,
   including the banking-app test results and the debug-variant confirmation.
6. **Verify**: `curl` the raw OTA JSON URL; on the phone run Updater → check.
