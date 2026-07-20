# Task

Current work contract for the dual-agent workflow. Claude (orchestrator) owns
this file; Codex executes against it. SPEC.md would be the technical source of
truth but none exists yet — CLAUDE.md governance applies.

## Objective
Make the Departure Board honest about data freshness. Today `refreshETAs`
updates the "更新 HH:MM:SS" clock **every 15s cycle even when every ETA fetch
failed** (it uses `Promise.allSettled` and always stamps the clock at the end),
and `fetchETA` silently swallows network errors to `—`. So during an API or
network outage the board looks freshly-updated while showing stale data. Add a
**fetch-health / stale-data indicator**: the "updated" time must reflect the
last *successful* refresh, and when that success is older than a threshold the
board must clearly signal that its data may be stale.

## Background
North Star: **correctness of ETA/route data > simplicity > features**. A board
that silently shows outdated arrivals as if live is a correctness failure for a
kiosk the owner glances at. This is a trust/correctness fix, not a new feature
surface. It reuses data the refresh loop already has.

## Scope
- `index.html` — inline `<script>`: `refreshETAs`, `fetchETA`, the
  `#last-update` status display, the `BoardLogic` seam, and small inline styles
  for the stale state.
- `scripts/test-board.mjs` — add pinned freshness-logic regression tests.
- `scripts/validate-js.js` — already runs the board test; no change expected.

## Out of scope
- Changing the ETA/route API providers, request cadence (stays 15s), retry/
  backoff (`apiFetch`), or the per-item ETA rendering semantics
  (`undefined`=loading, `[]`=no service "暫無班次", `null`=fetch error "—").
- #1 ordering (`compareBoardItems`) and #3 reminder (`evaluateReminder`)
  behaviour or their tests.
- New frameworks/bundlers/build step, backend, API keys, service-worker push.
- Unrelated refactors or restyling beyond this indicator.

## Functional requirements
1. **Success vs failure of a cycle.** `fetchETA` must report whether the fetch
   itself succeeded (i.e. `apiFetch` resolved) — a stop that legitimately has
   **zero upcoming buses is still a SUCCESS** (`etaRows = []`), only the `catch`
   path is a failure. `refreshETAs` must determine, per cycle, whether at least
   one item's fetch succeeded.
2. **Truthful "updated" time.** The `#last-update` timestamp must reflect the
   time of the **last successful** refresh, not merely loop completion. If a
   whole cycle fails (≥1 board item, all fetches failed), do NOT advance it.
3. **Stale signal.** When the age of the last successful refresh exceeds a
   documented threshold (pick a sensible default, e.g. ~60s ≈ several missed
   cycles), the header must clearly indicate staleness bilingually (e.g.
   `⚠ 資料可能過時 · Data may be stale` with the age), and optionally a subtle
   board de-emphasis. When a later cycle succeeds, the indicator clears and the
   board returns to normal.
4. **Empty board.** With no board items there is nothing to fetch — do NOT show
   a stale/error state.
5. **No regression** to refresh cadence, ordering, reminders, per-item ETA
   rendering, persistence, or the existing "更新" format on the healthy path.

## Non-functional requirements
- Correctness: the freshness decision (age → stale?) lives in a **pure function
  in the `BoardLogic` seam** (takes `now` and `lastSuccessMs` as args; no
  `Date.now()`/DOM inside) and is pinned by regression tests.
- i18n: Chinese-first bilingual tone matching existing copy.
- No build step; single-file architecture preserved. O(n) per refresh.
- No layout break on the 12" board or mobile (notch safe-area intact).

## Acceptance criteria
- Validation gate green (below) with the freshness tests **run, not skipped**;
  existing ordering + reminder tests still pass unchanged.
- `BoardLogic` exports a pure freshness-evaluation function; tests assert at
  minimum: fresh when age < threshold; stale when age ≥ threshold; the exact
  boundary; and the "no successful fetch yet" / null-lastSuccess case behaves
  per the documented rule (not a false "stale" on first paint).
- Manual/preview reasoning: on an all-fail cycle the "updated" time does not
  advance and the stale indicator appears; on recovery it clears.

## Required validation
node scripts/validate-js.js
<!-- Plus the new pinned freshness test(s), wired so they run and fail non-zero
     on regression. If UI changed: manual/preview check in browser. Do NOT
     weaken the definition of "passing". -->

## Risk classification
MEDIUM — touches the core refresh loop of the single production file. Proceeds
automatically; final merge stays human-controlled.

## Human approval requirements
None to proceed. Human owns the final merge (auto-merge off).

## Open questions
- None blocking. Choose and document the stale threshold and the null-lastSuccess
  behaviour rather than escalating.
