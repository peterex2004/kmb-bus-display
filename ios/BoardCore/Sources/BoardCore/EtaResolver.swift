/// Resolves fresh provider rows and stale last-known rows into display state.
public enum EtaResolver {
    public static func resolve(
        previous: EtaPreviousState,
        outcome: EtaFetchOutcome
    ) -> EtaDisplayState {
        if outcome.ok == true {
            let rows = outcome.rows ?? []
            if let first = rows.first {
                return EtaDisplayState(
                    etaRows: rows,
                    nearestEta: first.etaMs,
                    etaStale: false
                )
            }

            return EtaDisplayState(etaRows: [], nearestEta: nil, etaStale: false)
        }

        if let priorRows = previous.etaRows, !priorRows.isEmpty {
            return EtaDisplayState(etaRows: priorRows, nearestEta: nil, etaStale: true)
        }

        return EtaDisplayState(etaRows: nil, nearestEta: nil, etaStale: false)
    }
}
