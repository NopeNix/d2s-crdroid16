#!/usr/bin/env bash
# make-rooted-ota.sh — build the ROOTED flavor of a Nopenix OTA from a signed
# target-files zip (official workstream, owner decision 2026-11-01: the release
# matrix is rootless + rooted per line; the Updater offers both as channel
# entries — see docs/dev-prod.md + docs/ota.md).
#
# Method: unzip the SIGNED TF, overwrite IMAGES/boot.img with the Magisk-patched
# boot (shared sequence in scripts/magisk-patch-boot.sh), rezip the TF, then run
# the standard ota_from_target_files — so the rooted OTA is a completely normal
# OTA package whose boot payload simply happens to boot magiskinit. Same
# releasekey, same SPL, same everything else.
#
# Usage: make-rooted-ota.sh <signed-target-files.zip> <dev|prod> <outdir> <YYYYMMDD>
set -euo pipefail

TF="${1:?usage: make-rooted-ota.sh <signed-tf.zip> <dev|prod> <outdir> <YYYYMMDD>}"
VARIANT="${2:?usage: make-rooted-ota.sh <signed-tf.zip> <dev|prod> <outdir> <YYYYMMDD>}"
OUTDIR="${3:?usage: make-rooted-ota.sh <signed-tf.zip> <dev|prod> <outdir> <YYYYMMDD>}"
DATESTAMP="${4:?usage: make-rooted-ota.sh <signed-tf.zip> <dev|prod> <outdir> <YYYYMMDD>}"
KEYS="${NOPENIX_CERTS:-$HOME/.android-certs}"
SRC="${NOPENIX_SRC:-/srv/android/nopenix-d2s}"
HUB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

[ "$VARIANT" = dev ] || [ "$VARIANT" = prod ] || { echo "variant must be dev|prod" >&2; exit 2; }
[ -f "$TF" ] || { echo "not a file: $TF" >&2; exit 1; }
[ -d "$KEYS" ] || { echo "signing keys missing: $KEYS" >&2; exit 1; }

log() { echo "[$(date -u +%H:%M:%S)] $*"; }
export MAGISK_TOOLCHAIN_DIR="${MAGISK_TOOLCHAIN_DIR:-/srv/android/magisk-toolchain/v31.1}"
export TMPDIR="${TMPDIR:-/srv/android/tmp}"
mkdir -p "$TMPDIR" "$OUTDIR"

WORK=$(mktemp -d "$TMPDIR/rootedota.XXXXXX")
trap 'rm -rf "$WORK"' EXIT

# ------------------------------------------------ envsetup + lunch ----
(
  cd "$SRC"
  export TOP="$SRC"
  set +u
  source build/envsetup.sh >/dev/null
  rel=$(sed -n "s/^aosp_target_release=//p" vendor/lineage/vars/aosp_target_release)
  if [ "$VARIANT" = dev ]; then
    lunch "lineage_d2s-$rel-userdebug" >/dev/null
  else
    lunch "lineage_d2s-$rel-user" >/dev/null
  fi
  export PATH="$SRC/out/host/linux-x86/bin:$PATH"
  export PYTHONPATH="$SRC/external/avb:$SRC/system/apex/apexer:$SRC/system/apex/tools:$SRC/system/update_engine/scripts:$PYTHONPATH"
  export PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION=python

  # --------------------------------------------- rooted TF ----
  cd "$WORK"
  log "unzipping signed TF (~3.3 GB)"
  rm -rf tf; mkdir tf
  unzip -qo "$TF" -d tf
  [ -f tf/IMAGES/boot.img ] || { log "IMAGES/boot.img missing"; exit 1; }

  log "patching boot.img (magiskboot, single-source sequence)"
  cp tf/IMAGES/boot.img boot.img
  bash "$HUB_DIR/scripts/magisk-patch-boot.sh" "$WORK" rooted-boot.img
  cp rooted-boot.img tf/IMAGES/boot.img
  # NOTE: do NOT touch tf/IMAGES/*.map — GetSparseImage REQUIRES system.map /
  # vendor.map / product.map / system_ext.map next to their .img files
  # (they describe those sparse images, never boot.img). Deleting them broke
  # ota_from_target_files with a GetSparseImage assert (learned 2026-11-01).

  log "rezipping rooted TF"
  ( cd tf && zip -qr "$WORK/signed-tf-rooted.zip" . )

  # ota_from_target_files needs out/tf-dir to mirror the input zip
  # (local PartitionMapFromTargetFiles patch — see MEMORY 2026-10-14).
  rm -rf "$SRC/out/tf-dir"
  unzip -qo "$WORK/signed-tf-rooted.zip" -d "$SRC/out/tf-dir"

  log "ota_from_target_files (rooted payload) — 15-30 min"
  python3 "$SRC/build/make/tools/releasetools/ota_from_target_files.py" \
    -k "$KEYS/releasekey" "$WORK/signed-tf-rooted.zip" "$WORK/ota-rooted.zip"
) > "$WORK/rooted.log" 2>&1 || { log "rooted OTA generation FAILED (see $WORK/rooted.log)"; tail -20 "$WORK/rooted.log"; exit 1; }
tail -5 "$WORK/rooted.log"

# ------------------------------------------------ stage + sha ----
VERSION="$(grep -oP '(?<=NOPENIX_VERSION := ).*' "$SRC/device/samsung/d2s/nopenix.mk" | head -1 || echo unknown)"
if [ "$VARIANT" = dev ]; then
  OUT="$OUTDIR/Nopenix-dev-$VERSION-$DATESTAMP-d2s-ROOTED.zip"
else
  OUT="$OUTDIR/nopenix-$VERSION-$DATESTAMP-d2s-ROOTED.zip"
fi
cp -f "$WORK/ota-rooted.zip" "$OUT"
log "staged: $OUT"
sha256sum "$OUT"
