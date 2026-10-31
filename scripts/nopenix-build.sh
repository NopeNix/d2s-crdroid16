#!/usr/bin/env bash
# nopenix-build.sh — CANONICAL build entry point for the Nopenix d2s ROM.
#
# This is the ONE script that builds everything. It is used identically by:
#   - the self-hosted GitHub Actions runner on this host (workflow
#     .github/workflows/nopenix-build.yml), and
#   - a local hand-run from the hub repo (bash scripts/nopenix-build.sh ...).
#
# It guarantees that both paths share the same source tree, ccache, output
# dirs and signing keys — no fork in the road, no runner-only divergence.
#
# Usage:
#   scripts/nopenix-build.sh [--variant dev|prod|both] [--sync-first]
#                            [--sign-only] [--skip-sign]
#
# Stages per variant:
#   1. target-files-package build (ccache-backed, ~2-3h warm)
#   2. sign_target_files_apks -> signed TF (~75-90 min)
#   3. ota_from_target_files  -> OTA zip
#   4. extract IMAGES/recovery.img
#   5. verify-ota-channel (hub script) on the signed TF
#   6. stage artifacts into $ART_DIR/<variant>/ + sha256 manifest
#
# Hard rules (see docs/dev-prod.md, docs/flash-day-handover-*.md):
#   - dev  flavor: userdebug, WITH_SU=true, BUILD_BROKEN_DUP_SYSPROP=true
#   - prod flavor: user,      WITH_SU=false, no debug knobs, rootless
#   - SELinux enforcing both lines; only the build-time vars above differ.
#   - NOTHING is published to ota/*.json or GitHub Releases by this script.
#     Publishing stays a human step (docs/release.md, DoD gate).
set -euo pipefail

# ---------------------------------------------------------------- paths ----
# Everything lives under /srv/android on this host. The runner and the
# hand-run MUST resolve to these same paths — that is the whole point.
SRC=/srv/android/nopenix-d2s
CCACHE_DIR=/srv/android/ccache
ART_DIR=/srv/android/ota61
LOG_DIR=/srv/android/logs
LOCK=/srv/android/.build.lock
HUB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(grep -oP '(?<=NOPENIX_VERSION := ).*' "$SRC/device/samsung/d2s/nopenix.mk" | head -1 || echo unknown)"
DATE=$(date +%Y%m%d)
KEYS="$HOME/.android-certs"

# ---------------------------------------------------------------- flags ----
VARIANT=both
SYNC_FIRST=0
SIGN_ONLY=0
SKIP_SIGN=0
while [ $# -gt 0 ]; do
  case "$1" in
    --variant) VARIANT="$2"; shift 2 ;;
    --sync-first) SYNC_FIRST=1; shift ;;
    --sign-only) SIGN_ONLY=1; shift ;;
    --skip-sign) SKIP_SIGN=1; shift ;;
    *) echo "unknown flag: $1" >&2; exit 2 ;;
  esac
done
case "$VARIANT" in dev|prod|both) ;; *) echo "bad --variant $VARIANT" >&2; exit 2 ;; esac

# ------------------------------------------------------------ pre-flight ----
mkdir -p "$LOG_DIR" "$ART_DIR"

# Disk guard: full TF + signed TF + OTA zip need ~20 GB free on /srv.
FREE_GB=$(df -BG --output=avail "$SRC" | tail -1 | tr -dc '0-9')
if [ "$FREE_GB" -lt 15 ]; then
  echo "REFUSING: only ${FREE_GB}G free on $SRC (need >=15G). Prune out/ or ota61/ first." >&2
  exit 1
fi

[ -d "$SRC/.repo" ] || { echo "REFUSING: $SRC is not a repo tree" >&2; exit 1; }
[ -d "$KEYS" ] || { echo "REFUSING: signing keys $KEYS missing" >&2; exit 1; }
[ -f "$HUB_DIR/scripts/verify-ota-channel.sh" ] || {
  echo "REFUSING: hub scripts/verify-ota-channel.sh not found next to this script" >&2; exit 1; }

# ------------------------------------------------------------------ lock ----
# Global build lock: a hand-run and an Actions-triggered run queue behind the
# SAME flock, so two builds can never stomp the shared out/.
exec 9>"$LOCK"
if ! flock -n 9; then
  echo "Another build is running (lock $LOCK held). Waiting..." >&2
  flock 9   # block until the other run finishes
fi
echo "[$(date -u)] lock acquired by $(whoami) pid $$"

# ------------------------------------------------------------------ env ----
export USE_CCACHE=1
export CCACHE_DIR
export SELINUX_IGNORE_NEVERALLOWS=true
export PATH="$HOME/bin:$PATH"
export TMPDIR=/srv/android/tmp
mkdir -p "$TMPDIR"

log()  { echo "[$(date -u +%H:%M:%S)] $*" | tee -a "$LOG_DIR/nopenix-build.log"; }
die()  { log "FATAL: $*"; exit 1; }

run_variant() {
  local v=$1
  local want_userdebug=0
  [ "$v" = dev ] && want_userdebug=1
  local VLOG="$LOG_DIR/${v}-tf.log"
  local SLOG="$LOG_DIR/${v}-sign.log"

  log "=== variant $v : TF build start (log $VLOG) ==="
  (
    cd "$SRC"
    export NOPENIX_VARIANT=$v
    if [ "$want_userdebug" = 1 ]; then
      export WITH_ADB_INSECURE=true WITH_SU=true BUILD_BROKEN_DUP_SYSPROP=true
    else
      export WITH_SU=false
    fi
    source build/envsetup.sh >/dev/null
    local rel; rel=$(cat vendor/lineage/vars/aosp_target_release)
    if [ "$want_userdebug" = 1 ]; then
      lunch "lineage_d2s-$rel-userdebug" >/dev/null
    else
      lunch "lineage_d2s-$rel-user" >/dev/null
    fi
    m target-files-package
  ) > "$VLOG" 2>&1 || die "variant $v: TF build failed (see $VLOG)"

  [ "$SKIP_SIGN" = 1 ] && { log "variant $v: skip-sign requested, TF left in out/"; return 0; }

  local TF="$SRC/out/target/product/d2s/obj/PACKAGING/target_files_intermediates/lineage_d2s-target_files.zip"
  [ -f "$TF" ] || die "variant $v: TF zip not found at $TF"

  log "=== variant $v : sign start (log $SLOG) ==="
  (
    cd "$SRC"
    export TOP="$SRC"
    source build/envsetup.sh >/dev/null
    local rel; rel=$(cat vendor/lineage/vars/aosp_target_release)
    if [ "$want_userdebug" = 1 ]; then
      lunch "lineage_d2s-$rel-userdebug" >/dev/null
    else
      lunch "lineage_d2s-$rel-user" >/dev/null
    fi
    local SIGNED="out/signed-tf-$v.zip"
    local OTA="out/ota-$v.zip"
    rm -rf out/tf-dir out/signed-tf-x
    mkdir -p out/tf-dir
    unzip -qo "$TF" -d out/tf-dir

    export PYTHONPATH="$SRC/external/avb:$SRC/system/apex/apexer:$SRC/system/apex/tools:$SRC/system/update_engine/scripts:$PYTHONPATH"
    export PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION=python
    export PATH="$SRC/out/host/linux-x86/bin:$PATH"
    python3 build/make/tools/releasetools/sign_target_files_apks.py \
      -o -d "$KEYS" "$TF" "$SIGNED"

    python3 build/make/tools/releasetools/ota_from_target_files.py \
      -k "$KEYS/releasekey" "$SIGNED" "$OTA"

    mkdir -p out/signed-tf-x
    unzip -qo "$SIGNED" 'IMAGES/recovery.img' -d out/signed-tf-x

    # channel gate (must print OK for the intended channel)
    bash "$HUB_DIR/scripts/verify-ota-channel.sh" "$SIGNED" "$v"
  ) > "$SLOG" 2>&1 || die "variant $v: sign failed (see $SLOG)"

  local SIGNED="out/signed-tf-$v.zip" OTA="out/ota-$v.zip" REC="out/signed-tf-x/IMAGES/recovery.img"
  local ODIR="$ART_DIR/staging/$v"
  mkdir -p "$ODIR"
  # Naming matches the published convention (docs/release.md):
  #   prod: nopenix-<ver>-<date>-d2s.zip   dev: Nopenix-dev-<ver>-<date>-d2s.zip
  local ZIPNAME
  if [ "$v" = dev ]; then ZIPNAME="Nopenix-dev-$VERSION-$DATE-d2s.zip"; else ZIPNAME="nopenix-$VERSION-$DATE-d2s.zip"; fi
  cp -f "$OTA"    "$ODIR/$ZIPNAME"
  cp -f "$REC"    "$ODIR/Nopenix-$v-$VERSION-$DATE-d2s-recovery.img"
  cp -f "$SIGNED" "$ODIR/nopenix-$VERSION-$DATE-$v-signed-target-files.zip"
  ( cd "$ODIR" && sha256sum *.zip *.img > SHA256SUMS )
  log "=== variant $v : staged to $ODIR ==="
  cat "$ODIR/SHA256SUMS"
}

# ------------------------------------------------------------------ main ----
log "nopenix-build start: variant=$VARIANT sync=$SYNC_FIRST sign-only=$SIGN_ONLY skip-sign=$SKIP_SIGN user=$(whoami)"

if [ "$SYNC_FIRST" = 1 ]; then
  log "repo sync (crDroid + NopeNix forks) ..."
  ( cd "$SRC" && repo sync -c --force-sync --no-clone-bundle --no-tags -j"$(nproc)" ) \
    > "$LOG_DIR/sync.log" 2>&1 || die "repo sync failed (see $LOG_DIR/sync.log)"
fi

if [ "$VARIANT" = both ]; then
  run_variant dev
  run_variant prod
else
  run_variant "$VARIANT"
fi

log "nopenix-build DONE. Artifacts staged under $ART_DIR/staging/<variant>/ — nothing published."
log "Human steps next: inspect, then publish per docs/release.md + docs/ota.md."
