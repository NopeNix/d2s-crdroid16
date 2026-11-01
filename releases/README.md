# releases/

One markdown note per published Nopenix build (nopenix-<version>.md): security patch level, changelog, sha256, link to the GitHub release. Empty until the first build.

Each GitHub release also carries the **signed Magisk zip** (`Nopenix-magisk-<tag>-<variant>-<date>-d2s.zip`, official workstream 2026-11-01): sideloadable from our own recovery on both dev and prod installs, root is opt-in and removed by every OTA (re-sideload after updating). Spec: `docs/proposals/2026-11-01-signed-magisk-zip.md`; never referenced in `ota/*.json`.
