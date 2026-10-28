#!/usr/bin/env bash
# ota-json.sh — generate a crDroid 16 Updater JSON entry from a built OTA zip.
# Usage: scripts/ota-json.sh <zip> [version] [buildtype]
#
# Output format (verified against on-device Updater 2026-10-26): crDroid flat
# format wrapped in a response object: {"response":[{ maintainer/oem/device/
# filename/download/timestamp/sha256/size/version/buildtype/os_patch_level/
# os_sdk_level }]}. NOT the old Lineage nested files[] array — bare arrays and
# nested files[] are both rejected by the crDroid 16 Updater.
# Updater matches entries by timestamp + os_sdk_level, NOT the version field.
set -euo pipefail

ZIP="${1:?usage: ota-json.sh <zip> [version] [buildtype]}"
VERSION="${2:-23.2}"
BUILDTYPE="${3:-Nightly}"

[ -f "$ZIP" ] || { echo "not a file: $ZIP" >&2; exit 1; }

ZIP_NAME=$(basename "$ZIP")
SIZE=$(stat -c%s "$ZIP")
SHA256=$(sha256sum "$ZIP" | cut -d' ' -f1)
# Build timestamp from zip mtime (Updater matches on this; must be newer than installed)
DATETIME=$(stat -c%Y "$ZIP")
# SPL + SDK level from build prop if present in the zip
PROPS=$(unzip -p "$ZIP" SYSTEM/etc/prop.default 2>/dev/null || true)
SPL=$(echo "$PROPS" | grep '^ro.build.version.security_patch=' | cut -d= -f2 || true)
SDK=$(echo "$PROPS" | grep '^ro.build.version.sdk=' | cut -d= -f2 || true)
SPL="${SPL:-unknown}"
SDK="${SDK:-36}"

URL="https://github.com/NopeNix/d2s-crdroid16/releases/latest/download/${ZIP_NAME}"

python3 - "$ZIP_NAME" "$DATETIME" "$SHA256" "$SIZE" "$VERSION" "$BUILDTYPE" "$URL" "$SPL" "$SDK" <<'EOF'
import json, sys
(name, dt, sha, size, version, buildtype, url, spl, sdk) = sys.argv[1:]
entry = {
    "maintainer": "Nopenix",
    "oem": "Samsung",
    "device": "Galaxy Note10+",
    "filename": name,
    "download": url,
    "timestamp": int(dt),
    "sha256": sha,
    "size": int(size),
    "version": version,
    "buildtype": buildtype,
    "os_patch_level": spl,
    "os_sdk_level": int(sdk),
}
print(json.dumps({"response": [entry]}, indent=2))
EOF
