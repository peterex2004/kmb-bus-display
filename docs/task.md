# Task

Current work contract for the dual-agent workflow. Claude (orchestrator) owns
this file; Codex executes against it. SPEC.md would be the technical source of
truth but none exists yet — CLAUDE.md governance applies.

## Objective
**iOS port, Phase 1 — `BoardCore`.** Create a pure, dependency-free Swift
package at `ios/BoardCore/` that re-implements the web `BoardLogic` seam, and
prove it satisfies **all 88 cases** in `shared/fixtures/board-logic.vectors.json`
— the same file the JavaScript gate asserts against. No UI, no networking, no
app target.

## Background
`CLAUDE.md` §1–§2 now define two delivery targets (amended 2026-08-15). The iOS
target is native SwiftUI, Apple frameworks only, **no third-party dependencies**.
`docs/ios-architecture.md` holds the design; this contract executes its Phase 1.

The golden vectors are the *shared specification*. If `BoardCore` and
`BoardLogic` disagree, the web and iOS apps have silently drifted — which is the
exact failure this phase exists to make impossible.

## Scope
- **NEW** `ios/BoardCore/` — a SwiftPM library package:
  - `Package.swift` (library + test target, **zero dependencies**)
  - `Sources/BoardCore/` — the domain functions
  - `Tests/BoardCoreTests/` — a vector-driven runner
- **NEW/EDIT** `.gitignore` — ignore Swift build artefacts (`.build/`,
  `*.xcuserdatad`, `DerivedData/`).
- Optionally a short `ios/README.md` describing how to run the tests.

## Out of scope — HARD constraints
- **`index.html` MUST NOT change.** Neither may `scripts/validate-js.js` or
  `scripts/test-board.mjs` behaviour.
- **`shared/fixtures/board-logic.vectors.json` MUST NOT change.** Not one
  expected value, not one case. If Swift disagrees with a vector, **the Swift
  code is wrong** — fix the Swift. Editing a vector to make a test pass is
  changing the definition of correctness → STOP and ESCALATE (§5).
- **Do NOT copy or duplicate the fixture** into the package. The test must read
  the one file at `shared/fixtures/`. A copy guarantees future drift and defeats
  the entire phase.
- No Xcode `.xcodeproj`, no app target, no SwiftUI, no networking, no
  persistence — those are Phases 2–4.
- No third-party dependency of any kind.

## API to implement (mirroring `BoardLogic`)
All pure. **No `Date()` / `Date.now` anywhere inside `BoardCore`** — time is
injected, exactly as on the web.

| Web | Swift |
|---|---|
| `compareBoardItems` | `BoardComparator.auto(_:_:) -> ComparisonResult` |
| `compareBoardManual` | `BoardComparator.manual(_:_:) -> ComparisonResult` |
| `reorderBoardOrder` | `reorder(_:from:to:) -> [BoardItem]` |
| `evaluateReminder` | `ReminderEngine.evaluate(_:now:)` |
| `nextReminderLead` | `ReminderEngine.nextLead(_:)` |
| `evaluateFreshness` | `FreshnessEvaluator.evaluate(_:now:staleAfterMs:)` |
| `resolveEtaDisplay` | `EtaResolver.resolve(previous:outcome:)` |
| `shouldRunBackground` | `RefreshPolicy.shouldRun(hidden:boardActive:)` |
| `formatFreshnessAge` | `FreshnessFormatter.age(_:) -> String` |

Constants must match the fixture's `constants` group exactly:
`staleAfterMs` 60000, `rearmToleranceMs` 90000, `reminderLeads` [3, 5, 10].

## Known portability traps — handle explicitly
These are the places a naive port silently diverges. Each MUST be addressed and
called out in the report:

1. **Natural/numeric string ordering.** The web tiebreak is
   `keyA.localeCompare(keyB, undefined, { numeric: true })` — numeric-aware, so
   `"2" < "10"`. Swift's default `<` on `String` is **not**. Use
   `compare(_:options: .numeric)` (or an equivalent that reproduces the numeric
   collation) and add a test proving `route "2"` sorts before `route "10"`.
2. **Sort stability.** JS `Array.sort` is specified stable; Swift's `sort()` is
   **not guaranteed stable**. The comparators end in a deterministic key, so the
   ordering should be a *total* order and stability should not matter — verify
   that, and add a test that sorting is deterministic regardless of input
   permutation (e.g. sort several shuffles of the same input, assert identical
   output).
3. **Integer semantics.** Epoch-ms values (~1.767e12) exceed Int32 — use 64-bit
   `Int`. Note JS `Math.floor` on negatives differs from Swift integer division
   truncation; `formatFreshnessAge` clamps at 0 first so the observable result
   matches, but confirm the negative-input vector passes rather than assuming.

## Fixture consumption rules
- Resolve the fixture path relative to the **source file** (e.g. via
  `#filePath` walked up to repo root), NOT the CWD, so `swift test` works from
  any directory. Do not embed it as a package resource copy.
- Honour `absentKeys`: a listed dot-path is *absent* from the input at that
  path. Both absent and JSON `null` map to Swift `nil` for these fields (the
  distinction is not semantically meaningful to `BoardLogic`); the runner must
  still parse `absentKeys` and construct the case accordingly rather than
  ignoring the field.
- Honour the property flags: `assertInputUnchanged` (input array/items not
  mutated), `assertClonedItems` (returned items are distinct values), and
  `assertRowsIdentity` (the returned rows are the same rows as the named input
  path — in Swift, value equality is the portable reading).
- Preserve the bilingual `formatFreshnessAge` strings byte-for-byte, e.g.
  `更新於 1 分鐘前 · Updated 1m ago`.

## Functional requirements
1. Every one of the 88 vector cases is executed and passes.
2. The runner is **driven by the fixture** — no expected values hard-coded in
   Swift. Corrupting a vector must fail the Swift tests.
3. **No silent coverage loss.** Assert a per-group case count and a total of 88,
   and fail if a declared group is empty or a group is missing — mirroring the
   JS runner's guard.
4. A failing case reports the vector's `name` so failures are traceable to the
   same wording as the web suite.
5. The JS gate still passes untouched.

## Non-functional requirements
- Zero dependencies. Swift 6 / iOS 17+ language level is fine; the package
  itself must build for macOS too so `swift test` runs on the CLI.
- `BoardCore` is UI-free, IO-free (the *tests* do the file read, not the
  library), and deterministic.
- Public API documented briefly; naming idiomatic Swift, but behaviour identical
  to the web.

## Acceptance criteria
- `swift test` from `ios/BoardCore` — **all tests pass**, 88 cases asserted,
  count guards active.
- `node scripts/validate-js.js` still green (web target unaffected).
- `git diff --name-only origin/main` shows **no** `index.html`, **no**
  `shared/fixtures/**`, **no** `scripts/**` changes.
- Corrupting one vector value makes `swift test` **fail** (proof the fixture
  drives the Swift tests too); restore afterwards.
- Build artefacts (`.build/`) are gitignored, not committed.

## Required validation
cd ios/BoardCore && swift test
node scripts/validate-js.js
<!-- Both must pass. Do NOT weaken either. Do NOT edit the fixture. -->

## Risk classification
MEDIUM — new language and toolchain, but a narrow, pure, fully-specified
surface with an 88-case executable spec. The real risks are the three
portability traps above and accidentally "fixing" a vector instead of the code.
Proceeds automatically; human owns the final merge.

## Human approval requirements
None to proceed — the iOS target is authorised by CLAUDE.md §2 (amended
2026-08-15). Human owns the final merge. Adding any third-party dependency
would require explicit approval and is out of scope here.

## Open questions
- None blocking. Two decisions remain open for later phases (reminder strategy
  when the app is closed; v1 scope) — neither affects `BoardCore`, which is
  pure domain logic.
