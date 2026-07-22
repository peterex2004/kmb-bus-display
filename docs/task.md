# Task

Current work contract for the dual-agent workflow. Claude (orchestrator) owns
this file; Codex executes against it. SPEC.md would be the technical source of
truth but none exists yet — CLAUDE.md governance applies.

## Objective
When an ETA fetch fails (transient network blip / outage), keep showing that
card's **last-known ETAs, greyed out and marked "最後已知 · Last known"**,
instead of collapsing to "—". Today `fetchETA`'s catch sets `item.etaRows =
null` → the card flashes "—" on any single failed request. Retain the prior
good rows for display while the fetch is failing, without ever letting stale
data drive ordering or reminders.

## Background
North Star: correctness > simplicity > features. This is item **F**
(offline last-known cache), complementing #4's global stale banner with a
per-card fallback. **Correctness guardrail:** last-known ETAs are for *display
only* — while a card is showing stale data its `nearestEta` must be `null`, so
#1 ordering sinks it and #3 reminders do NOT fire on stale timestamps. #4's
freshness (cycle success → `lastSuccessMs`) is unchanged.

## Scope
- `index.html` inline `<script>`:
  - `BoardLogic` seam: a pure `resolveEtaDisplay(previous, outcome)` that decides
    the display state from the item's prior ETA state + the new fetch outcome.
  - `fetchETA` (~L2575): compute the parsed rows / failure as today, then route
    through `resolveEtaDisplay` to assign `item.etaRows` / `item.nearestEta` /
    `item.etaStale`.
  - `renderBoardEta` (~L2334): when a card is stale-with-retained-rows, render
    the rows **dimmed** with a "最後已知 · Last known" marker; do not show the
    live "即將抵達 / soon" styling on stale rows.
  - Minimal CSS for the dimmed/last-known state.
- `scripts/test-board.mjs`: pin the `resolveEtaDisplay` truth table.

## Out of scope
- **Persistence of last-known across reload** (localStorage schema change) — this
  item is **in-session retention only**; note reload-persistence as a possible
  follow-on (F2). Do NOT touch `saveBoard`/`loadBoard`/`SHARE_KEYS`.
- `compareBoardItems` / #1 ordering math, `evaluateReminder` / #3 reminders,
  `evaluateFreshness`/`STALE_AFTER_MS`/#4 banner, `formatFreshnessAge`, the #7
  stale tick, #8 visibility logic, the 15s cadence, `apiFetch`, providers.
- New frameworks/bundlers/build/backend/keys/SW push. Unrelated refactors. The
  bilingual copy of existing strings (add the one new "最後已知 · Last known"
  marker; don't reword existing ones).

## Functional requirements
1. **Retain on failure.** When `fetchETA` fails AND the item has a prior
   non-empty `etaRows` array, keep those rows for display and set
   `item.etaStale = true`. If there is no prior good data, keep today's behaviour
   (`etaRows = null` → "—").
2. **Never trust stale for logic.** Whenever a card is showing stale/last-known
   data (or a plain failure), `item.nearestEta` must be `null` — so #1 sinks the
   card and #3 fires no reminder on stale timestamps.
3. **Clear on success.** A successful fetch with rows sets fresh `etaRows` +
   `nearestEta = etaRows[0].etaMs` + `etaStale = false`. A success with zero
   upcoming rows → `etaRows = []`, `nearestEta = null`, `etaStale = false`
   (renders the existing "暫無班次", not stale).
4. **Distinct rendering.** Stale-with-rows renders the retained times **dimmed**
   with a "最後已知 · Last known" marker. Elapsed retained rows must NOT render
   as "即將抵達" (no false "arriving now" on old data) — render them dimmed.
5. **No cadence / freshness change.** `refreshETAs` cycle-success logic and
   `lastSuccessMs` are untouched; #4 banner + #7 tick behave exactly as before.
6. **No regression** to #1/#3/#4/#5/#7/#8, ordering, reminders, or persistence.

## Non-functional requirements
- Correctness: `resolveEtaDisplay` is a DOM-free pure function pinned by
  regression tests. Rendering is a DOM concern — smoke-verify in preview. No
  build step. O(1). i18n tone preserved (Chinese-first).
- No layout break on the 12" board / mobile; dimmed state must stay legible.

## Acceptance criteria
- Validation gate green (below) with the new `resolveEtaDisplay` test **run, not
  skipped**; all existing tests pass unchanged.
- Test asserts the four outcomes: (a) success+rows → fresh rows, nearestEta set,
  not stale; (b) success+empty → `[]`, nearestEta null, not stale; (c)
  failure+prior-rows → retained rows, **nearestEta null**, stale true; (d)
  failure+no-prior → null, nearestEta null, not stale.
- Preview: with a card populated, simulate a failed refresh → the card keeps its
  last ETAs dimmed with "最後已知 · Last known", the card sinks in order, and no
  reminder fires; a subsequent success restores live styling.

## Required validation
node scripts/validate-js.js
<!-- Plus the new pinned resolveEtaDisplay test; browser/preview check of the
     dimmed last-known render + sink-on-stale. Do NOT weaken "passing". -->

## Risk classification
LOW–MEDIUM — single production file; display fallback + one pure decision
function. The one correctness-critical rule (stale ⇒ nearestEta null) is pinned
by test. Proceeds automatically; human owns the final merge.

## Human approval requirements
None to proceed. Human owns the final merge (auto-merge off).

## Open questions
- None blocking. In-session retention only (reload-persistence deferred to F2).
  If a cleaner seam than `resolveEtaDisplay` exists, use it and pin equivalent
  cases; the non-negotiable is that stale data never sets a non-null
  `nearestEta`.
