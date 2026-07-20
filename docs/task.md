# Task

Current work contract for the dual-agent workflow. Claude (orchestrator) owns
this file; Codex executes against it. SPEC.md would be the technical source of
truth but none exists yet — CLAUDE.md governance applies.

## Objective
Let each board card choose its own arrival-reminder lead time — **3, 5, or 10
minutes** — instead of the single global 3-minute default shipped in #3. The
armed card fires its reminder at its own chosen lead.

## Background
North Star: **correctness of ETA/route data > simplicity > features**. #3 shipped
a per-card bell at a fixed `REMIND_LEAD_MIN = 3`. A standing kiosk user wants
more warning for some routes (long walk to the platform) and less for others.
The pure decision function `BoardLogic.evaluateReminder(state, now)` already
takes `leadMs` in `state`, so the *fire* logic needs no change — only the
per-card lead value, the control to set it, and its persistence.

## Scope
- `index.html` inline `<script>`: board item schema (`remindLeadMin`), the bell
  control + handler, the `refreshETAs` reminder hook (pass per-item `leadMs`), a
  small pure lead-cycle helper in the `BoardLogic` seam, and small CSS for the
  lead badge.
- `scripts/test-board.mjs`: add pinned tests for the lead-cycle helper +
  lead-driven fire threshold + persistence of `remindLeadMin`.
- `scripts/validate-js.js` — already runs the board test; no change expected.

## Out of scope
- Changing `evaluateReminder`'s latch/re-arm behaviour or the #3 fire channels
  (toast / vibrate / Notification). Changing #1 ordering (`compareBoardItems`)
  or #4 freshness (`evaluateFreshness`) logic or their tests.
- Arbitrary free-entry lead values — only the fixed set {3, 5, 10}.
- New frameworks/bundlers/build step, backend, API keys, service-worker push.
- Unrelated refactors or restyling.

## Functional requirements
1. **Per-card lead.** Add a persisted `remindLeadMin` (number; default 3). When
   a card is armed, its reminder fires when the nearest ETA ≤ `remindLeadMin`
   minutes (drive the existing `evaluateReminder` via a per-item `leadMs`).
2. **Single-control UX (cycle).** Tapping the bell cycles
   **Off(🔕) → 3 → 5 → 10 → Off**, arming/disarming and setting the lead in one
   control. When armed, the card visibly shows the chosen lead (e.g. a small
   badge/number on or next to 🔔) and the bilingual `title` states it. Disarming
   (cycling back to Off) clears `remindMe` and its runtime latch (as in #3).
3. **Pure cycle helper.** The Off→3→5→10→Off transition is a **pure function in
   the `BoardLogic` seam** (e.g. `nextReminderLead(currentLeadMin | null)`
   returning the next `{ remindMe, remindLeadMin }`, or the next lead value where
   null/0 = Off) so the sequence is testable and cannot drift. No `Date.now()` /
   DOM inside.
4. **Persistence.** `remindLeadMin` round-trips via `saveBoard` / `loadBoard`;
   backfill default 3 for armed legacy items lacking it; the runtime latch is
   still not persisted; `remindLeadMin` is NOT added to `SHARE_KEYS`.
5. **No regression** to #3 fire/latch behaviour, #1 ordering, #4 freshness, the
   refresh cadence, per-item ETA rendering, or the existing persistence.

## Non-functional requirements
- Correctness: the cycle helper + the lead-driven fire threshold are pinned to
  real ground truth in regression tests (vm-extracted `BoardLogic` + real
  `saveBoard`/`loadBoard`). No build step; single-file architecture preserved;
  O(n) per refresh.
- i18n: Chinese-first bilingual tone matching existing copy.
- No layout break on the 12" board or mobile (notch safe-area intact).

## Acceptance criteria
- Validation gate green (below) with the **new tests run, not skipped**; the
  existing #1 ordering + #3 reminder + #4 freshness tests still pass unchanged.
- Tests assert at minimum: the cycle sequence **Off→3→5→10→Off exactly**; a bus
  N minutes out fires at lead ≥ N but **not** at a smaller lead (e.g. a
  5-min-out bus fires at lead 5 and 10, but not at 3); `remindLeadMin` persists
  round-trip; default backfill = 3 for an armed legacy item lacking the field.
- Manual/preview: the bell shows the current lead; tapping cycles
  arm/disarm + changes the lead; the latch is cleared on Off.

## Required validation
node scripts/validate-js.js
<!-- Plus the new pinned tests, wired so they run and fail non-zero on
     regression. UI changed → manual/preview check of the bell/lead control in
     the browser. Do NOT weaken the definition of "passing". -->

## Risk classification
LOW–MEDIUM — small, additive change to #3 in the single production file; the
fire logic is already parameterised, so most of the surface is UI + persistence.
Proceeds automatically; final merge stays human-controlled.

## Human approval requirements
None to proceed. Human owns the final merge (auto-merge off).

## Open questions
- Confirm the {3, 5, 10} set and the Off→3→5→10→Off cycle order if a different
  set is wanted; otherwise proceed with {3, 5, 10}.
