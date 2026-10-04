# MEMORY.md — LLM learnings log (append-only, newest first)

> Rules: Every agent MUST append new gotchas/pitfalls/facts here (no permission needed for
> appending). Never delete or rewrite existing entries. Date-prefix each entry. Keep it short.
> Longer write-ups belong in `docs/` (ask permission for those).

- 2026-10-04 — The official d2s maintainer is Pedro Araujo "deuspivete" (not FreeRunner2017 —
  FreeRunner is a different Note10-series maintainer from earlier ROMs). deuspivete's local
  manifest / exact build recipe was never published; OTA JSON in crdroidandroid/android_vendor_crDroidOTA
  (branch 16.0, `d2s.json`) links the three device repos but not blobs.
- 2026-10-04 — crdroidandroid proprietary blob repos (proprietary_vendor_samsung_d2s &
  _exynos9820-common) only have branches 13.0/14.0, far behind the Lineage-23.2 base of
  crDroid 16. TheMuppets has lineage-23.2 blobs for both → default blob source (decided).
- 2026-10-04 — GitHub-hosted runners cannot build this ROM (~84 GB disk, ~7 GB RAM, 6 h job
  limit vs 150+ GB / 16+ GB RAM needs). Builds happen locally; releases pushed manually.
- 2026-10-04 — Updater app (crDroid/Lineage) matches OTA JSON `version` against
  `ro.lineage.build.version` — do NOT rename PRODUCT_NAME away from `lineage_d2s` or OTA
  version matching breaks. Brand via props/display strings instead (see docs/branding.md).
- 2026-10-04 — First Nopenix build cannot be OTA'd directly from official crDroid 12.9:
  official recovery trusts crDroid release keys only. Path = flash our recovery + sideload
  once manually; afterwards Updater works (see docs/ota.md).
- 2026-10-04 — VoLTE/VoWiFi are known-broken on the exynos9820 family in all these ROMs;
  do not treat as a regression we introduced.
- 2026-10-04 — Beware confusion: `a10` / A10s (SM-A107F) are DIFFERENT Samsung devices.
  crDroid's `d2s` = Galaxy Note10+ (SM-N975F). Some XDA threads mix these; trust the OTA JSON
  and device repos, not thread titles.
