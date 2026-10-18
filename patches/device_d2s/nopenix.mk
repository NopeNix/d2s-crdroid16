# nopenix.mk — Nopenix branding & OTA wiring (additive only, do NOT touch PRODUCT_NAME)

# Include from lineage_d2s.mk AFTER the crDroid inherit.

## Nopenix version stamp
NOPENIX_VERSION := 1.0
PRODUCT_SYSTEM_PROPERTIES += \
    ro.nopenix.version=$(NOPENIX_VERSION) \
    ro.nopenix.builddate=$(shell date -u +%Y%m%d)

## OTA: default Updater endpoint (raw GitHub, served from hub repo)
PRODUCT_SYSTEM_PROPERTIES += \
    lineage.updater.uri=https://raw.githubusercontent.com/NopeNix/d2s-crdroid16/main/ota/d2s.json