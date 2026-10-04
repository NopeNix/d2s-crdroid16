#!/usr/bin/env bash
# build.sh — convenience wrapper around envsetup + brunch for d2s.
# Usage: scripts/build.sh [--sync-first]
set -euo pipefail

if [ "${1:-}" = "--sync-first" ]; then
  "$(dirname "$0")/sync.sh"
fi

. build/envsetup.sh
brunch d2s
