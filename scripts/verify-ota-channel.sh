#!/usr/bin/env bash
# verify-ota-channel.sh — assert that a build's Updater RRO points at the
# intended OTA channel JSON. Catches the NOPENIX_OTA_URI class of bug (dead
# variable, hardcoded overlay URL baked into every build) BEFORE publish.
#
# Usage: verify-ota-channel.sh <zip> <expected-channel:dev|prod>
#   <zip> is a target-files package (hyphen form, e.g. signed-target-files.zip).
#   Exits 0 if the baked updater_server_url matches
#   .../ota/<expected-channel>.json, exits 1 otherwise.
#
# Works on the signed or unsigned target-files; does NOT work on the OTA zip
# (the RRO apk lives in the target-files layout). Call it after signing,
# before staging/publishing — see docs/ota.md release checklist.
set -euo pipefail

zip="$1"
channel="$2"
expected_url="https://raw.githubusercontent.com/NopeNix/d2s-crdroid16/main/ota/${channel}.json"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
# The Updater RRO may land under VENDOR/ or PRODUCT/ overlay depending on
# partition mapping; scan both. The URL override lives in the vendor RRO;
# the product one may carry no URL (not an error by itself).
unzip -q -o "$zip" 'VENDOR/overlay/Updater__*__auto_generated_rro_vendor.apk' 'PRODUCT/overlay/Updater__*__auto_generated_rro_product.apk' -d "$tmp" 2>/dev/null || true
rros="$(find "$tmp" -name 'Updater__*__auto_generated_rro_*.apk')"
if [ -z "$rros" ]; then
    echo "FAIL: no Updater RRO found in $zip" >&2
    exit 1
fi

# Union of URLs across ALL Updater RROs. grep's no-match exit status must
# not kill the pipeline (set -o pipefail).
urls="$(for rro in $rros; do
    unzip -p "$rro" resources.arsc 2>/dev/null | strings \
      | grep -o 'https://raw.githubusercontent.com/NopeNix/d2s-crdroid16/main/ota/[a-z]*\.json' || true
done | sort -u)"
if [ -z "$urls" ]; then
    echo "FAIL: no Updater RRO has an ota/*.json URL baked in (overlay dropped — check DEVICE_PACKAGE_OVERLAYS mirror path)" >&2
    exit 1
fi
if [ "$(echo "$urls" | wc -l)" -gt 1 ]; then
    echo "FAIL: conflicting URLs baked across Updater RROs: $urls" >&2
    exit 1
fi
baked_url="$urls"
if [ "$baked_url" != "$expected_url" ]; then
    echo "FAIL: channel mismatch — RRO bakes '$baked_url', expected '$expected_url'" >&2
    exit 1
fi
echo "OK: Updater RRO bakes $baked_url (channel=$channel)"
