# Task

Current work contract for the dual-agent workflow. Claude (orchestrator) owns
this file; Codex executes against it. SPEC.md would be the technical source of
truth but none exists yet — CLAUDE.md governance applies.

## Objective
Make the stale-data age text count **down per second** during an outage instead
of ticking in 15-second steps. Today the "⚠ 資料可能過時 · … · 更新於 X 秒前 ·
Updated Xs ago" line is only re-rendered on the 15s refresh cycle, so the age
jumps 0 → 15 → 30 … s. Drive a lightweight 1-second tick that re-renders the
freshness line **only while stale**, without changing the 15s fetch cadence.

## Background
North Star: correctness > simplicity > features. This is the #4 MINOR follow-up
— a small honesty/polish fix on the stale indicator shipped in #4. The fetch
loop must stay at 15s (no extra network); only the *displayed age* updates each
second while the board is stale, and the ticking stops the moment data recovers
or the board empties (no idle timers).

## Scope
- `index.html` inline `<script>`: a module-level 1s "stale tick" timer and the
  logic in/around `renderFreshnessStatus` (~L2357) + `refreshETAs`
  (~L2516-2545) that starts the tick when stale and clears it when
  fresh/empty. `formatFreshnessAge` (~L2348) copy stays as-is.
- `scripts/test-board.mjs`: pin `formatFreshnessAge` boundaries via vm
  extraction (locks the per-second seconds display + the minute rollover copy).

## Out of scope
- The 15s fetch cadence, `refreshETAs` fetch logic, `fetchETA`, `apiFetch`,
  providers, `evaluateFreshness`/`STALE_AFTER_MS`, reminders, ordering,
  persistence, `SHARE_KEYS`. The bilingual copy strings in `formatFreshnessAge`
  and the stale banner (don't reword them).
- New frameworks/bundlers/build/backend/keys/SW push. Unrelated refactors.
- Visibility/battery pausing (that is a separate queued item, D — do NOT
  implement it here).

## Functional requirements
1. **Per-second age while stale.** While the board is stale (per
   `evaluateFreshness`) and has items, the age line re-renders every ~1s so
   "更新於 X 秒前 · Updated Xs ago" counts up per second (recomputing age from
   `lastSuccessMs` vs the current time).
2. **Only while stale; self-stopping.** The 1s timer must NOT run when the data
   is fresh, when there are no board items, or before the first stale state. It
   must be cleared the moment a refresh succeeds (age resets, banner clears) or
   the board empties — no idle 1s timer in the healthy path.
3. **No change to fetch cadence.** The 15s network refresh is untouched; this is
   display-only. No extra API calls.
4. **Guarded + idempotent.** Guard all DOM/`document` access (the pure logic
   lives elsewhere). Starting the tick when already running must not stack
   multiple intervals (clear-before-set). Healthy-path "更新 HH:MM:SS" render is
   unchanged.
5. **No regression** to #4 freshness semantics, reminders, ordering, cadence, or
   persistence.

## Non-functional requirements
- Correctness: `formatFreshnessAge` boundaries pinned by a regression test
  (vm-extracted, DOM-free). The timer itself is a DOM/interval concern —
  smoke-verify in preview. i18n copy unchanged. No build step. O(1) per tick.
- No layout break on the 12" board / mobile.

## Acceptance criteria
- Validation gate green (below) with the new `formatFreshnessAge` test **run,
  not skipped**; all existing ordering/reminder/lead/freshness tests pass
  unchanged.
- Test asserts at least: 0s and 59s → "X 秒前 · Xs ago"; 60s and 119s →
  "1 分鐘前 · 1m ago"; 120s → "2 分鐘前 · 2m ago"; negative/again-zero clamps to
  0s.
- Preview: with a simulated stale state, the seconds visibly increment ~1/s;
  on a successful refresh the banner returns to "更新 HH:MM:SS" and the 1s timer
  stops (no console errors, no stacked timers).

## Required validation
node scripts/validate-js.js
<!-- Plus the new pinned test; browser/preview check of the per-second tick and
     its stop-on-recovery. Do NOT weaken the definition of "passing". -->

## Risk classification
LOW — display-only polish in the single production file; no network/logic
change. Proceeds automatically; human owns the final merge.

## Human approval requirements
None to proceed. Human owns the final merge (auto-merge off).

## Open questions
- None blocking. Tick interval ~1000ms; recompute age from `lastSuccessMs` each
  tick. If you find a cleaner seam (e.g. the tick calling the existing
  `renderFreshnessStatus(Date.now(), board.length > 0)`), use it and note it.
