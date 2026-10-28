# Build guide — Nopenix crDroid 16 for d2s (local build)

> Status: executed end-to-end (v13, 2026-10-25); the practical flash-day gotchas live in
> `MEMORY.md` and `docs/flash-day-handover-*.md`.

> **Two variants (docs/dev-prod.md)**: dev = `userdebug` + `BUILD_BROKEN_DUP_SYSPROP=true`
> (adb-root works, playground, CURRENT MAIN GOAL). prod = hardened build + Magisk
> (added after dev is done). This guide documents the proven debug (dev) flow;
> prod-variant steps get added when first executed.

## Hardware requirements

Full Android build of this size:

- **Disk**: ≥ 250 GB free (repo sync alone is 100–200 GB; build adds 100+ GB).
  SSD strongly recommended.
- **RAM**: 32 GB comfortable, 16 GB workable with swap; ccache helps a lot on rebuilds.
- **CPU**: 8+ cores; expect 2–6 h per full build.
- **OS**: Ubuntu 22.04/24.04 (x86_64).

GitHub-hosted runners are NOT usable (≈84 GB disk, ≈7 GB RAM, 6 h limit) — that's why
builds happen locally and releases are pushed manually.

## 1. Install dependencies

```bash
sudo apt update
sudo apt install -y bc bison build-essential ccache curl flex g++-multilib gcc-multilib \
  git git-lfs gnupg gperf imagemagick lib32ncurses-dev lib32readline-dev lib32z1-dev \
  liblz4-tool libncurses6 libncurses-dev libsdl1.2-dev libssl-dev libwxgtk3.2-dev \
  libxml2 libxml2-utils lzop pngcrush rsync schedtool squashfs-tools xsltproc zip zlib1g-dev
```

Install `repo`:

```bash
mkdir -p ~/bin
curl https://storage.googleapis.com/git-repo-downloads/repo > ~/bin/repo
chmod a+x ~/bin/repo
echo 'export PATH=~/bin:$PATH' >> ~/.bashrc && source ~/.bashrc
```

## 2. Git identity (required for repo to work)

```bash
git config --global user.name  "Your Name"
git config --global user.email "you@example.com"
```

## 3. Init + sync the source tree

```bash
mkdir -p ~/android/nopenix-d2s && cd ~/android/nopenix-d2s

repo init -u https://github.com/crdroidandroid/android.git -b 16.0 --git-lfs --no-clone-bundle

mkdir -p .repo/local_manifests
curl -o .repo/local_manifests/nopenix.xml \
  https://raw.githubusercontent.com/NopeNix/d2s-crdroid16/main/manifests/nopenix.xml

repo sync -c --force-sync --no-clone-bundle --no-tags -j$(nproc)
```

What the local manifest adds (details in `manifests/nopenix.xml`): the five NopeNix
device/kernel/vendor forks + the Lineage hardware/sepolicy dependencies at `lineage-23.2`.

## 4. Prepare build keys (first time only)

See `docs/signing.md`. Keys live in `~/.android-certs/` — never inside any repo.

## 5. Build

```bash
. build/envsetup.sh
brunch d2s            # = lunch lineage_d2s-userdebug + mka bacon
```

Output zip lands in `out/target/product/d2s/` as
`lineage-23.2-<date>-d2s-v<nopenix version>.zip` (naming is governed by our branding
overrides — see `docs/branding.md`).

Useful variants:

```bash
lunch lineage_d2s-userdebug   # pick target explicitly
mka bacon -j$(nproc)          # full package
mka target-files-package      # for proper signed release flow (see docs/signing.md)
export USE_CCACHE=1 && ccache -M 100G   # big win on rebuilds
```

## 6. Post-build: OTA JSON + release

```bash
scripts/ota-json.sh out/target/product/d2s/<zip>   # generates the Updater JSON snippet
```

Then follow `docs/release.md` and `docs/ota.md`.

## 7. First flash onto the phone (one-time, manual)

Documented in `docs/ota.md` §"First install of a Nopenix build". Summary: flash our
recovery via heimdall/Odin, sideload the signed zip once; every later update goes through
the built-in Updater app.

## Troubleshooting notes

(To be filled by whoever executes the first build. Append gotchas to MEMORY.md too.)

- If `repo sync` hits a project that exists upstream but not in the local manifest, the
  crDroid base manifest covers it — only device/kernel/vendor/HW deps come from ours.
- Blob-related build failures: re-check `docs/blob-strategy.md` fallback ladder.
