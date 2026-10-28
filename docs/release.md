# Release process (local build → GitHub release)

> Releases follow the **dev/prod policy** (`docs/dev-prod.md`): prod releases must
> pass `docs/dev-prod.md` §"Definition of done — prod" (current ASB patch level,
> hardened build + Magisk, subsystem checklist, banking-app test results).
> Dev builds publish to the dev channel (`ota/dev.json`, type nightly) freely —
> that is by design; OTA debugging happens on dev. Magisk note: prod OTAs rewrite
> `boot`, so document the Magisk re-patch step after every prod OTA.

1. **Build** per `docs/build-guide.md` (signed per `docs/signing.md`).
2. **Name**: `nopenix-1.0-<YYYYMMDD>-d2s-crDroid16.zip` (align with branding.md naming once finalized).
3. **OTA JSON**: run `scripts/ota-json.sh <zip>` → paste result into `ota/d2s.json`
   (newest entry first), commit + push to `main`.
4. **GitHub Release** on `NopeNix/d2s-crdroid16`:
   - tag: `nopenix-<version>` (e.g. `nopenix-1.0`)
   - assets: the ROM zip + `recovery.img` (so users can do the first-flash path)
   - body: security patch level, changelog diff vs previous, sha256 of the zip,
     banking-app compatibility test results
5. **Note**: add `releases/nopenix-<version>.md` with the same content for the record,
   including the banking-app test results and the debug-variant confirmation.
6. **Verify**: `curl` the raw OTA JSON URL; on the phone run Updater → check.
