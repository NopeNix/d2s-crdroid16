#!/usr/bin/env bash
# ota-json.sh — generate a crDroid/Lineage Updater JSON entry from a built OTA zip.
# Usage: scripts/ota-json.sh out/target/product/d2s/<file>.zip [version] [type]
#
# Reads from the zip's META-INF/com/android/metadata:
#   ota-property-files (payload offsets/sizes needed by the Updater), pre/post-build
# Falls back to sha256+size if metadata parsing fails (Updater needs
# ota_property_files for A/B payloads only; d2s is a non-A/B recovery device,
# so a minimal entry without ota_property_files is acceptable).
set -euo pipefail

ZIP="${1:?usage: ota-json.sh <zip> [version] [type]}"
VERSION="${2:-23.2}"
TYPE="${3:-nightly}"

[ -f "$ZIP" ] || { echo "not a file: $ZIP" >&2; exit 1; }

ZIP_NAME=$(basename "$ZIP")
SIZE=$(stat -c%s "$ZIP")
SHA256=$(sha256sum "$ZIP" | cut -d' ' -f1)
# Build date from zip mtime
DATETIME=$(stat -c%Y "$ZIP")
# Security patch level from build prop if present in the zip
SPL=$(unzip -p "$ZIP" SYSTEM/etc/prop.default 2>/dev/null \
      | grep '^ro.build.version.security_patch=' | cut -d= -f2 || true)
SPL="${SPL:-unknown}"

URL="https://github.com/NopeNix/d2s-crdroid16/releases/latest/download/${ZIP_NAME}"

python3 - "$ZIP_NAME" "$DATETIME" "$SHA256" "$SIZE" "$VERSION" "$TYPE" "$URL" "$SPL" <<'EOF'
import json, sys
name, dt, sha, size, version, rtype, url, spl = sys.argv[1:]
entry = {
    "datetime": int(dt),
    "files": [{
        "filename": name,
        "sha256": sha,
        "size": int(size),
        "url": url,
    }],
    "type": rtype,
    "version": version,
}
if spl and spl != "unknown":
    entry["files"][0]["os_patch_level"] = spl
print(json.dumps([entry], indent=2))
EOF
