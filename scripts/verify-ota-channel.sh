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
if ! unzip -q -o "$zip" 'VENDOR/overlay/Updater__*__auto_generated_rro_vendor.apk' -d "$tmp" 2>/dev/null; then
    echo "FAIL: no Updater vendor RRO found in $zip" >&2
    exit 1
fi

baked_url="$(strings "$tmp"/VENDOR/overlay/Updater__*__auto_generated_rro_vendor.apk \
    | grep -o 'https://raw.githubusercontent.com/NopeNix/d2s-crdroid16/main/ota/[a-z]*\.json' | head -1)"
if [ -z "$baked_url" ]; then
    echo "FAIL: Updater RRO has no recognizable ota/*.json URL" >&2
    exit 1
fi
if [ "$baked_url" != "$expected_url" ]; then
    echo "FAIL: channel mismatch — RRO bakes '$baked_url', expected '$expected_url'" >&2
    exit 1
fi
echo "OK: Updater RRO bakes $baked_url (channel=$channel)"
