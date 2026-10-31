# nopenix-build — unified build pipeline (runner + hand-run)

> Status: LIVE 2026-10-31. The old per-session wrapper scripts in
> `/srv/android/` (`build-start.sh`, `run-tf-prod.sh`, `run-sign-prod.sh`,
> `run-tf61.sh`, `run-build61.sh`) are superseded; `scripts/nopenix-build.sh`
> is the single canonical entry point. See `docs/dev-prod.md` for the
> dev/prod policy and `docs/release.md` for publishing.

## Principle: one script, two triggers, zero divergence

```
hand-run:  bash scripts/nopenix-build.sh --variant both
GitHub:    workflow_dispatch / push tag build/*  →  self-hosted runner [d2s]
                        └────────────┬────────────┘
                                     ▼
              scripts/nopenix-build.sh   ← THE canonical entry point
                                     │
        same source tree /srv/android/nopenix-d2s
        same ccache     /srv/android/ccache
        same keys       ~/.android-certs
        same artifacts  /srv/android/ota61/staging/<variant>/
        same global lock /srv/android/.build.lock  (flock — runs never collide)
```

A local run and an Actions run are byte-for-byte the same operation: same
env, same dirs, same logs (`/srv/android/logs/`), same staged output.
The runner does NOT re-clone the ROM tree; it only checks out the hub
(for scripts + the channel gate) and then drives the existing tree.

## What the pipeline does per variant

1. `target-files-package` build (`m target-files-package`) with the
   variant's env (`NOPENIX_VARIANT=dev|prod` etc. — see docs/dev-prod.md).
2. `sign_target_files_apks` → signed TF.
3. `ota_from_target_files` → OTA zip.
4. Extract `IMAGES/recovery.img` (always produced for BOTH variants).
5. `verify-ota-channel.sh` gate — asserts the baked Updater URL matches
   the variant's channel (`dev.json`/`prod.json`). Hard-fail on mismatch.
6. Stage into `/srv/android/ota61/staging/<variant>/` with `SHA256SUMS`.

`--variant both` (default) runs dev then prod, so the second build rides
the warm ccache.

## Triggers

- `workflow_dispatch` (manual, repo UI / `gh workflow run nopenix-build`)
  with `variant: dev|prod|both` and optional `sync-first` (runs `repo sync`
  of upstream crDroid + the NopeNix forks before building).
- `push` of a tag starting with `build/` (e.g. `build/both`) — builds
  `both`.
- NEVER on `pull_request` or `push` to `main` — the workflow drives local
  signing keys and a shared build tree. Manual dispatch + tag only.

## What it does NOT do

- No publishing to `ota/*.json` and no GitHub Release upload. The runner
  stages only; the DoD gate + publish remain a human step
  (`docs/release.md`, `docs/ota.md`).
- No auto-wipe of `out/` or `ota61/` (the disk guard refuses to start if
  `/srv` free < 15 GB; prune by hand first).

## Runner setup (already done on this host)

- Runner dir: `/srv/android/actions-runner` (org `NopeNix`, repo
  `d2s-crdroid16`, label `d2s`, runs as user `user`).
- Services: started/enabled via systemd user service
  (`~/.config/systemd/user/nopenix-runner.service`), `systemctl --user`
  managed; survives reboots.
- Repo is public — the runner runs on the maintainer's own machine, driven
  only by `workflow_dispatch` + tag push from `NopeNix` members (enforced
  by GitHub, not by repo file).

## Host hygiene

- `actions-runner` log rotation: `./config` with `--max-log-files 30`.
- The `_work` dir of the runner stays tiny (hub checkout only); all heavy
  output lands in `/srv/android/`.
- Outbox: the summary step in the Actions run lists staged sha256s and
  reminds that publishing is manual.
