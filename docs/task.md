# Task

Current work contract for the dual-agent workflow. Claude (orchestrator) owns
this file; Codex executes against it. SPEC.md would be the technical source of
truth but none exists yet — CLAUDE.md governance applies.

## Objective
**iOS port, Phase 2 — data layer.** Add a `TransitProvider` abstraction with
KMB and Citybus implementations that decode the **real recorded API responses**
in `shared/fixtures/api/`, plus a pure `EtaParser` reproducing the web's ETA
row-selection logic. All tests replay fixtures **offline** — no network in tests.

## Background
v1 scope was decided as **board + reminders first** (2026-08-15), so the data
layer is the next dependency: the board cannot render without providers.

`shared/fixtures/api/` holds unmodified responses recorded live from both public
endpoints on 2026-08-15 (see its `PROVENANCE.md`). They are ground truth, and
they already expose four decoding traps that a naive port would hit in
production. Pinning against them satisfies CLAUDE.md DoD #1 ("regression tests
pinned to real ground truth") without depending on the network.

## Scope
- **NEW** `ios/BoardCore/Sources/BoardCore/EtaParser.swift` — pure ETA row
  selection (see below). Stays inside `BoardCore` because it is domain logic.
- **NEW** `ios/BoardCore/Sources/BoardCore/Transit/` (or a second SwiftPM target
  `TransitData` in the same package — Codex's call, justify it):
  - `TransitProvider` protocol
  - `KMBProvider`, `CTBProvider`
  - DTOs + decoding
- **NEW** tests replaying `shared/fixtures/api/**`.
- **NEW** `shared/fixtures/eta-parse.vectors.json` — language-neutral vectors
  for `EtaParser`, in the **same style** as `board-logic.vectors.json`
  (`schemaVersion`, `description`, `groups`, per-case `name`), so the web can
  later assert the identical expectations.

## Out of scope — HARD constraints
- **`index.html` MUST NOT change.** No web-side edits at all this phase.
- **`shared/fixtures/board-logic.vectors.json` MUST NOT change**, and **the
  recorded files under `shared/fixtures/api/` MUST NOT be edited** — they are
  recordings. If one seems wrong, ESCALATE; do not hand-edit JSON.
- **No network access in tests or library code paths under test.** Tests must
  pass with networking unavailable. The provider's transport is injected.
- No SwiftUI/UI, no persistence, no notifications — Phases 3–4.
- No third-party dependencies (CLAUDE.md §2, iOS target).

## `EtaParser` — port of the web's `fetchETA` row logic
Web reference (`index.html`, `fetchETA`), which must be reproduced exactly:

```
rows   = data.data filtered to (r.dir === dirCode && r.eta truthy)
parsed = rows.map(eta -> epochMs).filter(finite && >= now).sort(asc).take(3)
```

Swift signature (pure; `now` injected, **no `Date()` inside**):
`EtaParser.parse(rows:dirCode:now:) -> [EtaRow]`

Rules: drop rows whose `dir` differs; drop `eta == nil`; drop unparseable
timestamps; drop strictly-past rows (**keep `etaMs == now`**, matching the web's
`>= now`); ascending sort; **cap at 3**.

## Known decoding traps — all present in the recorded data
Documented in `shared/fixtures/api/PROVENANCE.md`. Each MUST be handled and
reported on:
1. **`service_type` changes JSON type across KMB endpoints** — String `"1"` in
   `/route/...`, Int `1` in `/eta/...`.
2. **`seq` type differs across operators** — String in KMB `/route-stop`, Int in
   CTB `/route-stop`.
3. **CTB `lat`/`long` are Strings**, not numbers.
4. **`eta` can be `null`** — a real row exists in `kmb-stop-eta.json`.
5. **ETA timestamps carry a `+08:00` offset** — parse as an internet date-time
   with offset; do not assume UTC or a fixed local zone.

Handle 1–3 with a small forgiving decode helper (e.g. a `LenientString` /
`LenientInt` wrapper accepting either JSON type), **not** by editing fixtures.

## Functional requirements
1. `TransitProvider` exposes, at minimum: route lookup, route-stop list, stop
   detail, and ETA fetch — enough for the Phase 3 board. Company-agnostic at the
   call site.
2. `KMBProvider` and `CTBProvider` decode every recorded fixture without error.
3. `EtaParser` reproduces the web logic exactly, pinned by
   `shared/fixtures/eta-parse.vectors.json` **and** by an end-to-end test that
   feeds a real recorded ETA payload through the provider + parser.
4. Transport is injected (a protocol or closure returning `Data` for a URL), so
   tests supply fixture bytes. No `URLSession` call in any test path.
5. URL construction matches the web exactly:
   - KMB ETA `…/kmb/eta/{stopId}/{route}/{serviceType}`
   - CTB ETA `…/citybus-nwfb/eta/ctb/{stopId}/{route}`
   Pin URL building with tests (no live calls).
6. The `null`-eta row and the type-mismatch fields are covered by explicit tests.
7. **No silent coverage loss:** the new vector file gets per-group count guards,
   like the existing runner.

## Non-functional requirements
- `BoardCore` stays pure and dependency-free; `Foundation` only.
- No `Date()` in library code — inject `now`.
- Deterministic: no reliance on the machine's time zone for parsing.

## Acceptance criteria
- `cd ios/BoardCore && swift test` — all pass, including the existing **88**
  board-logic vectors (unchanged) plus the new provider/parser tests.
- `node scripts/validate-js.js` still green (web untouched).
- `git diff --name-only origin/main` shows **no** `index.html`, **no**
  `shared/fixtures/board-logic.vectors.json`, and **no modifications** to
  `shared/fixtures/api/*.json` (additions elsewhere are fine).
- Tests pass with **no network** — demonstrate by running them offline or by
  showing no networking API is reachable from the test path.
- Corrupting one value in `eta-parse.vectors.json` fails `swift test`; restore.

## Required validation
cd ios/BoardCore && swift test
node scripts/validate-js.js
<!-- Both must pass. Do NOT edit recorded fixtures or the board-logic vectors. -->

## Risk classification
MEDIUM — new decoding surface against messy real-world payloads. The traps are
already identified and pinned by real recordings, which is the main mitigation.
Proceeds automatically; human owns the final merge.

## Human approval requirements
None to proceed (iOS target authorised by CLAUDE.md §2, amended 2026-08-15).
Human owns the final merge.

## Open questions
- Whether `Transit*` lives in `BoardCore` or a sibling target is Codex's call —
  justify it. Constraint: `BoardCore`'s existing purity must not regress.
- The closed-app reminder strategy is still undecided; it does not affect this
  phase.
