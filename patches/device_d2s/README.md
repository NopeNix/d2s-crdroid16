# Phase 1 — prepared fork change: branding (NopeNix/android_device_samsung_d2s, branch 16.0)

Status: DRAFT, awaiting approval to push as feature branch + PR (AGENTS.md rule 6/8).

## Change 1: new file `nopenix.mk`
Content: see `nopenix.mk` next to this file.

## Change 2: `lineage_d2s.mk` — add one line at the end:

```make
## Nopenix branding & OTA wiring
$(call inherit-product-if-exists, device/samsung/d2s/nopenix.mk)
```

Rationale: keeps PRODUCT_NAME `lineage_d2s` (OTA version matching depends on it,
see docs/branding.md); branding is additive props only. `inherit-product-if-exists`
keeps the tree buildable even if nopenix.mk is removed later.

## Alternative considered
Setting the props via `vendor/lineage-priv` overlay would avoid touching the fork,
but a fork change is more robust for us (survives re-sync; version-controlled in
our fork) and keeps everything for d2s in one place.

## Not in this PR (deliberately, per docs/branding.md open items)
- Settings→About "Nopenix" display string (needs identifying crDroid's version
  string resource at build time; follow-up once a build exists).
- Zip filename naming override (same reason).

## Follow-up after first successful build
- Verify `ro.nopenix.version` appears in build.prop.
- Verify Updater picks up `lineage.updater.uri`.