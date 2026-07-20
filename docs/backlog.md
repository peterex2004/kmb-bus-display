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

## In flight

- _(none — PR #5 merged)_

---

## Candidate items (not yet scoped; human confirms scope + priority)

### A. Fare display (票價)
Show per-route / per-section fare on each board card. Explicitly **descoped**
from #1, not dropped — most "officially pending" item. Needs a fare data source
check (KMB/CTB fare API availability) before scoping. Risk: MEDIUM (new data
dependency).

### B. Per-second stale-age text
#4 MINOR follow-up: the stale "Xs ago" text currently ticks in 15s steps (the
refresh cadence). Drive a lightweight 1s timer while stale so the age counts
down per second, without changing the 15s fetch cadence. Risk: LOW.

### C. Reminder re-arm hardening
#3 MINOR follow-up: a transient `nearestEta === null` (brief data gap) can reset
the reminder latch, allowing a duplicate fire when data returns. Harden re-arm
to tolerate short null gaps. Pure-function change in `evaluateReminder` +
pinned tests. Risk: LOW–MEDIUM (touches fire logic — test carefully).

### D. Battery / visibility-aware refresh
Pause the 15s refresh loop when the tab/screen is hidden
(`document.visibilitychange`); resume + immediate refresh on focus. Kiosk power
saving; must not break freshness/reminder semantics. Risk: LOW–MEDIUM.

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
