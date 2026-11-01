# releases/

One markdown note per published Nopenix build (nopenix-<version>.md): security patch level, changelog, sha256, link to the GitHub release. Empty until the first build.

## Standard release asset set (owner decision 2026-11-01)

Every release carries, per line (prod / dev):

- OTA **rootless** (`nopenix-…-d2s.zip` / `Nopenix-dev-…-d2s.zip`)
- OTA **rooted** (`…-d2s-ROOTED.zip`) — root that SURVIVES updates (build-time
  Magisk-patched boot). Installing the rootless OTA is the unroot path.
- `recovery.img` for that line
- signed Magisk zip `Nopenix-magisk-…-d2s.zip` (auxiliary: root an already
  installed rootless build without a full OTA; asset-only, never in channels)

The served channel (`ota/prod.json`) carries TWO entries per release — rootless
and rooted, distinguished by the `-rooted` version suffix; the Updater offers
both and the user chooses (docs/ota.md §Multiple entries).
