# Proposal 2026-11-01 — Build always, serve selectively (dev + prod rescue policy)

**Status: DRAFT — awaiting owner approval. Nothing below is in effect until this
file is moved to APPROVED.**

**2026-11-01 amendment (owner-approved in session):** the destructive-operation
gate is now a standing rule — AGENTS.md rule 9 + the gate block in
`docs/dev-prod.md`. Wipes are recommendations only, never pre-authorized; every
occurrence needs explicit owner confirmation + a fresh backup.

## Background

The 2026-10-31 runner pipeline always builds dev TF + prod TF + both recoveries
and stages them. Publishing discipline previously stopped at staging. During
concept review (2026-11-01 session) the owner rejected a combined
"dev + prod chooser" in the Updater menu: on a single daily driver it makes the
userdebug dev build one accidental tap away from banking data, without solving
anything that recovery sideload does not already solve.

The real requirement that survived review: **a dev build must always exist
(staged + released) so a broken prod phone can be rescued with it. It must not
need to be built on demand.**

## Decisions proposed

1. **Build always, together.** Every green pipeline run produces dev TF, prod TF
   and both recoveries and stages them in `/srv/android/ota61/staging/{dev,prod}/`
   — unchanged. Never a build-on-demand rescue: if the phone is broken at the
   same moment the runner is broken, neither exists.
2. **Both lines published to GitHub Releases every run** (dev zip + recovery
   included). A rescue kit is only complete when it is released, not just staged
   locally.
3. **Only prod gets a `ota/prod.json` entry by default.** Dev is released but not
   served as a standing channel entry — the userdebug build must not sit one tap
   away from the daily driver's banking data.
4. **Debug episodes use explicit temporary entries.** When the phone needs a dev
   build for debugging, the agent appends a temporary dev entry to the channel
   (proven 2026-10-30 transition-entry pattern), debugs, then removes the entry.
   Alternative: recovery sideload of the released dev zip — needs no channel
   entry at all.
5. **Data policy unchanged in intent, hardened in wording.** Wiping userdata when
   entering dev is the *recommended default* — a recommendation to propose, never a
   pre-authorized action (see the destructive-operation gate: AGENTS.md rule 9 +
   `docs/dev-prod.md` gate block). Every wipe requires explicit owner confirmation
   in that session plus a fresh backup of the current device state made first.
6. **Release-asset retention.** Keep at least the last 2–3 prod builds + all
   their recoveries on GitHub Releases (last-known-good prod for sideload-back).
   Disk guards (auto-deletion) apply to local `/srv/android/ota61/` staging only,
   never to release assets.

## Consequences

- Updater stays a single-purity channel: prod.json only. No variant chooser.
- Dev builds exist at all times and are flashable, but are inert by default.
- Rescue path in a worst case: `adb reboot recovery` → sideload last-known-good
  prod (rollback) or released dev (debug); both always present as release assets.
- No changes to build pipeline, signing or variant identification.

## Files to change on approval

- `docs/dev-prod.md`: add "build always, serve selectively" + retention rules to
  the OTA channel design section.
- `docs/ota.md`: note that `ota/dev.json` entries are appended only during
  debugging episodes, not as a standing nightly channel.
- `docs/nopenix-build.md`: document that both lines are released every run and
  the 2–3 prod retention floor.
