# 九巴班次顯示 — KMB Bus Display

A personal real-time bus arrival display for KMB (Kowloon Motor Bus) Hong Kong, designed for a 12" standing screen.

**Live app:** https://peterex2004.github.io/kmb-bus-display/

---

## MVP v1 — Features

### Screen 1 · Route Search 路線搜尋
- On-screen numpad (no keyboard required) — touch-friendly
- Smart filtering: only valid next characters are shown as letter buttons; invalid digits are dimmed
- 797 KMB routes hardcoded for instant O(1) prefix matching (no API call needed)
- Route list shows all matching routes with outbound / inbound destinations
- Tap any route in the list to jump straight to the stop picker

### Screen 2 · Stop Picker 站點選擇
- Shows all stops for the selected route and direction
- Real-time ETA fetched in parallel for every stop on load
- Auto-expands the stop with the nearest arriving bus
- Tap any stop to expand / collapse its ETA detail
- Direction tabs (往 outbound / 往 inbound) — switch without leaving the screen
- ☆ Star button is the **only** way to save a stop to the departure board
- Fixed-height tiles with scrolling — works cleanly regardless of route length

### Screen 3 · Departure Board 班次顯示板
- Traditional departure board style, white / light theme
- Shows: route number · destination · stop name · ETA pills (即將抵達 / X 分鐘)
- Auto-refreshes every 15 seconds
- ★ Star toggle per card (starred cards highlighted in gold)
- Tap any card to open its stop picker (back returns to board)
- Edit mode to remove cards
- Magnifier button (🔍) in header to return to route search

### General
- Single HTML file — no build step, no backend, no dependencies
- Uses KMB public API (`data.etabus.gov.hk`) — no authentication required
- Stale ETA cancellation: switching direction cancels in-flight requests
- Offline banner when network is unavailable
- Responsive layout: compact mode for landscape / small screens
- Board persisted in `localStorage` — survives page refresh

---

## Tech notes

| Item | Detail |
|---|---|
| API base | `https://data.etabus.gov.hk/v1/transport/kmb` |
| Route data | 797 routes hardcoded; prefix trie built at startup |
| Stop names | Stop codes like `(WT916)` stripped via `cleanName()` |
| ETA fetch | `Promise.allSettled` across all stops in parallel |
| Persistence | `localStorage` key `kmb_board` |

---

## How to run locally

```bash
python3 -m http.server 8080
# open http://localhost:8080
```

Opening `index.html` directly as `file://` may block API calls in some browsers.

---

## Version history

| Version | Date | Notes |
|---|---|---|
| v1.0 | 2026-07-01 | MVP — route search, stop picker, departure board |
