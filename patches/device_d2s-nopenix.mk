# Nopenix branding and line-variant configuration. SNAPSHOT of the fork's
# device/samsung/d2s/nopenix.mk (NopeNix/android_device_samsung_d2s, branch
# nopenix/dev-fixes-16.0, commit 88bd604, 2026-10-30). If you ever need to
# recreate the device tree from this hub repo, copy this file AND the two
# channel overlay dirs:
#   overlay/updater/dev/packages/apps/Updater/app/src/main/res/values/strings.xml  (-> ota/dev.json)
#   overlay/updater/prod/packages/apps/Updater/app/src/main/res/values/strings.xml (-> ota/prod.json)
# (paths inside overlay/ mirror the Updater package source tree; aapt2 silently
# drops the override if the mirror path is wrong — do not "simplify" them.)
# HISTORY: pre-88bd604 this file computed NOPENIX_OTA_URI but never consumed it,
# so every build baked ota/dev.json into the Updater RRO regardless of variant.
# Included from device.mk BEFORE vendor/lineage/config/common_full_phone.mk,
# so CR_VERSION must be set here to win over the crDroid default in
# version.mk (patched to `CR_VERSION ?= 12.12` — carry that patch, see hub
# repo patches/).
#
# Variant-specific values (dev vs prod) are switched by NOPENIX_VARIANT,
# which the build wrapper sets per line:
#   dev  -> userdebug + WITH_SU=true + WITH_ADB_INSECURE=true +
#           BUILD_BROKEN_DUP_SYSPROP (set in device tree) + init.debug.rc
#   prod -> user flavor, WITH_SU=false, no WITH_ADB_INSECURE, no debug knobs
#           (init.debug.rc and ro.debuggable gated off in device.mk/BoardConfig)

NOPENIX_VARIANT ?= dev
NOPENIX_VERSION := 13.0

CR_VERSION := $(NOPENIX_VERSION)

PRODUCT_PRODUCT_PROPERTIES += \
    ro.nopenix.variant=$(NOPENIX_VARIANT) \
    ro.nopenix.version=$(NOPENIX_VERSION) \
    ro.lineage.build.version=23.2

# Updater OTA channel: DEVICE_PACKAGE_OVERLAYS must pick the overlay BEFORE
# its value is compiled into the Updater auto-RRO (PRODUCT_ENFORCE_RRO_TARGETS
# =*). Channel-specific overlays live in overlay/updater/<channel>/values/.
ifeq ($(NOPENIX_VARIANT),dev)
DEVICE_PACKAGE_OVERLAYS += $(LOCAL_PATH)/overlay/updater/dev
else
DEVICE_PACKAGE_OVERLAYS += $(LOCAL_PATH)/overlay/updater/prod
endif

$(warning Nopenix: variant=$(NOPENIX_VARIANT) version=$(NOPENIX_VERSION) ota=ota/$(NOPENIX_VARIANT).json)
