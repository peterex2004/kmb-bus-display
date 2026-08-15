import Foundation

/// A board card and the fields consumed by the shared BoardLogic seam.
public struct BoardItem: Codable, Equatable, Sendable {
    public var id: String?
    public var company: String?
    public var route: String?
    public var stopId: String?
    public var dir: String?
    public var starred: Bool?
    public var nearestEta: Int?
    public var boardOrder: Int?
    public var etaRows: [EtaRow]?

    public init(
        id: String? = nil,
        company: String? = nil,
        route: String? = nil,
        stopId: String? = nil,
        dir: String? = nil,
        starred: Bool? = nil,
        nearestEta: Int? = nil,
        boardOrder: Int? = nil,
        etaRows: [EtaRow]? = nil
    ) {
        self.id = id
        self.company = company
        self.route = route
        self.stopId = stopId
        self.dir = dir
        self.starred = starred
        self.nearestEta = nearestEta
        self.boardOrder = boardOrder
        self.etaRows = etaRows
    }
}

/// A single ETA row from a provider response.
public struct EtaRow: Codable, Equatable, Sendable {
    public var etaMs: Int?

    public init(etaMs: Int? = nil) {
        self.etaMs = etaMs
    }
}

/// Inputs and results for reminder evaluation.
public struct ReminderState: Codable, Sendable {
    public var remindMe: Bool?
    public var nearestEta: Int?
    public var leadMs: Int?
    public var notifiedEta: Int?

    public init(
        remindMe: Bool?,
        nearestEta: Int?,
        leadMs: Int?,
        notifiedEta: Int?
    ) {
        self.remindMe = remindMe
        self.nearestEta = nearestEta
        self.leadMs = leadMs
        self.notifiedEta = notifiedEta
    }
}

public struct ReminderEvaluation: Equatable, Sendable {
    public let shouldNotify: Bool
    public let notifiedEta: Int?
    public let minutes: Double?

    public init(shouldNotify: Bool, notifiedEta: Int?, minutes: Double?) {
        self.shouldNotify = shouldNotify
        self.notifiedEta = notifiedEta
        self.minutes = minutes
    }
}

public struct ReminderLead: Codable, Equatable, Sendable {
    public let remindMe: Bool
    public let remindLeadMin: Int?

    public init(remindMe: Bool, remindLeadMin: Int?) {
        self.remindMe = remindMe
        self.remindLeadMin = remindLeadMin
    }
}

public struct FreshnessResult: Equatable, Sendable {
    public let stale: Bool
    public let ageMs: Int?

    public init(stale: Bool, ageMs: Int?) {
        self.stale = stale
        self.ageMs = ageMs
    }
}

public struct EtaPreviousState: Codable, Sendable {
    public var etaRows: [EtaRow]?

    public init(etaRows: [EtaRow]?) {
        self.etaRows = etaRows
    }
}

public struct EtaFetchOutcome: Codable, Sendable {
    public var ok: Bool?
    public var rows: [EtaRow]?

    public init(ok: Bool?, rows: [EtaRow]?) {
        self.ok = ok
        self.rows = rows
    }
}

public struct EtaDisplayState: Equatable, Sendable {
    public let etaRows: [EtaRow]?
    public let nearestEta: Int?
    public let etaStale: Bool

    public init(etaRows: [EtaRow]?, nearestEta: Int?, etaStale: Bool) {
        self.etaRows = etaRows
        self.nearestEta = nearestEta
        self.etaStale = etaStale
    }
}
