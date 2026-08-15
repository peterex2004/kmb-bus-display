import Foundation

/// The provider fields needed by the pure ETA row-selection rule.
public struct EtaInputRow: Codable, Equatable, Sendable {
    public let dir: String
    public let eta: String?

    public init(dir: String, eta: String?) {
        self.dir = dir
        self.eta = eta
    }
}

/// Selects the ETA rows shown by the web board.
public enum EtaParser {
    /// Reproduces `fetchETA` in `index.html` with an injected epoch-millisecond
    /// clock. ISO-8601 offsets are interpreted from the input string itself.
    public static func parse(
        rows: [EtaInputRow],
        dirCode: String,
        now: Int
    ) -> [EtaRow] {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        let parsed = rows.compactMap { row -> EtaRow? in
            guard row.dir == dirCode,
                  let eta = row.eta,
                  let date = formatter.date(from: eta)
            else {
                return nil
            }

            let intervalMs = date.timeIntervalSince1970 * 1_000
            guard intervalMs.isFinite,
                  intervalMs >= Double(Int.min),
                  intervalMs <= Double(Int.max)
            else {
                return nil
            }

            let etaMs = Int(intervalMs.rounded())
            guard etaMs >= now else {
                return nil
            }
            return EtaRow(etaMs: etaMs)
        }

        return Array(parsed.sorted { ($0.etaMs ?? Int.max) < ($1.etaMs ?? Int.max) }.prefix(3))
    }
}
