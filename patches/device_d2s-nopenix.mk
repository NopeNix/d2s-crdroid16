# Nopenix branding and line-variant configuration.
# Included from device.mk BEFORE vendor/lineage/config/common_full_phone.mk,
# so CR_VERSION must be set here to win over the crDroid default in
# version.mk (patched to `CR_VERSION ?= 12.12` — carry that patch, see hub
# repo patches/).
#
# Variant-specific values (dev vs prod) are switched by NOPENIX_VARIANT,
# which the build wrapper sets per line (dev for now; prod later).

NOPENIX_VARIANT ?= dev
NOPENIX_VERSION := 13.0

CR_VERSION := $(NOPENIX_VERSION)

PRODUCT_PRODUCT_PROPERTIES += \
    ro.nopenix.variant=$(NOPENIX_VARIANT) \
    ro.nopenix.version=$(NOPENIX_VERSION) \
    ro.lineage.build.version=23.2

ifeq ($(NOPENIX_VARIANT),dev)
# Dev OTA channel (nightly JSON in the hub repo). The crDroid 16 Updater
# reads the updater_server_url string resource only (no lineage.updater.uri
# prop support); the override ships as a device-tree resource overlay which
# PRODUCT_ENFORCE_RRO_TARGETS=* converts into an auto-RRO.
NOPENIX_OTA_URI := https://raw.githubusercontent.com/NopeNix/d2s-crdroid16/main/ota/dev.json
else
NOPENIX_OTA_URI := https://raw.githubusercontent.com/NopeNix/d2s-crdroid16/main/ota/prod.json
endif

$(warning Nopenix: variant=$(NOPENIX_VARIANT) version=$(NOPENIX_VERSION) ota=$(NOPENIX_OTA_URI))
