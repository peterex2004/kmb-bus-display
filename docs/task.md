# Task

Current work contract for the dual-agent workflow. Claude (orchestrator) owns
this file; Codex executes against it. SPEC.md would be the technical source of
truth but none exists yet — CLAUDE.md governance applies.

## Objective
Two enhancements to the **Departure Board** (Screen 3), the standing-screen
centrepiece:
1. **Global soonest-first ordering** — order all board cards by their nearest
   upcoming ETA (ascending), re-applied on every auto-refresh, so the next bus
   to arrive is always at the top at a glance.
2. **Fare display** — show the official adult fare for each route/stop on the
   board (and, if cheap to reuse, in the stop picker), sourced only from the
   existing public unauthenticated APIs / open datasets.

## Background
From a market comparison (KMB App1933, Citybus app, hkbus.app all surface
fares; none optimise for a fixed standing display). The board is this app's
unique use case, so "what's arriving next" should sort itself. Fares are static
reference data already published in the same public datasets the app uses.

## Scope
- `index.html` — inline `<script>` (board render + refresh + ETA logic) and its
  inline styles.
- MAY add a plain-Node regression test (e.g. `scripts/test-*.mjs`) and wire it
  into the validation gate.
- MAY add a fare fetch + `localStorage` cache using the existing public APIs.

## Out of scope
- GMB / green-minibus support (explicitly held off by the human this round).
- New frameworks, bundlers, or a build step; any backend; any API key/secret.
- Switching KMB (`data.etabus.gov.hk`) / CTB (`rt.data.gov.hk/.../citybus-nwfb`)
  providers, or changing the North Star (KMB + CTB only).
- Unrelated refactors or restyling beyond what these two features require.

## Functional requirements
**#1 Ordering**
- Board cards sorted by soonest upcoming ETA ascending on load and on every
  15s refresh. Cards with no ETA / unavailable data sink to the bottom.
- Ordering must be **stable** (no visible jitter when ETAs tie or are equal).
- Preserve all existing card behaviour: gold highlight for starred cards, tap
  to open stop picker, edit-mode removal, per-card star toggle. Starred cards
  keep their highlight but are still sorted by ETA (do NOT pin them to top
  unless that is already the current behaviour — Codex must verify and report).

**#2 Fare**
- For each board card, show the adult fare (bilingual label, e.g. `車費 / Fare`)
  from a public unauthenticated source, cached (do NOT refetch every 15s).
- Correctness gate: if no reliable public fare source exists for a company
  (KMB and/or CTB), **do NOT fabricate or hardcode a guessed value** — omit the
  fare gracefully for that company and say so in the report. Correctness of
  data outranks having the feature (CLAUDE.md priority order).
- For sectional-fare routes, show the fare from the boarding stop; note the
  simplification in the report.

## Non-functional requirements
- Correctness: fare values and sort ordering pinned to **real ground truth** in
  a regression test (a passing render is a smoke test, not correctness).
- i18n: preserve the zh-HK Chinese-first bilingual tone.
- No build step; single-file architecture preserved.
- No performance regression (fares cached; sort is O(n log n) on a small board).
- No layout break on the 12" standing screen or on mobile (incl. notch
  safe-area already handled in v1.7).

## Acceptance criteria
- Validation gate green (below), with pinned correctness tests that **ran**
  (not skipped).
- Regression tests assert: (a) the ETA-sort comparator orders a fixed sample
  correctly incl. no-ETA-to-bottom + stable ties; (b) fare parsing/formatting
  maps a fixed real API sample to the expected displayed fare string.
- Board still renders and refreshes; starred/edit/tap behaviours intact.

## Required validation
node scripts/validate-js.js
<!-- Plus the new pinned regression test(s) added by this task, wired so they
     run and fail non-zero on regression. If UI changed: manual/preview check in
     browser. Do NOT weaken the definition of "passing". -->

## Risk classification
MEDIUM — multi-behaviour change to the single production file + fare-data
correctness. Proceeds automatically; final merge stays human-controlled.

## Human approval requirements
None to proceed. Human owns the final merge (auto-merge off). ESCALATE before
acting if fares turn out to require any authenticated or non-public source.

## Open questions
- Exact public fare source per company (KMB / CTB) — Codex to research and
  report; descope fare for any company lacking a reliable public source rather
  than guess.
- Confirm current starred-card ordering behaviour before changing it.
