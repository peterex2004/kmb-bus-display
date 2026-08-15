# Task

Current work contract for the dual-agent workflow. Claude (orchestrator) owns
this file; Codex executes against it. SPEC.md would be the technical source of
truth but none exists yet — CLAUDE.md governance applies.

## Objective
**iOS port, Phase 0 — shared golden vectors.** Extract the language-neutral
behavioural assertions currently hard-coded in `scripts/test-board.mjs` into a
versioned JSON fixture at `shared/fixtures/board-logic.vectors.json`, and
refactor `test-board.mjs` to drive those assertions **from the fixture**. The
same fixture will later be consumed by the Swift `BoardCore` unit tests, making
web↔iOS behavioural parity machine-checked rather than assumed.

## Background
The planned iOS app (native SwiftUI) will re-implement the `BoardLogic` seam in
Swift. `BoardLogic` is already pure and DOM-free — it is the domain model. The
single biggest correctness risk in a port is silent behavioural drift between
the two implementations. A shared, language-neutral vector file removes that
risk: both implementations must satisfy byte-identical expectations.

This phase is **test-infrastructure only**. It introduces no build step, no
framework, and no iOS code, so it needs no governance change and is safe to land
in the web repo on its own merits (it also makes the existing suite
data-driven and easier to extend).

## Scope
- **NEW** `shared/fixtures/board-logic.vectors.json` — the versioned vector file.
- `scripts/test-board.mjs` — load the fixture and drive the portable assertions
  from it; keep the JS-only tests inline (see "Stays inline" below).
- Optionally a small loader helper inside `test-board.mjs` (no new dependency,
  no new npm package, no build step).

## Out of scope — HARD constraints
- **`index.html` MUST NOT change.** Phase 0 touches zero production code. A diff
  that modifies `index.html` is an automatic fail.
- No new runtime dependency, package manager, bundler, or build step.
- No change to `scripts/validate-js.js` behaviour (it must still run
  `test-board.mjs` and fail the gate on any assertion failure).
- No change to any assertion's *meaning*, threshold, or expected value. This is
  a **pure re-expression** of existing expectations, not a re-baselining.

## Vector file format
Language-neutral JSON — no JS-only constructs (no `undefined`, no `NaN`
literals, no functions). Use `null` for absent values and an explicit sentinel
(e.g. `{"missing": true}` or omission of the key) where a case must distinguish
"absent" from "null"; document the convention in the file itself.

Required top-level shape:

```json
{
  "schemaVersion": 1,
  "description": "...",
  "constants": { "STALE_AFTER_MS": 60000, "REARM_TOLERANCE_MS": 90000,
                 "REMINDER_LEADS": [3, 5, 10] },
  "epoch": { "NOW": 1767268800000, "FRESHNESS_NOW": 1767268800000 },
  "groups": {
    "compareBoardItems": { "cases": [ { "name": "...", "input": {...},
                                       "expected": {...} } ] },
    "...": {}
  }
}
```

Resolve every chained/derived value to a **literal number** computed from the
declared epoch, so a consumer needs no JS evaluation to use the file. Each case
carries a `name` — reuse the existing assertion message verbatim so failures
stay traceable to today's wording.

## Groups that MUST be covered (all currently asserted behaviour)
1. `compareBoardItems` — the 6-item ordering sample; starred-not-pinned-ahead.
2. `compareBoardManual` — ETA-ignoring order; missing `boardOrder` sinks (both
   argument orders); same-`boardOrder` deterministic-key fallthrough.
3. `reorderBoardOrder` — move+compact; input-not-mutated; shallow-cloned items;
   out-of-range; equal-index; non-array input.
4. `resolveEtaDisplay` — the 4-case truth table (incl. **stale ⇒ nearestEta
   null**).
5. `shouldRunBackground` — the 4-case truth table.
6. `evaluateFreshness` — below/at/above threshold, no-successful-refresh,
   older-has-larger-age.
7. `formatFreshnessAge` — 0s, 59s, 60s rollover, 119s floor, 120s, negative
   clamp (exact bilingual strings preserved byte-for-byte).
8. `nextReminderLead` — the full Off→3→5→10→Off cycle.
9. `evaluateReminder` — every currently-asserted scenario: not-yet, first fire,
   same-bus drift, distinct-later-bus before/at lead, unarmed, missing-ETA latch
   hold, the transient-null gap chain (fires exactly once), re-arm after gap,
   at/above lead boundary, arriving-now, and the lead-matrix
   (`reminderAtLead`) cases.
10. `constants` — `STALE_AFTER_MS`, `REARM_TOLERANCE_MS`, `REMINDER_LEADS`.

## Stays inline in test-board.mjs (JS-only, NOT vectorised)
- The `vm` extraction machinery and marker assertions.
- The `loadBoard`/`saveBoard` **localStorage persistence** tests — these bind to
  a web-only storage mechanism; iOS will use a different persistence layer.
  Keep them exactly as they are today.

## Functional requirements
1. Every assertion that exists today still runs and still passes.
2. The portable assertions are **driven by the fixture** — editing an expected
   value in the JSON must change what the test asserts (no duplicated
   hard-coded expectations left behind shadowing the fixture).
3. **No silent coverage loss.** The runner must fail if a declared group has
   zero cases, and must assert a per-group expected case count so that
   accidentally dropping cases breaks the gate.
4. The runner prints a clear per-group PASS line and a total case count.
5. The existing `PASS:` lines consumed by humans/CI stay recognisable (keep the
   same wording where a group maps 1:1 to a current line).

## Non-functional requirements
- Pure Node, no dependencies. Fixture read via `node:fs/promises` + `JSON.parse`.
- The fixture must be readable by a non-JS consumer (Swift `Codable`) without
  preprocessing — that is the whole point.
- Keep the bilingual expected strings exactly as today (UTF-8, no escaping
  changes that alter the decoded value).

## Acceptance criteria
- `node scripts/validate-js.js` green, exit 0, **no skips**.
- `git diff --stat origin/main` shows **`index.html` untouched**; only
  `docs/task.md`, `shared/fixtures/board-logic.vectors.json`, and
  `scripts/test-board.mjs` change.
- Deliberately corrupting one expected value in the fixture makes the gate
  **fail** (prove the tests really read the file) — demonstrate this in the
  report, then restore the file.
- Total asserted case count is reported and is ≥ the number of portable
  assertions present today.

## Required validation
node scripts/validate-js.js
<!-- Plus the fixture-drives-the-test proof described above. Do NOT weaken
     "passing", and do NOT change any expected value. -->

## Risk classification
LOW — test-infrastructure only; production code untouched. The one real risk is
silent coverage loss during extraction, which requirement 3 (per-group expected
counts) and the corruption proof are designed to catch. Proceeds automatically;
human owns the final merge.

## Human approval requirements
None to proceed. Human owns the final merge (auto-merge off). Note: the broader
iOS port (Xcode project, Swift target) is **not** authorised by this contract —
CLAUDE.md §2's no-build-tools rule is still pending a human decision. Phase 0
deliberately stays inside the existing web repo's rules.

## Open questions
- None blocking. If a case genuinely cannot be expressed language-neutrally,
  leave it inline, list it explicitly in the report with the reason, and cover
  everything else.
