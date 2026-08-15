# CLAUDE.md — Project ground rules

Process/governance rules for this project. If a `SPEC.md` exists it stays the
technical source of truth; this file is the *how we work* contract. Read both
before making changes.

<!-- ─────────────────────────────────────────────────────────────────────
     FILL THIS IN for the specific project. The sections below are the
     reusable dual-agent governance; add a project "North Star" + any
     project-specific rules above/around them.
     ───────────────────────────────────────────────────────────────────── -->

## 1. North Star (what this project is)

九巴/城巴班次顯示 (KMB/CTB Bus Display) — a personal real-time bus arrival
board for Hong Kong (KMB + CTB), built for a 12" standing screen and mobile.
Single user (the owner), no accounts, no backend. Priority order when goals
conflict: **correctness of ETA/route data > simplicity > breadth of features**.
Live app: https://peterex2004.github.io/kmb-bus-display/. Canonical source lives
in the sibling folder `~/Claude/kmb-bus-display` (production); this cowork clone
is where Claude/Codex do isolated work before the human reviews and merges back.

**Two delivery targets** (approved 2026-08-15):

- **Web target** — the installable PWA at the live URL above. *Simplicity here
  means literally no build step and no framework* (see §2).
- **iOS target** — a native SwiftUI app for iPhone, sharing the same domain
  logic. *Simplicity here means no third-party dependencies* — Apple frameworks
  only. Xcode is its build system by necessity.

Correctness outranks simplicity on **both** targets, and the two must not drift:
shared behaviour is pinned by `shared/fixtures/board-logic.vectors.json`.

---

## 2. Architecture direction

### Rules that apply to BOTH targets

- KMB (`data.etabus.gov.hk`) and CTB (`rt.data.gov.hk/.../citybus-nwfb`) are
  both public, unauthenticated APIs — never add API keys/secrets.
- **No backend, ever.** No server-side persistence, no proxy, no push server.
  All state is on-device. This is unchanged and is not target-scoped.
- Preserve the zh-HK bilingual (Chinese-first, English labels for tech terms)
  tone already used in the UI copy.
- Domain logic that both targets share is specified by
  `shared/fixtures/board-logic.vectors.json`. Changing an expected value there
  is a change to the *definition of correctness* → human escalation (§5).

### Web target (`index.html`)

- Single `index.html` file — **no build tools, no framework**. Keep it that way;
  do not introduce bundlers/frameworks here without explicit human approval.
- Route/stop data and UI state live in-memory + `localStorage`.
- `index.html` stays at repo root so GitHub Pages keeps serving it unchanged.

### iOS target (`ios/`)

- Native **SwiftUI**, Apple frameworks only — **no third-party dependencies**,
  no package managers beyond SwiftPM for first-party/local modules. Adding an
  external dependency needs explicit human approval, exactly as a bundler does
  on the web target.
- `BoardCore` is a **pure, dependency-free Swift module** mirroring the web
  `BoardLogic` seam. It must pass the shared golden vectors. No UI, no
  networking, no `Date()` inside it — time is injected, as on the web.
- Persistence is on-device only (SwiftData or Codable files). Reminders are
  local notifications; **no APNs/push server** (that would need a backend).
- Xcode/SwiftPM is the build system for this target only. It does not license a
  build step on the web target.

---

## 3. Definition of Done (every change)

A change is **not done** until all of these hold:

1. **Correctness is asserted, not eyeballed.** New/changed logic that matters
   has **regression tests** pinned to real ground truth. "It renders / no
   exception" is a smoke test, not a correctness test.
2. The project's validation gate is green (`VALIDATION_CMD`, usually
   `make test`).
3. `SPEC.md` (if present) updated in the same change + version bumped per its
   rules.
4. A **git commit** is made for the change (§4).
5. If UI was touched: the UI test sweep is green and preview restarts cleanly.

**Never label a change "validated" without 1 and 2.**

---

## 4. Git discipline

- **Per-change commits** — small, focused, message explains the *why*.
- The commit that bumps any SPEC version *is* the change; keep version and git
  history in step.
- **NEVER commit:** secrets, tokens, credentials, local machine settings, build
  caches, or large binaries. (See `.gitignore`.)
- **NEVER push or merge to `main` without explicit human go-ahead.** This repo
  shares `origin` with the live production site
  (https://peterex2004.github.io/kmb-bus-display/) — a push here goes live.
  Work happens on feature branches / worktrees; the human reviews and decides
  when (and whether) to merge/push.

---

## 5. Dual-agent workflow

This project uses the Claude-orchestrates / Codex-executes model. The full
operating model, leadership/disagreement rules, decision protocol, risk tiers,
and safety boundary live in `docs/agent-workflow.md` and `AGENTS.md`. Key
points:

- Claude leads and drives; Codex is a senior peer expected to challenge bad
  orders. Neither silently overrides nor silently complies.
- Codex works in an isolated worktree; validation is re-run independently by
  the orchestrator (false-green guard); the human owns the final merge
  (auto-merge off by default).
- Changing code to meet the *current* definition of correctness may proceed
  automatically; changing the *definition* of correctness requires human
  escalation.
