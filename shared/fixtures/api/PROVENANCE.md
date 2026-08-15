# Recorded API fixtures — provenance

Real, unmodified responses from the two public unauthenticated APIs the app
uses. Recorded **2026-08-15** by the orchestrator (not synthesised, not edited).
Byte-for-byte as returned; `generated_timestamp` / `data_timestamp` fields are
left intact so the recording date is self-evident.

| File | Endpoint |
|---|---|
| `kmb-route-1A-outbound-1.json` | `https://data.etabus.gov.hk/v1/transport/kmb/route/1A/outbound/1` |
| `kmb-route-stop-1A-outbound-1.json` | `.../kmb/route-stop/1A/outbound/1` |
| `kmb-eta-1A.json` | `.../kmb/eta/A8CE52F4450FE939/1A/1` |
| `kmb-stop-eta.json` | `.../kmb/stop-eta/A8CE52F4450FE939` |
| `ctb-route-1.json` | `https://rt.data.gov.hk/v1/transport/citybus-nwfb/route/ctb/1` |
| `ctb-route-stop-1-outbound.json` | `.../citybus-nwfb/route-stop/ctb/1/outbound` |
| `ctb-stop.json` | `.../citybus-nwfb/stop/001049` |
| `ctb-eta-1.json` | `.../citybus-nwfb/eta/ctb/001049/1` |

## Ground-truth quirks these pin (found in the real data, not invented)

1. **`service_type` changes JSON type across KMB endpoints** — String `"1"` in
   `/route/...`, Int `1` in `/eta/...`. A naive strict `Codable` model throws.
2. **`seq` type differs across operators** — String `"1"` in KMB
   `/route-stop`, Int `1` in CTB `/route-stop`.
3. **`lat`/`long` are Strings**, not numbers, in the CTB stop payload.
4. **`eta` can be `null`** — `kmb-stop-eta.json` contains a real row
   (route N293) with `"eta": null`. The web filters these out; the port must too.
5. **ETA timestamps carry a `+08:00` offset** (e.g. `2026-08-15T09:51:21+08:00`),
   so date parsing must accept an internet date-time with offset, not assume UTC.

Refreshing these is a deliberate act: re-record from the same endpoints and
update this file. Do **not** hand-edit the JSON.
