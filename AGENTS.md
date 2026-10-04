# AGENTS.md — Read this FIRST, every session

This repository documents and drives the rebuild of **crDroid 16 (Android 16) for the
Samsung Galaxy Note10+ (SM-N975F, codename `d2s`, Exynos 9825)** as a community
continuation after the official maintainer (deuspivete) stopped building (last official
build: 2026-04-26, v12.9). Our builds are branded **Nopenix** and are security-patch
continuations only — **no new features**.

## Repo layout (hub-and-forks model — IMPORTANT)

This repo is the **hub**: docs, manifests, scripts, memory, release notes.
**The ROM source code lives in separate forked repos** under the `NopeNix` GitHub org:

| Repo | Purpose | Branch we use |
|---|---|---|
| `NopeNix/android_device_samsung_d2s` | d2s device tree | `16.0` |
| `NopeNix/android_device_samsung_exynos9820-common` | Exynos 9820/9825 common tree | `16.0` |
| `NopeNix/android_kernel_samsung_exynos9820` | Kernel | `16.0` |
| `NopeNix/proprietary_vendor_samsung_d2s` | d2s vendor blobs | `14.0` (+ see blob strategy) |
| `NopeNix/proprietary_vendor_samsung_exynos9820-common` | common vendor blobs | `13.0` (+ see blob strategy) |

All five are forks of `crdroidandroid/*` originals. Blob strategy (decided 2026-10-04):
**default to TheMuppets `lineage-23.2` blobs** (newest Samsung firmware extraction, matches
the Lineage 23.2 base of crDroid 16) with the crDroid 13.0/14.0 branches as fallback.
See `docs/blob-strategy.md`.

If a task mentions "the device tree" or "the kernel" without a path, it means one of the
fork repos above — NOT this repo. Changes there are made by cloning the fork, committing,
pushing to its `16.0` (or blob) branch.

## Rules for every LLM working here

1. **Read order**: `AGENTS.md` (this file) → `MEMORY.md` → the relevant file in `docs/`.
   `MEMORY.md` exists precisely so you do not repeat past mistakes. Read it before you plan.
2. **Planning mode**: unless the user explicitly says "go" / "execute", you are in
   planning-only mode. Research freely, but do not create, modify, push, or fork anything.
3. **Docs are living documents.** You are expected to improve them: if you discover
   something wrong, outdated, or missing in any file in `docs/`, `README.md`, or
   `manifests/`, you should propose the fix. **BUT**: propose first — summarize exactly
   what you will change in which file and wait for the user's approval before editing
   any documentation file. (Exception: `MEMORY.md`, see rule 4.)
4. **MEMORY.md is append-only and self-serve.** You do NOT need permission to append to
   `MEMORY.md` — you MUST append any gotcha, pitfall, dead end, root cause, or hard-won
   fact you encounter, so the next LLM doesn't fall into the same hole. Never delete or
   rewrite existing entries; append a dated entry at the TOP of the list (newest first)
   with a one-line date prefix. Keep entries short (2–5 lines each).
5. **No secrets in git.** Signing keys, API tokens, and credentials live outside this
   repo (e.g. `~/.android-certs/`). Document *where* they live and *how* to generate
   them, never the artifacts themselves.
6. **Git hygiene**: never push directly to a fork's branch without the user's OK unless
   the task explicitly includes it; use feature branches + PRs for anything non-trivial
   in the forks. The hub repo's `main` gets direct small doc commits only with approval.
7. **Verify claims against the sources.** When you touch manifests or device configs,
   re-check the upstream (`crdroidandroid/*`, `LineageOS/*`) before assuming.
8. **Goal discipline**: security-patch continuation + working OTA only. If a change adds
   features, flag it to the user and get explicit buy-in.

## The 60-second orientation for a new session

- What device? Samsung Galaxy Note10+ SM-N975F (Exynos 9825), codename `d2s`.
- What ROM? crDroid 16.0 (v12.x, Android 16, Lineage 23.2 base), forked and continued as "Nopenix".
- Where is the build recipe? `docs/build-guide.md` and `manifests/nopenix.xml`.
- How did the official builds work? `docs/history.md`.
- How do OTAs work and how do we serve them? `docs/ota.md`.
- How do I build locally and publish a release? `docs/build-guide.md` + `docs/release.md`.
- What has gone wrong before? `MEMORY.md`.
- What's the current state / what to do next? `docs/ROADMAP.md` and the latest entry in `releases/`.
