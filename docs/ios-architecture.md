# iOS architecture — 九巴/城巴班次顯示

Design record for the native iOS target. Companion to `CLAUDE.md` (governance)
and `docs/backlog.md` (feature list). Status: **Phase 0 shipped; Phase 1 ready
to start.**

---

## 1. Why native, not a WebView

The existing PWA already works on iPhone. The port is only worth doing for what
a web page **cannot** do:

| Want | Web today | Native |
|---|---|---|
| Reminder fires when app is closed | ❌ foreground-only (UI says 「只限開啟頁面時」) | ✅ local notifications |
| Lock Screen / Dynamic Island countdown | ❌ | ✅ ActivityKit |
| Home screen widget | ❌ | ✅ WidgetKit |
| Map without a CDN round-trip | ❌ Leaflet from `unpkg` | ✅ MapKit |

Rejected alternatives: **WKWebView wrapper** (inherits every limitation above —
defeats the purpose); **Capacitor / React Native** (adds a framework and a JS
build chain, contradicting the simplicity rule on both targets).

---

## 2. Layering

```
┌──────────────────────────────────────────────────┐
│ Presentation — SwiftUI + @Observable             │
│ BoardView · SearchView · StopView · NearbyView   │
├──────────────────────────────────────────────────┤
│ Feature — BoardStore · RefreshCoordinator ·      │
│           ReminderManager                        │
├──────────────────────────────────────────────────┤
│ ★ BoardCore — pure Swift, zero dependencies      │
│   BoardComparator · ReminderEngine ·             │
│   FreshnessEvaluator · EtaResolver ·             │
│   RefreshPolicy · Reorder                        │
├──────────────────────────────────────────────────┤
│ Data — TransitProvider protocol                  │
│        KMBProvider · CTBProvider · DTOs · caches │
├──────────────────────────────────────────────────┤
│ Persistence — on-device only                     │
├──────────────────────────────────────────────────┤
│ Platform — CoreLocation · UserNotifications ·    │
│            ActivityKit · WidgetKit               │
└──────────────────────────────────────────────────┘
```

Dependencies point **downward only**. `BoardCore` knows nothing above it.

---

## 3. BoardCore — the shared domain

The web `BoardLogic` IIFE is already pure and DOM-free. It is the domain model,
and it ports 1:1:

| Web (`BoardLogic`) | Swift (`BoardCore`) |
|---|---|
| `compareBoardItems` | `BoardComparator.auto` |
| `compareBoardManual` | `BoardComparator.manual` |
| `reorderBoardOrder` | `reorder(_:from:to:)` |
| `evaluateReminder` | `ReminderEngine.evaluate(_:now:)` |
| `nextReminderLead` | `ReminderEngine.nextLead(_:)` |
| `evaluateFreshness` | `FreshnessEvaluator.evaluate(_:now:)` |
| `resolveEtaDisplay` | `EtaResolver.resolve(previous:outcome:)` |
| `shouldRunBackground` | `RefreshPolicy.shouldRun(hidden:boardActive:)` |
| `formatFreshnessAge` | `FreshnessFormatter.age(_:)` |

**Parity is machine-checked, not assumed.** Both implementations are validated
against `shared/fixtures/board-logic.vectors.json` — 88 cases, schema v1,
strict JSON with no `NaN`/`Infinity`/`undefined`, readable by `Codable` with no
preprocessing. Constants pinned there: `STALE_AFTER_MS` 60000,
`REARM_TOLERANCE_MS` 90000, `REMINDER_LEADS` [3,5,10].

Rules for `BoardCore`: no `Date()` inside (inject `now`, as the web does), no
networking, no UI, no third-party imports.

---

## 4. Known hard constraint — background refresh

iOS has **no equivalent of the web's 15-second polling loop** when the app is
not foreground:

- `BGAppRefreshTask` is *opportunistic* — the system decides, often ≥15 min
  apart. Unusable for a 3-minute arrival warning.
- Accurate push would need APNs **and a server** — forbidden by the no-backend
  rule, and it needs the paid developer account.
- ActivityKit self-updates without push have a limited budget.

**⚠️ OPEN DECISION 1 — reminder strategy.** Not yet decided by the human.
Candidates:

- **(a) Predictive local notification** *(recommended)* — on each refresh,
  schedule a local notification for `ETA − lead`; re-schedule on every
  foreground refresh. Fires with the app closed, no backend. Honest trade-off:
  best-effort, drifts when the bus does.
- **(b) Foreground + Live Activity only** — never wrong, never notifies cold.
- **(c) Backend push** — most accurate; **breaks the no-backend North Star**.

Whichever is chosen, the guardrail from web item #9 carries over: **stale data
must never fire a reminder** (`nearestEta == nil` ⇒ no notification).

---

## 5. Feature parity checklist

Carried from the web app: route search (numpad + live match), stop picking per
route/direction, the board with ETA pills and 15s foreground refresh,
auto/manual ordering (#1/#10), reminders with 3/5/10-min leads (#3/#5/#6),
freshness banner (#4/#7), visibility-aware refresh (#8), offline last-known
ETAs (#9), nearby stops with distance + map, share, star/favourites.

**⚠️ OPEN DECISION 3 — v1 scope.** Candidates: board + reminders first
*(recommended)*; full parity incl. nearby map + share; or a thin spike.

---

## 6. Phases

| Phase | Deliverable | Gate |
|---|---|---|
| **0** ✅ | Golden vectors extracted to `shared/fixtures/` | JS gate green, 88 cases — **shipped, PR #12** |
| **1** | `BoardCore` Swift module | Swift tests pass the **same** 88 vectors |
| **2** | `TransitProvider` + KMB/CTB, recorded API fixtures | Offline-replayable provider tests |
| **3** | SwiftUI board / search / stop | Runs in Simulator |
| **4** | Local notifications, MapKit nearby, Live Activity, widget | On-device |

---

## 7. Repo layout

One repo. `index.html` stays at root so GitHub Pages is untouched:

```
index.html            ← web target (unchanged)
scripts/              ← web validation gate
shared/fixtures/      ← golden vectors, consumed by BOTH targets
ios/                  ← Xcode project + BoardCore (Phase 1+)
docs/
```

Separate repos were rejected: keeping the golden vectors in sync across two
remotes is exactly the drift this design exists to prevent.

---

## 8. Toolchain baseline (verified 2026-08-15)

Xcode 26.6 · Swift 6.3.3 · iOS 26.5 SDK · iOS 26.5 Simulator runtime installed
(11 devices available). Signing: free *Apple Development* identity — enough for
Simulator and short-lived device installs; a paid Apple Developer Program
membership is required only for a permanent on-device install (7-day expiry
otherwise) and for APNs.
