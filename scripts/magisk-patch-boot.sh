#!/usr/bin/env bash
# magisk-patch-boot.sh — THE canonical Magisk boot-image patch sequence for
# Nopenix (single source of truth; both make-magisk-zip.sh and make-rooted-ota.sh
# call this). Faithful re-implementation of Magisk's assets/boot_patch.sh for a
# non-A/B Samsung arm64 target (d2s), pinned MAGISK_TAG in make-magisk-zip.sh.
#
# History: v1 of the magisk zip repacked a stock ramdisk (silent no-op — phone
# booted unrooted). v2 fixed shebang/args of update-binary but the PATCH was
# still incomplete. This helper carries the full, on-device-verified sequence.
#
# Usage: magisk-patch-boot.sh <workdir-with-boot.img> [<out-name>]
#   workdir must contain boot.img; magiskboot + magisk payload files are added
#   to the workdir; result: <workdir>/<out-name or new-boot.img>
# Env: MAGISK_TOOLCHAIN_DIR (default /srv/android/magisk-toolchain/<tag from
#   make-magisk-zip.sh>), KEEPVERITY/KEEPFORCEENCRYPT/PATCHVBMETAFLAG exported.
set -euo pipefail

WORK="${1:?usage: magisk-patch-boot.sh <workdir-with-boot.img> [out-name]}"
OUTNAME="${2:-new-boot.img}"
BIN="$MAGISK_TOOLCHAIN_DIR/bin"
MAGISK_LIB="$MAGISK_TOOLCHAIN_DIR/apk/lib/arm64-v8a"
[ -x "$BIN/magiskboot" ] || { echo "magiskboot missing in $BIN" >&2; exit 1; }
[ -f "$MAGISK_LIB/libmagiskinit.so" ] || { echo "magisk payload missing in $MAGISK_LIB" >&2; exit 1; }

cd "$WORK"
[ -f boot.img ] || { echo "no boot.img in $WORK" >&2; exit 1; }
cp "$BIN/magiskboot" .
cp "$MAGISK_LIB/libmagiskinit.so" magiskinit
cp "$MAGISK_LIB/libmagisk.so" magisk
cp "$MAGISK_LIB/libinit-ld.so" init-ld
chmod 755 magiskboot magiskinit magisk init-ld

"$BIN/magiskboot" unpack boot.img >/dev/null || { echo "unpack failed" >&2; exit 1; }
STATUS=$("$BIN/magiskboot" cpio ramdisk.cpio test >/dev/null 2>&1; echo $?)
[ "$STATUS" = 0 ] || { echo "unexpected cpio status $STATUS (1=already patched, 2=unsupported)" >&2; exit 1; }
"$BIN/magiskboot" sha1 boot.img > sha1.txt

# magiskboot cpio 'patch' reads these from the ENVIRONMENT (boot_patch.sh
# exports them); the config file is for magiskinit at boot.
: "${KEEPVERITY:=true}"; : "${KEEPFORCEENCRYPT:=true}"; : "${PATCHVBMETAFLAG:=false}"
export KEEPVERITY KEEPFORCEENCRYPT PATCHVBMETAFLAG
cat > config <<EOF
KEEPVERITY=$KEEPVERITY
KEEPFORCEENCRYPT=$KEEPFORCEENCRYPT
RECOVERYMODE=false
VENDORBOOT=false
SHA1=$(cat sha1.txt)
EOF

"$BIN/magiskboot" compress=xz magisk magisk.xz
"$BIN/magiskboot" compress=xz init-ld init-ld.xz

cp ramdisk.cpio ramdisk.cpio.orig
"$BIN/magiskboot" cpio ramdisk.cpio \
  "add 0750 init magiskinit" \
  "mkdir 0750 overlay.d" \
  "mkdir 0750 overlay.d/sbin" \
  "add 0644 overlay.d/sbin/magisk.xz magisk.xz" \
  "add 0644 overlay.d/sbin/init-ld.xz init-ld.xz" \
  "patch" \
  "backup ramdisk.cpio.orig" \
  "mkdir 000 .backup" \
  "add 000 .backup/.magisk config" \
  || { echo "cpio patch failed" >&2; exit 1; }
rm -f ramdisk.cpio.orig config magisk.xz init-ld.xz

# Samsung kernel patches from boot_patch.sh (Exynos 9825 needs all three):
# RKP removal, defex bypass (execve -221 -> -32768), PROCA rename.
RKP_OLD=49010054011440B93FA00F71E9000054010840B93FA00F7189000054001840B91FA00F7188010054
RKP_NEW=A1020054011440B93FA00F7140020054010840B93FA00F71E0010054001840B91FA00F7181010054
DEFEX_OLD=821B8012
DEFEX_NEW=E2FF8F12
PROCA_OLD=70726F63615F636F6E66696700
PROCA_NEW=70726F63615F6D616769736B00
PATCHED=0
if "$BIN/magiskboot" hexpatch kernel "$RKP_OLD" "$RKP_NEW" 2>/dev/null; then PATCHED=1; fi
if "$BIN/magiskboot" hexpatch kernel "$DEFEX_OLD" "$DEFEX_NEW" 2>/dev/null; then PATCHED=1; fi
if "$BIN/magiskboot" hexpatch kernel "$PROCA_OLD" "$PROCA_NEW" 2>/dev/null; then PATCHED=1; fi
if [ "$PATCHED" = 0 ]; then
  rm -f kernel   # nothing to patch: keep raw kernel (boot_patch.sh behavior)
fi

"$BIN/magiskboot" repack boot.img "$OUTNAME" >/dev/null || { echo "repack failed" >&2; exit 1; }
echo "patched: $WORK/$OUTNAME"
