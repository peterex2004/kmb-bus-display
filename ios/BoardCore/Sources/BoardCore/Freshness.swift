/// Computes whether the last successful refresh has crossed the stale window.
public enum FreshnessEvaluator {
    public static func evaluate(
        _ lastSuccessMs: Int?,
        now: Int?,
        staleAfterMs: Int? = BoardConstants.staleAfterMs
    ) -> FreshnessResult {
        guard let lastSuccessMs else {
            return FreshnessResult(stale: false, ageMs: nil)
        }

        guard let now, let staleAfterMs else {
            return FreshnessResult(stale: false, ageMs: nil)
        }

        let ageMs = now - lastSuccessMs
        return FreshnessResult(stale: ageMs >= staleAfterMs, ageMs: ageMs)
    }
}

/// Formats the bilingual age label used by the board freshness banner.
public enum FreshnessFormatter {
    public static func age(_ ageMs: Int) -> String {
        let seconds = max(0, ageMs) / 1_000
        if seconds < 60 {
            return "更新於 \(seconds) 秒前 · Updated \(seconds)s ago"
        }

        let minutes = seconds / 60
        return "更新於 \(minutes) 分鐘前 · Updated \(minutes)m ago"
    }
}
