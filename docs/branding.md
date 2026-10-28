# Branding — how "Nopenix" becomes visible without breaking OTA

## Constraint (do not break this)

The Updater app matches OTA JSON `version` against `ro.lineage.build.version`, and the
device's product name (`PRODUCT_NAME = lineage_d2s`) is what `brunch d2s` resolves.
**Do NOT rename PRODUCT_NAME / PRODUCT_DEVICE / the product makefile.** Branding is
additive, via props and display strings.

## What we set

1. **Build/display version strings** — in our `android_device_samsung_d2s` fork, add a
   `nopenix.mk` (included from `lineage_d2s.mk` after the crDroid inherit) setting:
   - `NOPENIX_VERSION := 1.x` (or date-based: `1.0-20260930`)
   - `ro.nopenix.version=$(NOPENIX_VERSION)`
   - `ro.nopenix.builddate=<iso date>`
   - append Nopenix to the display version via the crDroid/Lineage version overlay
     (exact resource/prop to be identified during first build — likely
     `ro.lineage.build.version` suffix or the crDroid Settings version string overlay).
2. **Updater URI prop** — set the default OTA URL in the same place:
   - `lineage.updater.uri=https://raw.githubusercontent.com/NopeNix/d2s-crdroid16/main/ota/d2s.json`
3. **Visible identity** — Settings → About must show "Nopenix". Implementation options,
   in preference order (pick during first build and update this file):
   - overlay crDroid's version string resource(s) in our device tree overlay dir;
   - or append to `ro.crdroid.version` / equivalent display prop.
4. **Zip name** — the release zip gets the `nopenix` prefix via
   `CUSTOM_VERSION`/release naming mechanism of the crDroid vendor config (identify exact
   var during first build; crDroid derives filename from version props).

## Open items (first build)

- [ ] Identify exact crDroid 16.0 prop/resource used for the Settings→About ROM version
      string; wire Nopenix into it.
- [ ] Identify the zip filename generator var; set `nopenix` naming.
- [ ] Confirm `lineage.updater.uri` is picked up from device-tree prop overlay.

> Whoever resolves these: update this doc (ask user first) + append to MEMORY.md.

> Dev/prod note (2026-10-26): v13 still displays "v12.12-20261025" and carries no
> `ro.lineage.build.version` — branding props must be fixed for the dev line already,
> because the Updater OTA version-match depends on `ro.lineage.build.version` (see
> `docs/ota.md` and `docs/dev-prod.md`; handover-8 item 2). Add `ro.nopenix.variant`
> (dev|prod) and per-line zip naming (`nopenix-dev-*` / `nopenix-*`).
