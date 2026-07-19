# Task

Current work contract for the dual-agent workflow. Claude (orchestrator) owns
this file; Codex executes against it. SPEC.md would be the technical source of
truth but none exists yet — CLAUDE.md governance applies.

## Objective
Add an **arrival reminder** to the Departure Board (Screen 3). The user can arm
a per-card reminder (a bell toggle); while the app is open, when that card's
nearest upcoming ETA drops to within a lead time (default **3 minutes**), the
app fires a **foreground alert once per approaching bus**: a browser
Notification when permission is granted, plus an always-on in-app fallback
(toast + vibration where supported). Backlog item #3.

## Background
Market apps (App1933, Citybus, hkbus.app) push arrival alerts. This app is a
fixed standing board / installable PWA with no backend, so the realistic,
in-architecture version is a **foreground, while-open reminder** driven by the
ETA data the board already fetches every 15s. The board item already carries
`nearestEta` (ms epoch) and `etaRows`; the reminder is a thin, testable layer on
top of that plus a notification side-effect.

### Scope interpretation — read this
The backlog title "落車/到站提示" is scoped this round to **arrival-at-the-watched-stop**
reminder (bus is ~N min from the stop the user is watching). True on-bus "time to
alight" tracking would need live GPS position along the route while riding — that
is a heavier, separate feature and is **out of scope** here. State this clearly.

## Scope
- `index.html` — inline `<script>` (board data model, `BoardLogic` seam,
  `refreshETAs`/render loop, per-card controls) and its inline styles.
- `scripts/test-board.mjs` — add pinned regression tests for the reminder logic.
- `scripts/validate-js.js` — already runs the board test; no change expected.
- MAY touch `manifest.json` only if strictly needed (it is not expected to be).

## Out of scope
- **Background / push notifications** (Web Push, VAPID, service-worker `push`
  events, waking a closed app). No backend exists; do NOT add one. Reminder is
  **foreground / while-open only** — say so in the UI/report.
- True on-bus GPS "alight now" tracking; GMB / green-minibus; new frameworks,
  bundlers, build step, backend, or any API key/secret.
- Changing the #1 soonest-first ordering behaviour or its existing tests.
- Unrelated refactors or restyling beyond what this feature requires.

## Functional requirements
1. **Per-card arm control.** Each board card gets a reminder toggle (a bell,
   matching the existing star/remove control pattern and bilingual title). Off
   by default. State persists in `localStorage` across reloads (via the existing
   `saveBoard`/`loadBoard` path). Default lead time **3 minutes**.
2. **Fire condition.** For an armed card, when the nearest upcoming ETA is
   `<= lead` minutes away (including "arriving now"), fire the alert. Do NOT
   fire when the card is not armed, or when there is no ETA / data is
   unavailable.
3. **Fire once per bus (latch).** Must NOT re-fire every 15s refresh for the
   same approaching bus. After firing for an arrival, stay silent until that bus
   passes and a **distinctly later** arrival becomes the nearest one (then
   re-arm and it may fire again). Use a small tolerance so tiny ETA drift
   between refreshes is treated as the *same* bus, not a new one.
4. **Alert channels.** On fire: always show an in-app toast identifying the
   route + stop (bilingual) and vibrate where `navigator.vibrate` exists; and,
   if `Notification.permission === 'granted'`, also post a browser
   `Notification`. Arming a reminder for the first time should request
   Notification permission once (graceful if denied/unsupported — the toast
   fallback still works).
5. **No regression** to add-to-board, star, remove, share, ordering, refresh, or
   persistence. Runtime-only reminder latch state must NOT leak into the saved
   board JSON (mirror how `nearestEta`/`etaRows` are stripped in `saveBoard`).

## Non-functional requirements
- Correctness: the fire/latch decision lives in a **pure function in the
  `BoardLogic` seam** and is pinned to ground truth by regression tests (a
  passing render is a smoke test, not correctness).
- i18n: Chinese-first bilingual tone (`中文 · English`) matching existing copy.
- No build step; single-file architecture preserved.
- No layout break on the 12" standing screen or on mobile (notch safe-area from
  v1.7 intact). No performance regression (reminder check is O(n) per refresh).

## Acceptance criteria
- Validation gate green (below) with the reminder tests **run, not skipped**;
  existing ordering tests still pass unchanged.
- `BoardLogic` exports a pure reminder-evaluation function; regression tests
  assert, at minimum:
  1. Fires when an armed card's nearest ETA first crosses to `<= lead`.
  2. Does NOT fire again on the next tick for the same bus (latch holds).
  3. Re-arms and fires for a distinctly later next bus after the first passes.
  4. Does NOT fire when the card is unarmed.
  5. Does NOT fire when nearestEta is null/unavailable.
  6. Boundary: exactly at the lead threshold fires; clearly above it does not.
- Reminder arm state round-trips through `localStorage`; latch state does not
  persist. Board still renders/refreshes; star/remove/share/ordering intact.

## Required validation
node scripts/validate-js.js
<!-- Plus the new pinned reminder test(s), wired so they run and fail non-zero
     on regression. If UI changed: manual/preview check in browser. Do NOT
     weaken the definition of "passing". -->

## Risk classification
MEDIUM — touches the single production file (persistence schema + render loop +
new permission side-effect). Proceeds automatically; final merge stays
human-controlled.

## Human approval requirements
None to proceed. Human owns the final merge (auto-merge off). ESCALATE before
acting if delivering the reminder would require a backend, Web Push
infrastructure, or any authenticated/non-public source.

## Open questions
- None blocking. If the "fire once per bus" re-arm tolerance needs a specific
  value, pick a sensible default (document it) rather than escalating.
