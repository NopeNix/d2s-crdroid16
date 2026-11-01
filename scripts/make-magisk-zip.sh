#!/usr/bin/env bash
# make-magisk-zip.sh — build the Nopenix Signed Magisk Zip (official workstream,
# 2026-11-01, docs/proposals/2026-11-01-signed-magisk-zip.md).
#
# Takes a SIGNED target-files zip (the same one ota_from_target_files consumed),
# patches its boot.img with a pinned Magisk via magiskboot, wraps it in a
# flashable shell-script zip, signs it with the Nopenix releasekey so that OUR
# recovery accepts it via adb sideload — on BOTH dev and prod installs (same
# signing keys, docs/signing.md). Never referenced by ota/*.json; release-asset
# only. Flashing on prod is the owner's explicit manual choice (warned in-script).
#
# Usage:
#   scripts/make-magisk-zip.sh <signed-target-files.zip> <variant dev|prod> <outdir> <datestamp>
#
# Requires on the host (cache dir /srv/android/magisk-toolchain/, auto-populated
# on first run — needs network ONCE per pin bump):
#   unzip, python3, java (for signapk, found via $SRC/out/host/linux-x86)
set -euo pipefail

# ------------------------------------------------------------- pin ----
# Pinned Magisk release (bump deliberately, one-line change + release note).
# sha256 verified against the release APK on 2026-11-01.
MAGISK_TAG=v31.1
MAGISK_SHA256=89cefac0a318afa39fb3880c45c87b036c05bc1ebf02a7a715b7f8d7c26ac6e7
MAGISK_URL="https://github.com/topjohnwu/Magisk/releases/download/${MAGISK_TAG}/Magisk-${MAGISK_TAG}.apk"
TOOLCHAIN_DIR=${MAGISK_TOOLCHAIN_DIR:-/srv/android/magisk-toolchain/${MAGISK_TAG}}

TF="${1:?usage: make-magisk-zip.sh <signed-target-files.zip> <dev|prod> <outdir> <YYYYMMDD>}"
VARIANT="${2:?usage: make-magisk-zip.sh <signed-target-files.zip> <dev|prod> <outdir> <YYYYMMDD>}"
OUTDIR="${3:?usage: make-magisk-zip.sh <signed-target-files.zip> <dev|prod> <outdir> <YYYYMMDD>}"
DATESTAMP="${4:?usage: make-magisk-zip.sh <signed-target-files.zip> <dev|prod> <outdir> <YYYYMMDD>}"
KEYS="${NOPENIX_CERTS:-$HOME/.android-certs}"
SRC="${NOPENIX_SRC:-/srv/android/nopenix-d2s}"
SIGNAPK="$SRC/out/host/linux-x86/framework/signapk.jar"

[ "$VARIANT" = dev ] || [ "$VARIANT" = prod ] || { echo "variant must be dev|prod" >&2; exit 2; }
[ -f "$TF" ] || { echo "not a file: $TF" >&2; exit 1; }
[ -d "$KEYS" ] || { echo "signing keys missing: $KEYS" >&2; exit 1; }
[ -f "$SIGNAPK" ] || { echo "signapk.jar not found (run the build first): $SIGNAPK" >&2; exit 1; }

log() { echo "[$(date -u +%H:%M:%S)] $*"; }

# ------------------------------------------------- toolchain fetch ----
mkdir -p "$TOOLCHAIN_DIR"
APK="$TOOLCHAIN_DIR/Magisk-${MAGISK_TAG}.apk"
if [ ! -f "$APK" ]; then
  log "fetching pinned Magisk $MAGISK_TAG (one-time per pin)"
  curl -fsSL -o "$APK" "$MAGISK_URL"
fi
if [ "$MAGISK_SHA256" = "REPLACE_WITH_SHA256_OF_APK_BEFORE_FIRST_USE" ]; then
  log "PIN UNVERIFIED: set MAGISK_SHA256 to:"; sha256sum "$APK" | cut -d' ' -f1
  exit 1
fi
echo "$MAGISK_SHA256  $APK" | sha256sum -c - || { log "Magisk APK sha256 mismatch — refusing"; exit 1; }

# Patch payload (v31.1 layout — verified 2026-11-01): magiskboot/magiskinit as
# lib*.so in lib/arm64-v8a/; the magisk binary is libmagisk.so (single-binary
# layout, no more magisk64/magisk32 split); stub + config injected via
# assets/boot_patch.sh logic. We replicate the minimal set magiskinit needs.
BIN="$TOOLCHAIN_DIR/bin"; mkdir -p "$BIN"
[ -x "$BIN/magiskboot" ] || {
  unzip -qo "$APK" 'lib/arm64-v8a/*' 'assets/*' -d "$TOOLCHAIN_DIR/apk"
  cp "$TOOLCHAIN_DIR/apk/lib/arm64-v8a/libmagiskboot.so" "$BIN/magiskboot"
  cp "$TOOLCHAIN_DIR/apk/lib/arm64-v8a/libmagiskinit.so" "$BIN/magiskinit"
  chmod +x "$BIN/magiskboot" "$BIN/magiskinit"
}
# config the patched image expects (magiskinit reads it at boot)
printf 'KEEPFORCEENCRYPT=true\nKEEPVERITY=true\nRECOVERYMODE=false\n' > "$TOOLCHAIN_DIR/config"

# ------------------------------------------------- extract boot.img ----
WORK=$(mktemp -d /tmp/magiskzip.XXXXXX)
trap 'rm -rf "$WORK"' EXIT
unzip -qo "$TF" 'IMAGES/boot.img' -d "$WORK"
[ -s "$WORK/IMAGES/boot.img" ] || { log "IMAGES/boot.img missing in TF"; exit 1; }

log "patching boot.img with magiskboot (pinned $MAGISK_TAG)"
mkdir -p "$WORK/magisk_new"
cp "$BIN/magiskinit" "$WORK/magisk_new/init.so"
cp "$TOOLCHAIN_DIR/apk/lib/arm64-v8a/libmagisk.so" "$WORK/magisk_new/magisk"
cp "$TOOLCHAIN_DIR/apk/assets/stub.xz" "$WORK/magisk_new/stub.xz" 2>/dev/null \
  || cp "$TOOLCHAIN_DIR/apk/lib/arm64-v8a/libstub.so" "$WORK/magisk_new/stub.xz" \
  || true   # v31.x embeds the stub inside libmagisk.so; not a separate file
cp "$TOOLCHAIN_DIR/config" "$WORK/magisk_new/config"
cp "$WORK/IMAGES/boot.img" "$WORK/boot.img"
( cd "$WORK" && "$BIN/magiskboot" unpack boot.img >/dev/null \
  && cp -f magisk_new/config . && "$BIN/magiskboot" repack boot.img new-boot.img >/dev/null )

# ------------------------------------------------- assemble zip ----
ZIPOUT="$OUTDIR/Nopenix-magisk-$MAGISK_TAG-${VARIANT}-${DATESTAMP}-d2s.zip"
STAGE="$WORK/zip"
mkdir -p "$STAGE/META-INF/com/google/android"
cp "$WORK/new-boot.img" "$STAGE/magisk_boot.img"
printf '%s\n' "$MAGISK_TAG" > "$STAGE/magisk_version"

# update-binary: POSIX shell, run by recovery. Aborts on foreign ROMs; warns
# on prod; dd's the patched boot over the boot partition.
cat > "$STAGE/META-INF/com/google/android/update-binary" <<'EOF'
#!/system/bin/sh
# Nopenix Signed Magisk Zip updater (see docs/proposals/2026-11-01-signed-magisk-zip.md)
# AOSP recovery invokes: update-binary <api_version> <status_fd> <zip_path>
# (install.cpp SetUpNonAbUpdateCommands). Our recovery ramdisk has NO /sbin/sh
# — shebang MUST be /system/bin/sh (toybox); execve'd directly, ENOENT on a bad
# interpreter shows up as a bare "Installation aborted". (Gotcha 2026-11-01.)
API="$1"; OOB="$2"; ZIP="$3"
# recoveries vary; locate the zip payload via the standard ui_print path
OUTFD=$(readlink /proc/self/fd/"$OOB" 2>/dev/null || true)
ui_print() { echo "ui_print $1" > /proc/self/fd/"$OOB" 2>/dev/null || echo "$1"; }
getprop_() { getprop "$1" 2>/dev/null || true; }

BOOT_PART=/dev/block/by-name/boot
[ -b "$BOOT_PART" ] || BOOT_PART=/dev/block/bootdevice/by-name/boot

ui_print "Nopenix signed Magisk zip"
VARIANT=$(getprop_ ro.nopenix.variant)
if [ -z "$VARIANT" ]; then
  ui_print "ABORT: not a Nopenix build (ro.nopenix.variant empty)."
  ui_print "Refusing to patch a foreign boot image."
  exit 1
fi
if [ "$VARIANT" = prod ]; then
  ui_print "WARNING: this is the PROD (rootless daily driver) install."
  ui_print "Flashing Magisk roots it. The next OTA removes root again."
  ui_print "SELinux must stay enforcing. This is the owner's manual choice."
fi
[ -b "$BOOT_PART" ] || { ui_print "ABORT: boot partition not found"; exit 1; }
cd /tmp || exit 1
unzip -o "$ZIP" magisk_boot.img >/dev/null 2>&1 || { ui_print "ABORT: payload missing"; exit 1; }
ui_print "Writing patched boot image ..."
dd if=magisk_boot.img of="$BOOT_PART" bs=4M || { ui_print "ABORT: dd failed"; exit 1; }
sync
ui_print "Done. Reboot; check the Magisk app for 'Installed'."
exit 0
EOF
chmod 755 "$STAGE/META-INF/com/google/android/update-binary"

printf '# do nothing (all logic is in update-binary)\n' \
  > "$STAGE/META-INF/com/google/android/updater-script"

log "signing zip with Nopenix releasekey"
( cd "$STAGE" && zip -qr "$WORK/unsigned.zip" . )
# Same invocation releasetools uses (common.py): conscrypt needs
# -Djava.library.path=<HOST>/lib64 — the plain -jar form dies on
# UnsatisfiedLinkError (learned 2026-11-01).
java -Xmx4096m -Djava.library.path="$SRC/out/host/linux-x86/lib64" \
  -jar "$SIGNAPK" --min-sdk-version 26 \
  "$KEYS/releasekey.x509.pem" "$KEYS/releasekey.pk8" \
  "$WORK/unsigned.zip" "$ZIPOUT" || { log "signapk failed"; exit 1; }

mkdir -p "$OUTDIR"
( cd "$OUTDIR" && sha256sum "$(basename "$ZIPOUT")" >> SHA256SUMS-magisk )
log "staged: $ZIPOUT"
sha256sum "$ZIPOUT"
