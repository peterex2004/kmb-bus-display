# Task

Current work contract for the dual-agent workflow. Claude (orchestrator) owns
this file; Codex executes against it. SPEC.md would be the technical source of
truth but none exists yet — CLAUDE.md governance applies.

## Objective
Add a per-board **Auto / Manual** sort mode (item E, design **E1**). **Auto is
the default** and keeps today's soonest-first ordering (#1 correctness intact).
In **Manual** mode the board sorts purely by a user-controlled `boardOrder`
(drag-to-reorder in edit mode), ignoring ETA for ordering. The mode + order
persist across reload.

## Background
North Star: correctness of ETA/route data > simplicity (no build/framework) >
features. `compareBoardItems` is ETA-primary; `boardOrder` is only an equal-ETA
tiebreak — so soonest-first and a fixed manual order are mutually exclusive. A
**mode toggle** is the only way to give manual control without silently
defeating #1. Auto stays the default so correctness is the out-of-the-box
behaviour. This does NOT change the auto comparator's math.

## Scope
- `index.html` inline `<script>`:
  - `BoardLogic` seam: a pure `compareBoardManual(a, b)` (boardOrder-primary) and
    a pure `reorderBoardOrder(items, fromIndex, toIndex)` helper; both exported
    and pinned by tests. `compareBoardItems` (auto) is UNCHANGED and still used.
  - A board-wide `sortMode ∈ {'auto','manual'}`, default `'auto'`, persisted
    under a NEW top-level localStorage key `kmb_sort_mode` (NOT inside the
    per-item board array, NOT in `SHARE_KEYS`).
  - Every `board.sort(BoardLogic.compareBoardItems)` call site is mode-gated:
    `board.sort(sortMode === 'manual' ? BoardLogic.compareBoardManual :
    BoardLogic.compareBoardItems)`.
  - A sort-mode toggle button in the board edit bar; drag-to-reorder rows in
    manual + edit mode.
  - Minimal CSS for the toggle, drag handle, and dragging state.
- `scripts/test-board.mjs`: pin `compareBoardManual` + `reorderBoardOrder`.

## Out of scope
- `compareBoardItems` / #1 ordering math (auto path stays byte-for-byte today's
  behaviour), `evaluateReminder` / #3, `evaluateFreshness`/`STALE_AFTER_MS`/#4,
  `formatFreshnessAge`, #7 stale tick, #8 visibility (`shouldRunBackground`),
  F's `resolveEtaDisplay`, the 15s cadence, `refreshETAs` fetch logic,
  `fetchETA`, `apiFetch`, providers.
- `SHARE_KEYS` / sharing payload. New frameworks/bundlers/build/backend/keys/SW.
  Unrelated refactors. Rewording existing copy.

## Functional requirements
1. **Mode state + persistence.** `sortMode` defaults to `'auto'`; persisted under
   `kmb_sort_mode`; any missing/invalid stored value loads as `'auto'`.
2. **Auto mode = today's behaviour.** `compareBoardItems` unchanged; the only
   change in auto is that the sort call is mode-gated (auto branch === current
   call). Soonest-first, F stale cards sink (nearestEta null), reminders/#4/#7/#8
   all unchanged.
3. **Manual comparator (pure).** `compareBoardManual(a, b)` orders by `boardOrder`
   (finiteNumber; missing sinks deterministically) then the SAME final
   deterministic key as `compareBoardItems`. Ignores `nearestEta`.
4. **Reorder helper (pure).** `reorderBoardOrder(items, fromIndex, toIndex)`
   returns a NEW array reflecting moving one item, with compact integer
   `boardOrder` 0..n-1 reassigned by resulting position. Out-of-range / no-op
   inputs are safe (return an equivalent array, no throw).
5. **Toggle UI.** A button in the board edit bar, bilingual label reflecting
   state ("自動排序 · Auto" / "手動排序 · Manual"); click flips mode, persists,
   re-sorts, re-renders.
6. **Drag-to-reorder (manual + edit mode only).** Rows draggable with a drag
   handle; on drop compute new order via `reorderBoardOrder`, assign `boardOrder`,
   `saveBoard()`, `renderBoard()`. Drag is NOT enabled in auto mode (it would be
   immediately overwritten by the ETA sort) nor outside edit mode.
7. **New cards append in manual.** New cards keep getting `nextBoardOrder()`
   (already the case), so in manual mode they land at the bottom.
8. **No regression** to #1/#3/#4/#5/#6/#7/#8, ETAs still render/refresh normally
   in manual mode (a stale card stays in its manual slot — expected).

## Non-functional requirements
- Correctness: `compareBoardManual` + `reorderBoardOrder` are DOM-free pure
  functions pinned by regression tests. Drag wiring + toggle are DOM concerns —
  smoke-verify in preview. No build step. i18n tone preserved (Chinese-first).
- No layout break on the 12" board / mobile.

## Acceptance criteria
- Validation gate green (below) with new `compareBoardManual` +
  `reorderBoardOrder` tests **run, not skipped**; all existing tests pass
  unchanged (including F's resolver truth table and auto `compareBoardItems`).
- Tests assert: (a) `compareBoardManual` orders by `boardOrder` regardless of
  `nearestEta` (a later-ETA item with smaller boardOrder sorts first); missing
  boardOrder handled deterministically. (b) `reorderBoardOrder(items, from, to)`
  moving an item yields the expected sequence with compact 0..n-1 `boardOrder`;
  out-of-range/no-op safe.
- Preview: Auto (default) → soonest-first, no drag handles. Toggle to Manual →
  order freezes; edit mode → drag a card → stays dropped, persists across a
  refresh cycle and a reload. Toggle back to Auto → ETA sort resumes. No console
  errors; reminders/#4/#7/#8 behave.

## Required validation
node scripts/validate-js.js
<!-- Plus the new pinned compareBoardManual + reorderBoardOrder tests; browser
     preview of toggle + drag + persistence. Do NOT weaken "passing". -->

## Risk classification
MEDIUM — new drag interaction + mode + persistence in the single file. Pure
comparator/reorder pinned by tests; auto path unchanged. Proceeds
automatically; human owns the final merge. ESCALATE if drag cannot be done
cleanly without a framework or without touching the auto comparator.

## Human approval requirements
None to proceed. Human owns the final merge (auto-merge off).

## Open questions
- None blocking. Non-negotiable: the AUTO path stays byte-for-byte today's
  behaviour and manual reorder never mutates ETA data (only `boardOrder`).
