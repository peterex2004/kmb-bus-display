import Foundation
import XCTest
@testable import BoardCore

final class BoardCoreVectorTests: XCTestCase {
    func testSharedFixture() {
        do {
            let fixture = try Fixture.load()
            let expectedCaseCounts = [
                "compareBoardItems": 2,
                "compareBoardManual": 4,
                "reorderBoardOrder": 11,
                "resolveEtaDisplay": 12,
                "shouldRunBackground": 4,
                "evaluateFreshness": 8,
                "formatFreshnessAge": 6,
                "nextReminderLead": 1,
                "evaluateReminder": 37,
                "constants": 3
            ]

            XCTAssertEqual(fixture.schemaVersion, 1, "fixture schema version is supported")
            XCTAssertEqual(
                Set(fixture.groups.keys),
                Set(expectedCaseCounts.keys),
                "fixture declares exactly the expected BoardCore groups"
            )

            var validatedGroups: [String: [VectorCase]] = [:]
            var totalCaseCount = 0

            for groupName in expectedCaseCounts.keys.sorted() {
                guard let cases = fixture.groups[groupName] else {
                    XCTFail("fixture group \(groupName) is missing")
                    continue
                }

                XCTAssertFalse(cases.isEmpty, "fixture group \(groupName) is not empty")
                XCTAssertEqual(
                    cases.count,
                    expectedCaseCounts[groupName],
                    "\(groupName) fixture case count is unchanged"
                )

                for vectorCase in cases {
                    for absentKey in vectorCase.absentKeys {
                        XCTAssertFalse(
                            hasOwnPath(vectorCase.raw, absentKey),
                            "\(groupName) \(vectorCase.name): absent key \(absentKey) is omitted"
                        )
                    }
                }

                validatedGroups[groupName] = cases
                totalCaseCount += cases.count
                print("PASS: \(groupName) fixture cases asserted: \(cases.count)")
            }

            XCTAssertEqual(totalCaseCount, 88, "total fixture case count is unchanged")
            print("PASS: total fixture cases asserted: \(totalCaseCount)")

            runCompareBoardItems(validatedGroups["compareBoardItems"] ?? [])
            runCompareBoardManual(validatedGroups["compareBoardManual"] ?? [])
            runReorder(validatedGroups["reorderBoardOrder"] ?? [])
            runEtaResolver(validatedGroups["resolveEtaDisplay"] ?? [])
            runBackgroundPolicy(validatedGroups["shouldRunBackground"] ?? [])
            runFreshness(validatedGroups["evaluateFreshness"] ?? [])
            runFreshnessFormatter(validatedGroups["formatFreshnessAge"] ?? [])
            runReminderLeads(validatedGroups["nextReminderLead"] ?? [])
            runReminder(validatedGroups["evaluateReminder"] ?? [])
            runConstants(validatedGroups["constants"] ?? [])
        } catch {
            XCTFail("shared fixture could not be executed: \(error)")
        }
    }

    func testNumericStringCollationForBothComparators() throws {
        let routes = ["10", "2"]
        let items = routes.map {
            BoardItem(
                company: "KMB",
                route: $0,
                stopId: "S",
                dir: "outbound",
                nearestEta: 60_000,
                boardOrder: 0
            )
        }

        let auto = items.sorted { BoardComparator.auto($0, $1) == .orderedAscending }
        let manual = items.sorted { BoardComparator.manual($0, $1) == .orderedAscending }
        XCTAssertEqual(auto.map(\.route), ["2", "10"])
        XCTAssertEqual(manual.map(\.route), ["2", "10"])
    }

    func testComparatorOutputIsByteIdenticalAcrossShuffles() throws {
        let items = ["2", "10", "11", "3"].map {
            BoardItem(
                id: $0,
                company: "KMB",
                route: $0,
                stopId: "S",
                dir: "outbound",
                nearestEta: 60_000,
                boardOrder: 4
            )
        }
        let shuffles = [
            [0, 1, 2, 3],
            [3, 2, 1, 0],
            [1, 3, 0, 2],
            [2, 0, 3, 1]
        ]
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        let autoOutputs = try shuffles.map { permutation in
            try encoder.encode(permutation.map { items[$0] }.sorted {
                BoardComparator.auto($0, $1) == .orderedAscending
            })
        }
        let manualOutputs = try shuffles.map { permutation in
            try encoder.encode(permutation.map { items[$0] }.sorted {
                BoardComparator.manual($0, $1) == .orderedAscending
            })
        }

        XCTAssertTrue(autoOutputs.dropFirst().allSatisfy { $0 == autoOutputs[0] })
        XCTAssertTrue(manualOutputs.dropFirst().allSatisfy { $0 == manualOutputs[0] })
        XCTAssertEqual(autoOutputs[0], manualOutputs[0])
    }

    private func runCompareBoardItems(_ cases: [VectorCase]) {
        for vectorCase in cases {
            do {
                let input = try decode(vectorCase.input, as: CompareInput.self)
                let expected = vectorCase.expectedObject

                if let expectedRoutes = expected["orderedRoutes"] {
                    let ordered = (input.items ?? []).sorted {
                        BoardComparator.auto($0, $1) == .orderedAscending
                    }
                    XCTAssertEqual(
                        ordered.map(\.route),
                        try decode(expectedRoutes, as: [String].self),
                        vectorCase.name
                    )
                }
                if let expectedSign = expected["comparisonSign"] {
                    let actual = try XCTUnwrap(input.a)
                    let other = try XCTUnwrap(input.b)
                    XCTAssertEqual(
                        comparisonSign(BoardComparator.auto(actual, other)),
                        try decode(expectedSign, as: Int.self),
                        vectorCase.name
                    )
                }
            } catch {
                XCTFail("\(vectorCase.name): \(error)")
            }
        }
    }

    private func runCompareBoardManual(_ cases: [VectorCase]) {
        for vectorCase in cases {
            do {
                let input = try decode(vectorCase.input, as: CompareInput.self)
                let expected = vectorCase.expectedObject

                if let expectedRoutes = expected["orderedRoutes"] {
                    let ordered = (input.items ?? []).sorted {
                        BoardComparator.manual($0, $1) == .orderedAscending
                    }
                    XCTAssertEqual(
                        ordered.map(\.route),
                        try decode(expectedRoutes, as: [String].self),
                        vectorCase.name
                    )
                }
                if let expectedSign = expected["comparisonSign"] {
                    let actual = try XCTUnwrap(input.a)
                    let other = try XCTUnwrap(input.b)
                    XCTAssertEqual(
                        comparisonSign(BoardComparator.manual(actual, other)),
                        try decode(expectedSign, as: Int.self),
                        vectorCase.name
                    )
                }
            } catch {
                XCTFail("\(vectorCase.name): \(error)")
            }
        }
    }

    private func runReorder(_ cases: [VectorCase]) {
        for vectorCase in cases {
            do {
                let input = try decode(vectorCase.input, as: ReorderInput.self)
                let original = input.items
                let result = reorder(input.items ?? [], from: input.fromIndex, to: input.toIndex)
                let expected = vectorCase.expectedObject

                if vectorCase.assertInputUnchanged {
                    XCTAssertEqual(input.items, original, vectorCase.name)
                }
                if vectorCase.assertClonedItems {
                    // BoardItem is a struct, so every returned card has value
                    // semantics and cannot alias an input reference.
                    var detached = result
                    let beforeDetachedMutation = result
                    if !detached.isEmpty {
                        detached[0].id = "__detached_value__"
                    }
                    XCTAssertEqual(result, beforeDetachedMutation, vectorCase.name)
                }
                if let orderedIds = expected["orderedIds"] {
                    XCTAssertEqual(
                        result.map(\.id),
                        try decode(orderedIds, as: [String?].self),
                        vectorCase.name
                    )
                }
                if let boardOrders = expected["boardOrders"] {
                    XCTAssertEqual(
                        result.map(\.boardOrder),
                        try decode(boardOrders, as: [Int?].self),
                        vectorCase.name
                    )
                }
                if let isArray = expected["isArray"] {
                    XCTAssertEqual(true, try decode(isArray, as: Bool.self), vectorCase.name)
                }
                if let length = expected["length"] {
                    XCTAssertEqual(result.count, try decode(length, as: Int.self), vectorCase.name)
                }
            } catch {
                XCTFail("\(vectorCase.name): \(error)")
            }
        }
    }

    private func runEtaResolver(_ cases: [VectorCase]) {
        for vectorCase in cases {
            do {
                let input = try decode(vectorCase.input, as: EtaInput.self)
                let actual = EtaResolver.resolve(
                    previous: input.previous,
                    outcome: input.outcome
                )
                let expected = vectorCase.expectedObject

                if let identityPath = vectorCase.assertRowsIdentity {
                    let expectedRows: [EtaRow]? = identityPath == "outcome.rows"
                        ? input.outcome.rows
                        : input.previous.etaRows
                    XCTAssertEqual(actual.etaRows, expectedRows, vectorCase.name)
                }
                if let etaRows = expected["etaRows"] {
                    XCTAssertEqual(
                        actual.etaRows,
                        try decode(etaRows, as: [EtaRow]?.self),
                        vectorCase.name
                    )
                }
                if let nearestEta = expected["nearestEta"] {
                    XCTAssertEqual(
                        actual.nearestEta,
                        try decode(nearestEta, as: Int?.self),
                        vectorCase.name
                    )
                }
                if let etaStale = expected["etaStale"] {
                    XCTAssertEqual(
                        actual.etaStale,
                        try decode(etaStale, as: Bool.self),
                        vectorCase.name
                    )
                }
            } catch {
                XCTFail("\(vectorCase.name): \(error)")
            }
        }
    }

    private func runBackgroundPolicy(_ cases: [VectorCase]) {
        for vectorCase in cases {
            do {
                let input = try decode(vectorCase.input, as: BackgroundInput.self)
                let expected = try decode(vectorCase.expected, as: Bool.self)
                XCTAssertEqual(
                    RefreshPolicy.shouldRun(hidden: input.hidden, boardActive: input.boardActive),
                    expected,
                    vectorCase.name
                )
            } catch {
                XCTFail("\(vectorCase.name): \(error)")
            }
        }
    }

    private func runFreshness(_ cases: [VectorCase]) {
        for vectorCase in cases {
            do {
                let expected = vectorCase.expectedObject

                if let olderAgeGreater = expected["olderAgeGreater"] {
                    let input = try decode(vectorCase.input, as: FreshnessComparisonInput.self)
                    let newer = input.newer
                    let older = input.older
                    let newerResult = FreshnessEvaluator.evaluate(
                        newer.lastSuccessMs,
                        now: newer.now,
                        staleAfterMs: newer.staleAfterMs
                    )
                    let olderResult = FreshnessEvaluator.evaluate(
                        older.lastSuccessMs,
                        now: older.now,
                        staleAfterMs: older.staleAfterMs
                    )
                    XCTAssertEqual(
                        olderResult.ageMs! > newerResult.ageMs!,
                        try decode(olderAgeGreater, as: Bool.self),
                        vectorCase.name
                    )
                } else {
                    let input = try decode(vectorCase.input, as: FreshnessInput.self)
                    let actual = FreshnessEvaluator.evaluate(
                        input.lastSuccessMs,
                        now: input.now,
                        staleAfterMs: input.staleAfterMs
                    )
                    if let stale = expected["stale"] {
                        XCTAssertEqual(actual.stale, try decode(stale, as: Bool.self), vectorCase.name)
                    }
                    if let ageMs = expected["ageMs"] {
                        XCTAssertEqual(actual.ageMs, try decode(ageMs, as: Int?.self), vectorCase.name)
                    }
                }
            } catch {
                XCTFail("\(vectorCase.name): \(error)")
            }
        }
    }

    private func runFreshnessFormatter(_ cases: [VectorCase]) {
        for vectorCase in cases {
            do {
                let input = try decode(vectorCase.input, as: AgeInput.self)
                let expected = try decode(vectorCase.expected, as: String.self)
                XCTAssertEqual(FreshnessFormatter.age(input.ageMs), expected, vectorCase.name)
            } catch {
                XCTFail("\(vectorCase.name): \(error)")
            }
        }
    }

    private func runReminderLeads(_ cases: [VectorCase]) {
        for vectorCase in cases {
            do {
                let input = try decode(vectorCase.input, as: ReminderLeadInput.self)
                let expected = try decode(vectorCase.expected, as: ReminderLeadCycle.self)
                var current = input.startingLead
                var cycle: [ReminderLead] = []
                for _ in 0..<input.steps {
                    let next = ReminderEngine.nextLead(current)
                    cycle.append(next)
                    current = next.remindMe ? next.remindLeadMin : nil
                }
                XCTAssertEqual(cycle, expected.cycle, vectorCase.name)
            } catch {
                XCTFail("\(vectorCase.name): \(error)")
            }
        }
    }

    private func runReminder(_ cases: [VectorCase]) {
        var chainResults: [String: [String: ReminderEvaluation]] = [:]

        for vectorCase in cases where vectorCase.chainAssertion == nil {
            do {
                let input = try decode(vectorCase.input, as: ReminderInput.self)
                let actual = ReminderEngine.evaluate(
                    ReminderState(
                        remindMe: input.remindMe,
                        nearestEta: input.nearestEta,
                        leadMs: input.leadMs,
                        notifiedEta: input.notifiedEta
                    ),
                    now: input.now
                )
                let expected = vectorCase.expectedObject
                if let shouldNotify = expected["shouldNotify"] {
                    XCTAssertEqual(
                        actual.shouldNotify,
                        try decode(shouldNotify, as: Bool.self),
                        vectorCase.name
                    )
                }
                if let notifiedEta = expected["notifiedEta"] {
                    XCTAssertEqual(
                        actual.notifiedEta,
                        try decode(notifiedEta, as: Int?.self),
                        vectorCase.name
                    )
                }
                if let minutes = expected["minutes"] {
                    XCTAssertEqual(
                        actual.minutes,
                        try decode(minutes, as: Double?.self),
                        vectorCase.name
                    )
                }
                if let chain = vectorCase.chain, let chainStep = vectorCase.chainStep {
                    chainResults[chain, default: [:]][chainStep] = actual
                }
            } catch {
                XCTFail("\(vectorCase.name): \(error)")
            }
        }

        for vectorCase in cases where vectorCase.chainAssertion != nil {
            do {
                let assertion = try XCTUnwrap(vectorCase.chainAssertion)
                let results = try XCTUnwrap(chainResults[assertion.chain])
                let fireCount = results.values.filter(\.shouldNotify).count
                XCTAssertEqual(fireCount, assertion.shouldNotifyCount, vectorCase.name)
            } catch {
                XCTFail("\(vectorCase.name): \(error)")
            }
        }
    }

    private func runConstants(_ cases: [VectorCase]) {
        for vectorCase in cases {
            do {
                let input = try decode(vectorCase.input, as: ConstantInput.self)
                switch input.key {
                case "STALE_AFTER_MS":
                    XCTAssertEqual(
                        BoardConstants.staleAfterMs,
                        try decode(vectorCase.expected, as: Int.self),
                        vectorCase.name
                    )
                case "REARM_TOLERANCE_MS":
                    XCTAssertEqual(
                        BoardConstants.rearmToleranceMs,
                        try decode(vectorCase.expected, as: Int.self),
                        vectorCase.name
                    )
                case "REMINDER_LEADS":
                    XCTAssertEqual(
                        BoardConstants.reminderLeads,
                        try decode(vectorCase.expected, as: [Int].self),
                        vectorCase.name
                    )
                default:
                    XCTFail("\(vectorCase.name): unknown constant key \(input.key)")
                }
            } catch {
                XCTFail("\(vectorCase.name): \(error)")
            }
        }
    }
}

private struct CompareInput: Codable {
    var items: [BoardItem]?
    var a: BoardItem?
    var b: BoardItem?
}

private struct ReorderInput: Codable {
    var items: [BoardItem]?
    var fromIndex: Int?
    var toIndex: Int?
}

private struct EtaInput: Codable {
    var previous: EtaPreviousState
    var outcome: EtaFetchOutcome
}

private struct BackgroundInput: Codable {
    var hidden: Bool?
    var boardActive: Bool?
}

private struct FreshnessInput: Codable {
    var lastSuccessMs: Int?
    var now: Int?
    var staleAfterMs: Int?
}

private struct FreshnessComparisonInput: Codable {
    var newer: FreshnessInput
    var older: FreshnessInput
}

private struct AgeInput: Codable {
    var ageMs: Int
}

private struct ReminderLeadInput: Codable {
    var startingLead: Int?
    var steps: Int
}

private struct ReminderLeadCycle: Codable, Equatable {
    var cycle: [ReminderLead]
}

private struct ReminderInput: Codable {
    var remindMe: Bool?
    var nearestEta: Int?
    var leadMs: Int?
    var notifiedEta: Int?
    var now: Int?
}

private struct ChainAssertion: Codable {
    var chain: String
    var shouldNotifyCount: Int
}

private struct ConstantInput: Codable {
    var key: String
}

private struct VectorCase {
    let raw: JSONValue
    let object: [String: JSONValue]

    init(raw: JSONValue) {
        self.raw = raw
        self.object = raw.objectValue ?? [:]
    }

    var name: String { object["name"]?.stringValue ?? "<unnamed vector>" }
    var input: JSONValue { object["input"] ?? .null }
    var expected: JSONValue { object["expected"] ?? .null }
    var expectedObject: [String: JSONValue] { expected.objectValue ?? [:] }
    var absentKeys: [String] { object["absentKeys"]?.stringArrayValue ?? [] }
    var assertInputUnchanged: Bool { object["assertInputUnchanged"]?.boolValue ?? false }
    var assertClonedItems: Bool { object["assertClonedItems"]?.boolValue ?? false }
    var assertRowsIdentity: String? { object["assertRowsIdentity"]?.stringValue }
    var chain: String? { object["chain"]?.stringValue }
    var chainStep: String? { object["chainStep"]?.stringValue }
    var chainAssertion: ChainAssertion? {
        guard let value = object["chainAssertion"] else { return nil }
        return try? decode(value, as: ChainAssertion.self)
    }
}

private struct Fixture {
    let schemaVersion: Int
    let groups: [String: [VectorCase]]

    static func load(filePath: String = #filePath) throws -> Fixture {
        let fixtureURL = try fixtureURL(from: filePath)
        let data = try Data(contentsOf: fixtureURL)
        let root = try JSONDecoder().decode(JSONValue.self, from: data)
        let rootObject = try root.requiredObject()
        let schemaVersion = try rootObject.required("schemaVersion").integerValueRequired()
        let groupObject = try rootObject.required("groups").requiredObject()
        var groups: [String: [VectorCase]] = [:]

        for (name, groupValue) in groupObject {
            let group = try groupValue.requiredObject()
            let rawCases = try group.required("cases").requiredArray()
            groups[name] = rawCases.map(VectorCase.init(raw:))
        }

        return Fixture(schemaVersion: schemaVersion, groups: groups)
    }

    private static func fixtureURL(from filePath: String) throws -> URL {
        var directory = URL(fileURLWithPath: filePath).deletingLastPathComponent()
        let fileManager = FileManager.default

        while directory.path != "/" {
            let candidate = directory
                .appendingPathComponent("shared")
                .appendingPathComponent("fixtures")
                .appendingPathComponent("board-logic.vectors.json")
            if fileManager.fileExists(atPath: candidate.path) {
                return candidate
            }
            directory.deleteLastPathComponent()
        }

        throw FixtureError("could not find shared fixture above \(filePath)")
    }
}

private enum FixtureError: Error, CustomStringConvertible {
    case message(String)

    init(_ message: String) { self = .message(message) }

    var description: String {
        switch self {
        case .message(let message): return message
        }
    }
}

private enum JSONValue: Codable {
    case object([String: JSONValue])
    case array([JSONValue])
    case string(String)
    case integer(Int)
    case double(Double)
    case boolean(Bool)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .boolean(value)
        } else if let value = try? container.decode(Int.self) {
            self = .integer(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "unsupported JSON value"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .object(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .integer(let value): try container.encode(value)
        case .double(let value): try container.encode(value)
        case .boolean(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }

    var objectValue: [String: JSONValue]? {
        guard case .object(let value) = self else { return nil }
        return value
    }

    var stringValue: String? {
        guard case .string(let value) = self else { return nil }
        return value
    }

    var boolValue: Bool? {
        guard case .boolean(let value) = self else { return nil }
        return value
    }

    var stringArrayValue: [String]? {
        guard case .array(let values) = self else { return nil }
        return values.compactMap(\.stringValue)
    }

    func requiredObject() throws -> [String: JSONValue] {
        guard let value = objectValue else { throw FixtureError("expected JSON object") }
        return value
    }

    func requiredArray() throws -> [JSONValue] {
        guard case .array(let value) = self else { throw FixtureError("expected JSON array") }
        return value
    }

    func integerValueRequired() throws -> Int {
        guard case .integer(let value) = self else { throw FixtureError("expected integer") }
        return value
    }
}

private extension Dictionary where Key == String, Value == JSONValue {
    func required(_ key: String) throws -> JSONValue {
        guard let value = self[key] else { throw FixtureError("missing JSON key \(key)") }
        return value
    }
}

private func decode<T: Decodable>(_ value: JSONValue, as type: T.Type) throws -> T {
    let data = try JSONEncoder().encode(value)
    return try JSONDecoder().decode(T.self, from: data)
}

private func hasOwnPath(_ root: JSONValue, _ path: String) -> Bool {
    var current = root
    for segment in path.split(separator: ".", omittingEmptySubsequences: false).map(String.init) {
        switch current {
        case .object(let object):
            guard let next = object[segment] else { return false }
            current = next
        case .array(let array):
            guard let index = Int(segment), array.indices.contains(index) else { return false }
            current = array[index]
        default:
            return false
        }
    }
    return true
}

private func comparisonSign(_ result: ComparisonResult) -> Int {
    switch result {
    case .orderedAscending: return -1
    case .orderedDescending: return 1
    case .orderedSame: return 0
    @unknown default: return 0
    }
}
