#!/usr/bin/env bash
# sync.sh — initialize/sync the crDroid 16.0 tree with the Nopenix local manifest.
# Usage: run inside an empty or existing build dir. Assumes `repo` is on PATH.
set -euo pipefail

MANIFEST_URL="${MANIFEST_URL:-https://raw.githubusercontent.com/NopeNix/d2s-crdroid16/main/manifests/nopenix.xml}"

if [ ! -d .repo ]; then
  repo init -u https://github.com/crdroidandroid/android.git -b 16.0 --git-lfs --no-clone-bundle
fi

mkdir -p .repo/local_manifests
curl -fsSL -o .repo/local_manifests/nopenix.xml "$MANIFEST_URL"

repo sync -c --force-sync --no-clone-bundle --no-tags -j"$(nproc)"
