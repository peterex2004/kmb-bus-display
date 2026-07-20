# Backlog — 九巴/城巴班次顯示 (KMB/CTB Bus Display)

Planning backlog for the dual-agent workflow. Priority order (per `CLAUDE.md`):
**correctness of ETA/route data > simplicity (no build step) > breadth of
features.** `docs/task.md` holds the *current* work contract; this file is the
standing list. Item numbers are stable labels, not priority.

---

## Shipped (on production `main`)

- **#1 — Soonest-first ordering** (PR #2) — board cards sort by nearest ETA,
  stable for ties, unavailable cards sink. *Fare display was descoped out of
  this item (see Candidate #A).*
- **#3 — Arrival reminder / per-card bell** (PR #3) — while-open foreground
  reminder: toast + `navigator.vibrate` + `Notification`, pure latch/re-arm in
  `BoardLogic.evaluateReminder`.
- **#4 — Fetch-health / stale-data indicator** (PR #4) — "更新" time reflects the
  last *successful* refresh; amber bilingual stale banner past `STALE_AFTER_MS`
  (60s); pure `BoardLogic.evaluateFreshness`.
- **#5 — Per-card reminder lead time** (PR #5) — single bell cycles
  Off → 3 → 5 → 10 → Off via pure `BoardLogic.nextReminderLead`; per-card
  `remindLeadMin` drives the existing reminder fire logic; persisted + backfilled.
- **#6 — Reminder re-arm hardening** (PR #6, was Candidate C) — a transient
  `nearestEta === null` gap no longer resets the latch, so an already-notified
  bus doesn't double-fire when its ETA returns; genuine re-arm preserved. Pure
  one-branch change in `BoardLogic.evaluateReminder` + pinned no-duplicate-fire
  tests.
- **#7 — Stale-banner 1s tick** (PR #7, was Candidate B) — a display-only 1s
  timer re-renders the freshness line only while stale (self-stopping on
  recovery/empty; no fetch-cadence change). **Honest scope note:** because the
  board is only "stale" at age ≥ 60s (`STALE_AFTER_MS`) and `formatFreshnessAge`
  shows minutes from 60s, the banner stays in the *minutes* range while stale —
  so the tick sharpens the minute rollover (lands within ~1s of the true
  boundary) rather than showing per-second *seconds*. Making seconds visible
  would need a deliberate #4 threshold/formatter change (not done).
- **#8 — Visibility-aware refresh** (PR #8, was Candidate D) — on tab hide,
  pauses both the 15s refresh loop and the #7 stale tick (zero background
  network); on show, resumes with one immediate refresh + the 15s cadence, but
  only while the board screen is active. Pure `BoardLogic.shouldRunBackground`
  predicate + pinned truth table. Visibility only (no Battery/Page-Lifecycle).

## In flight

- _(none — PRs #6/#7/#8 merged)_

---

## Candidate items (not yet scoped; human confirms scope + priority)

### A. Fare display (票價) — BLOCKED / descoped (2026-07-20)
Show per-route / per-section fare on each board card. **Blocked: no viable
official client-side data source.** Verified: fares are not in either real-time
API (KMB `data.etabus.gov.hk` / Citybus `rt.data.gov.hk` = route/stop/ETA only);
the sole official source is TD "Routes and fares"
(`static.data.gov.hk/td/routes-fares-geojson/JSON_BUS.json`) which is **74.8 MB**
and serves **no CORS** header (browser fetch blocked), updated biweekly. Doing it
correctly + simply from official client-side sources isn't possible today.
Reopening requires a human architecture decision (see
`.agent-output/human-escalation.md`): (B) approve a one-time vendoring/build step
that commits a slimmed `fares.json`, or (C) approve a third-party dataset
(`hkbus/hk-bus-crawling`). Until then: **descoped**. Risk if reopened: MEDIUM.

_(Candidates B, C, D shipped as #7, #6, #8 respectively — see "Shipped" above.)_

### E. Manual card reorder
Drag-to-reorder within the existing edit mode (order is currently ETA-driven
only). Persist an explicit ordering. Interaction with #1 auto-sort needs a
decision (manual overrides auto?, or a pinned-manual mode). Risk: MEDIUM.

### F. Offline last-known cache
When the network is fully down, show the last-good ETAs greyed out (complements
#4's stale indicator) instead of only "—". localStorage-backed; no backend.
Risk: MEDIUM.

---

## Notes
- No committed backlog existed before this file; earlier item numbers lived in
  the planning conversation. This file makes the list durable.
- Every item follows the same flow: promote to `docs/task.md` on a fresh
  `agent/<slug>` branch cut from the current `origin/main`, write a Codex work
  order, dispatch, independently re-validate, review, human-merge.
