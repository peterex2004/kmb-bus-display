# Task

Current work contract for the dual-agent workflow. Claude (orchestrator) owns
this file; Codex executes against it. SPEC.md would be the technical source of
truth but none exists yet — CLAUDE.md governance applies.

## Objective
Harden the arrival-reminder latch so a **transient loss of ETA does not cause a
duplicate reminder**. Today, when a card's nearest ETA is briefly unavailable
(`nearestEta === null` for a cycle — a data gap, not the bus departing),
`evaluateReminder` clears the notified-bus latch; when the SAME bus's ETA returns
within the lead window, it fires a **second** notification for a bus the user was
already reminded about. Preserve the latch across transient null gaps.

## Background
North Star: **correctness of ETA/route data > simplicity > features.** A kiosk
that double-buzzes for one bus because of a one-cycle network hiccup is a
correctness defect (recorded as the #3 MINOR follow-up). The reminder decision is
already a pure function (`BoardLogic.evaluateReminder(state, now)`), so this is a
small, well-contained pure-logic change with pinned tests. The notified latch
(`notifiedEta`) is an **absolute epoch-ms timestamp**, so holding it through a
null gap is safe: any genuinely new/distinct bus has a later timestamp beyond
`REARM_TOLERANCE_MS` and still re-arms via the existing `newerBus` path.

## Scope
- `index.html` inline `<script>`, `BoardLogic` seam: the `nearestEta === null`
  branch of `evaluateReminder` (~L1516-1521). Change ONLY that null-handling so
  the latch is preserved instead of reset.
- `scripts/test-board.mjs`: add pinned regression tests for the transient-null
  hold + no-duplicate-fire behaviour.

## Out of scope
- The rest of `evaluateReminder` (lead threshold, `sameBus`/`newerBus` re-arm
  math, `REARM_TOLERANCE_MS`), the #3 fire channels (toast/vibrate/Notification),
  `nextReminderLead`, `compareBoardItems`, `evaluateFreshness`.
- `refreshETAs`/`fetchETA`, the 15s cadence, `apiFetch`, providers, per-item ETA
  render semantics (undefined/[]/null), persistence, `SHARE_KEYS`.
- New frameworks/bundlers/build/backend/keys/SW push. Unrelated refactors.

## Functional requirements
1. **Hold the latch through a transient null.** When `remindMe === true` and
   `nearestEta === null`, `evaluateReminder` must return
   `shouldNotify: false`, `minutes: null`, and **preserve** the incoming
   `notifiedEta` (i.e. `notifiedEta: finiteNumber(state.notifiedEta)`), NOT
   `null`. This keeps the notified-bus latch alive across brief data gaps.
2. **No duplicate fire on recovery.** After a null gap, when the SAME bus's ETA
   returns within the lead window, the held latch makes it `sameBus` →
   `shouldNotify: false`. The user is not re-notified for a bus they were already
   reminded about.
3. **Re-arm still works for a genuinely new bus.** A distinct later bus
   (`nearestEta > notifiedEta + REARM_TOLERANCE_MS`) after a null gap still
   re-arms and fires at its own threshold, exactly as today. Unarmed
   (`remindMe !== true`) still returns a cleared latch (`notifiedEta: null`).
4. **No regression** to any existing #3 reminder behaviour, #5 lead-time,
   ordering, freshness, cadence, or persistence.

## Non-functional requirements
- Correctness: the new behaviour is pinned by regression tests against the real
  vm-extracted `BoardLogic`. Pure function unchanged in shape (takes `now`; no
  `Date.now()`/DOM). No build step; O(1) decision. i18n/UI unaffected (no UI
  change expected).

## Acceptance criteria
- Validation gate green (below) with the new tests **run, not skipped**; every
  existing ordering + reminder + lead-cycle + freshness test still passes
  unchanged.
- Tests assert at minimum: (a) armed + `nearestEta === null` with a non-null
  incoming `notifiedEta` returns `shouldNotify:false, notifiedEta:<preserved>,
  minutes:null`; (b) a full sequence — fire at lead → one null-gap cycle →
  same bus returns within lead — fires exactly **once** (second evaluation
  `shouldNotify:false`); (c) a distinct later bus after a null gap still re-arms
  and fires; (d) unarmed still clears the latch.

## Required validation
node scripts/validate-js.js
<!-- Plus the new pinned tests, wired to run and fail non-zero on regression.
     No UI change expected; if any UI is touched, add a preview check. Do NOT
     weaken the definition of "passing". -->

## Risk classification
LOW–MEDIUM — a one-branch change to the reminder fire logic in the single
production file. Small surface, but it touches correctness-critical code, so the
no-duplicate-fire path must be pinned by tests. Proceeds automatically; final
merge stays human-controlled.

## Human approval requirements
None to proceed. Human owns the final merge (auto-merge off).

## Open questions
- None blocking. The latch is an absolute timestamp, so an indefinite hold
  through sustained null is safe (a real new bus is always a later timestamp);
  no time-boxing of the hold is required. Note this in the report if you deviate.
