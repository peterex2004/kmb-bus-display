# Task

Current work contract for the dual-agent workflow. Claude (orchestrator) owns
this file; Codex executes against it. SPEC.md would be the technical source of
truth but none exists yet — CLAUDE.md governance applies.

## Objective
Stop background work when the board screen is not visible, and resume cleanly
when it returns. Today the 15s ETA refresh loop (`refreshTimer`) and the 1s
stale tick (`staleTickTimer`, shipped in #7) keep running even when the tab is
hidden — wasting network + battery on a screen nobody is looking at. Add a
`visibilitychange`-driven pause/resume: on hide, stop both timers; on show
(only while the board screen is active), do an immediate refresh then resume the
15s cadence.

## Background
North Star: correctness > simplicity > features. This is item **D**
(visibility-aware refresh), a battery/network hygiene follow-on to the #4
freshness work and the #7 stale tick. The pure ETA/freshness logic is
unchanged; this is purely about *when* the existing refresh + tick run. The 15s
interval VALUE and all fetch logic stay exactly as-is — we only gate their
scheduling on document visibility + the active screen.

## Scope
- `index.html` inline `<script>`:
  - A single `visibilitychange` listener (registered once, guarded for
    `typeof document === 'undefined'`).
  - A small handler that on hide calls `stopRefresh()` + `stopStaleTick()`, and
    on show — **only if the board screen (`#disp-screen`) is active** — calls
    `startRefresh()` (which already clears-before-set, fires an immediate
    `refreshETAs()`, and restarts the 15s interval; `refreshETAs` →
    `renderFreshnessStatus` re-arms the stale tick iff still stale).
  - `BoardLogic` seam: a tiny PURE predicate
    `shouldRunBackground(hidden, boardActive)` → `!hidden && boardActive` (no
    DOM, no Date.now), used by the handler and pinned by test.
- `scripts/test-board.mjs`: pin the `shouldRunBackground` truth table.

## Out of scope
- The 15s interval VALUE, `refreshETAs`/`fetchETA`/`apiFetch` fetch logic,
  providers, `evaluateFreshness`/`STALE_AFTER_MS`, `formatFreshnessAge`,
  `staleTickTimer` semantics (from #7), reminders, ordering, persistence,
  `SHARE_KEYS`. The bilingual copy strings.
- Battery API / Page Lifecycle `freeze`/`resume`/`prerender` — **visibility
  only**. No frameworks/bundlers/build/backend/keys/SW push. Unrelated
  refactors.

## Functional requirements
1. **Pause on hide.** When `document.hidden` becomes true, both the 15s
   `refreshTimer` and the 1s `staleTickTimer` are cleared. Zero `apiFetch` and
   zero ticks occur while hidden.
2. **Resume on show — board only.** When `document.hidden` becomes false AND the
   board screen (`#disp-screen`) is the active screen, do exactly ONE immediate
   refresh then resume the 15s cadence (i.e. call `startRefresh()`). If the
   active screen is the intro/selection/stop/nearby screen, do NOT start
   `refreshTimer` (those screens legitimately have no running refresh loop).
3. **Self-correcting stale tick.** After resume, the immediate `refreshETAs()`
   → `renderFreshnessStatus` decides whether to re-arm `staleTickTimer` (stale)
   or leave it stopped (fresh). Do not start the stale tick directly from the
   visibility handler.
4. **No change to fetch cadence or logic.** The 15s interval value and all fetch
   internals are untouched. No new network calls beyond the single resume
   refresh that `startRefresh()` already performs.
5. **Guarded + idempotent.** Guard all `document` access. Register the listener
   exactly once (no stacking on re-entry). Repeated hide/show must never stack
   `refreshTimer` or `staleTickTimer` (rely on the existing clear-before-set in
   `startRefresh`/`startStaleTick`).
6. **No regression** to #4 freshness, #7 stale tick, reminders, ordering,
   cadence value, or persistence.

## Non-functional requirements
- Correctness: `shouldRunBackground` pinned by a DOM-free regression test. The
  `visibilitychange` wiring itself is a DOM/interval concern — smoke-verify in
  preview. No build step. O(1) per event. i18n copy unchanged.
- No layout change (this item touches no DOM structure/CSS).

## Acceptance criteria
- Validation gate green (below) with the new `shouldRunBackground` test **run,
  not skipped**; all existing tests pass unchanged.
- Test asserts the truth table: `(hidden=false, boardActive=true) → true`;
  `(false, false) → false`; `(true, true) → false`; `(true, false) → false`.
- Preview: on the board screen, hiding the tab (`document.hidden = true` via
  visibility event) clears both timers and produces zero network calls; showing
  it again fires exactly one immediate refresh and resumes the 15s cadence, and
  the stale tick re-arms only if still stale. On a non-board screen, show/hide
  never starts `refreshTimer`. No console errors, no stacked timers.

## Required validation
node scripts/validate-js.js
<!-- Plus the new pinned shouldRunBackground test; browser/preview check of the
     pause-on-hide / resume-on-show behaviour. Do NOT weaken "passing". -->

## Risk classification
LOW–MEDIUM — display/scheduling only in the single production file; no
network/logic change, only *when* existing timers run. Proceeds automatically;
human owns the final merge.

## Human approval requirements
None to proceed. Human owns the final merge (auto-merge off).

## Open questions
- None blocking. Board-active seam = `#disp-screen.classList.contains('active')`
  (the only screen where `startRefresh()` runs, via `showBoardScreen()`).
  `startRefresh()` already fires an immediate `refreshETAs()`, so resume needs
  no extra call. If you find a cleaner active-screen signal, use it and note it.
