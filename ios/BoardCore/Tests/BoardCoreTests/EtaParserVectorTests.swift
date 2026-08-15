import Foundation
import XCTest
@testable import BoardCore

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

final class EtaParserVectorTests: XCTestCase {
    func testEtaParserVectors() throws {
        let fixture = try EtaVectorFixture.load(filePath: #filePath)
        let expectedCounts = [
            "filters": 1,
            "pastAndBoundary": 1,
            "sortAndCap": 1,
            "invalidAndOffset": 2
        ]

        XCTAssertEqual(fixture.schemaVersion, 1, "ETA fixture schema version is supported")
        XCTAssertEqual(
            Set(fixture.groups.keys),
            Set(expectedCounts.keys),
            "ETA fixture declares exactly the expected groups"
        )

        var total = 0
        for groupName in expectedCounts.keys.sorted() {
            guard let group = fixture.groups[groupName] else {
                XCTFail("ETA fixture group \(groupName) is missing")
                continue
            }

            XCTAssertFalse(group.cases.isEmpty, "ETA fixture group \(groupName) is not empty")
            XCTAssertEqual(
                group.cases.count,
                expectedCounts[groupName],
                "\(groupName) ETA fixture case count is unchanged"
            )
            total += group.cases.count

            for vectorCase in group.cases {
                let actual = EtaParser.parse(
                    rows: vectorCase.input.rows,
                    dirCode: vectorCase.input.dirCode,
                    now: vectorCase.input.now
                )
                XCTAssertEqual(actual, vectorCase.expected, vectorCase.name)
            }
            print("PASS: \(groupName) ETA fixture cases asserted: \(group.cases.count)")
        }

        XCTAssertEqual(total, 5, "total ETA fixture case count is unchanged")
        print("PASS: total ETA fixture cases asserted: \(total)")
    }

    func testOffsetParsingIsIndependentOfProcessTimeZone() throws {
        let row = EtaInputRow(dir: "O", eta: "2026-08-15T09:51:21+08:00")
        let now = 1786758681000
        let originalTZ = getenv("TZ").map { String(cString: $0) }

        defer {
            if let originalTZ {
                setenv("TZ", originalTZ, 1)
            } else {
                unsetenv("TZ")
            }
            tzset()
        }

        setenv("TZ", "UTC", 1)
        tzset()
        let utcResult = EtaParser.parse(rows: [row], dirCode: "O", now: now)

        setenv("TZ", "Pacific/Honolulu", 1)
        tzset()
        let honoluluResult = EtaParser.parse(rows: [row], dirCode: "O", now: now)

        XCTAssertEqual(utcResult, [EtaRow(etaMs: now)])
        XCTAssertEqual(honoluluResult, utcResult)
    }
}

private struct EtaVectorFixture: Decodable {
    let schemaVersion: Int
    let groups: [String: EtaVectorGroup]

    static func load(filePath: String) throws -> EtaVectorFixture {
        var directory = URL(fileURLWithPath: filePath).deletingLastPathComponent()
        let fileManager = FileManager.default

        while directory.path != "/" {
            let candidate = directory
                .appendingPathComponent("shared")
                .appendingPathComponent("fixtures")
                .appendingPathComponent("eta-parse.vectors.json")
            if fileManager.fileExists(atPath: candidate.path) {
                return try JSONDecoder().decode(EtaVectorFixture.self, from: Data(contentsOf: candidate))
            }
            directory.deleteLastPathComponent()
        }

        throw NSError(domain: "EtaVectorFixture", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "could not find eta-parse.vectors.json above \(filePath)"
        ])
    }
}

private struct EtaVectorGroup: Decodable {
    let cases: [EtaVectorCase]
}

private struct EtaVectorCase: Decodable {
    let name: String
    let input: EtaVectorInput
    let expected: [EtaRow]
}

private struct EtaVectorInput: Decodable {
    let dirCode: String
    let now: Int
    let rows: [EtaInputRow]
}
