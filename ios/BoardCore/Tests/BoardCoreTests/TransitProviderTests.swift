import Foundation
import XCTest
@testable import BoardCore
@testable import TransitData

final class TransitProviderTests: XCTestCase {
    func testKMBRecordedFixturesDecodeAndPreserveKnownTypes() throws {
        let transport = try FixtureTransport(filePath: #filePath)
        let provider = KMBProvider(transport: transport)

        let route = try provider.route("1A", direction: "outbound", serviceType: "1")
        XCTAssertEqual(route.route, "1A")
        XCTAssertEqual(route.bound, "O")
        XCTAssertEqual(route.serviceType, "1")

        let routeStops = try provider.routeStops("1A", direction: "outbound", serviceType: "1")
        XCTAssertEqual(routeStops.count, 34)
        XCTAssertEqual(routeStops.first?.sequence, 1)
        XCTAssertEqual(routeStops.first?.serviceType, "1")

        let etaRows = try provider.eta(
            stopId: "A8CE52F4450FE939",
            route: "1A",
            serviceType: "1"
        )
        XCTAssertEqual(etaRows.count, 3)
        XCTAssertEqual(Set(etaRows.compactMap(\.serviceType)), ["1"])
        XCTAssertTrue(etaRows.allSatisfy { $0.eta != nil })

        let stopEtaRows = try provider.stopEtas(stopId: "A8CE52F4450FE939")
        XCTAssertEqual(stopEtaRows.count, 15)
        XCTAssertEqual(stopEtaRows.last?.route, "N293")
        XCTAssertNil(stopEtaRows.last?.eta)
        XCTAssertEqual(Set(stopEtaRows.compactMap(\.serviceType)), ["1", "2", "5"])

        XCTAssertEqual(
            transport.requestedURLs,
            [
                "https://data.etabus.gov.hk/v1/transport/kmb/route/1A/outbound/1",
                "https://data.etabus.gov.hk/v1/transport/kmb/route-stop/1A/outbound/1",
                "https://data.etabus.gov.hk/v1/transport/kmb/eta/A8CE52F4450FE939/1A/1",
                "https://data.etabus.gov.hk/v1/transport/kmb/stop-eta/A8CE52F4450FE939"
            ]
        )
    }

    func testCTBRecordedFixturesDecodeAndPreserveStringCoordinates() throws {
        let transport = try FixtureTransport(filePath: #filePath)
        let provider = CTBProvider(transport: transport)

        let route = try provider.route("1", direction: nil, serviceType: nil)
        XCTAssertEqual(route.route, "1")
        XCTAssertEqual(route.originEn, "Central (Macao Ferry)")
        XCTAssertEqual(route.destinationEn, "Happy Valley (Upper)")

        let routeStops = try provider.routeStops("1", direction: "outbound", serviceType: nil)
        XCTAssertEqual(routeStops.count, 20)
        XCTAssertEqual(routeStops.first?.sequence, 1)
        XCTAssertEqual(routeStops.first?.direction, "O")

        let stop = try provider.stop("001049")
        XCTAssertEqual(stop.stopId, "001049")
        XCTAssertEqual(stop.latitude, 22.282866402091)
        XCTAssertEqual(stop.longitude, 114.15717776053)

        let etaRows = try provider.eta(stopId: "001049", route: "1", serviceType: nil)
        XCTAssertEqual(etaRows.count, 3)
        XCTAssertTrue(etaRows.allSatisfy { $0.eta != nil })

        XCTAssertEqual(
            transport.requestedURLs,
            [
                "https://rt.data.gov.hk/v1/transport/citybus-nwfb/route/ctb/1",
                "https://rt.data.gov.hk/v1/transport/citybus-nwfb/route-stop/ctb/1/outbound",
                "https://rt.data.gov.hk/v1/transport/citybus-nwfb/stop/001049",
                "https://rt.data.gov.hk/v1/transport/citybus-nwfb/eta/ctb/001049/1"
            ]
        )
    }

    func testRecordedKMBETAFlowsThroughEtaParser() throws {
        let transport = try FixtureTransport(filePath: #filePath)
        let provider = KMBProvider(transport: transport)
        let rows = try provider.eta(
            stopId: "A8CE52F4450FE939",
            route: "1A",
            serviceType: "1"
        )

        let parsed = EtaParser.parse(
            rows: rows.map(\.parserInput),
            dirCode: "O",
            now: 1786758600000
        )
        XCTAssertEqual(
            parsed,
            [
                EtaRow(etaMs: 1786758681000),
                EtaRow(etaMs: 1786759016000),
                EtaRow(etaMs: 1786759492000)
            ]
        )
    }

    func testURLConstructionForKMBStopDetailUsesWebBulkEndpoint() throws {
        let payload = Data(#"{"data":[{"stop":"S","name_tc":"站","name_en":"Stop","lat":"22.1","long":"114.1"}]}"#.utf8)
        let transport = RecordingTransport(data: payload)
        let provider = KMBProvider(transport: transport)

        XCTAssertEqual(try provider.stop("S").stopId, "S")
        XCTAssertEqual(
            transport.requestedURLs,
            ["https://data.etabus.gov.hk/v1/transport/kmb/stop"]
        )
    }
}

private final class FixtureTransport: TransitTransport {
    private let fixtureDirectory: URL
    private let fixtureByURL: [String: String]
    private(set) var requestedURLs: [String] = []

    init(filePath: String) throws {
        var directory = URL(fileURLWithPath: filePath).deletingLastPathComponent()
        let fileManager = FileManager.default
        while directory.path != "/" {
            let candidate = directory.appendingPathComponent("shared/fixtures/api")
            if fileManager.fileExists(atPath: candidate.path) {
                fixtureDirectory = candidate
                fixtureByURL = [
                    "https://data.etabus.gov.hk/v1/transport/kmb/route/1A/outbound/1": "kmb-route-1A-outbound-1.json",
                    "https://data.etabus.gov.hk/v1/transport/kmb/route-stop/1A/outbound/1": "kmb-route-stop-1A-outbound-1.json",
                    "https://data.etabus.gov.hk/v1/transport/kmb/eta/A8CE52F4450FE939/1A/1": "kmb-eta-1A.json",
                    "https://data.etabus.gov.hk/v1/transport/kmb/stop-eta/A8CE52F4450FE939": "kmb-stop-eta.json",
                    "https://rt.data.gov.hk/v1/transport/citybus-nwfb/route/ctb/1": "ctb-route-1.json",
                    "https://rt.data.gov.hk/v1/transport/citybus-nwfb/route-stop/ctb/1/outbound": "ctb-route-stop-1-outbound.json",
                    "https://rt.data.gov.hk/v1/transport/citybus-nwfb/stop/001049": "ctb-stop.json",
                    "https://rt.data.gov.hk/v1/transport/citybus-nwfb/eta/ctb/001049/1": "ctb-eta-1.json"
                ]
                return
            }
            directory.deleteLastPathComponent()
        }
        throw NSError(domain: "FixtureTransport", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "could not find shared/fixtures/api above \(filePath)"
        ])
    }

    func data(for url: URL) throws -> Data {
        let key = url.absoluteString
        requestedURLs.append(key)
        guard let fixtureName = fixtureByURL[key] else {
            throw NSError(domain: "FixtureTransport", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "unexpected URL: \(key)"
            ])
        }
        return try Data(contentsOf: fixtureDirectory.appendingPathComponent(fixtureName))
    }
}

private final class RecordingTransport: TransitTransport {
    private let payload: Data
    private(set) var requestedURLs: [String] = []

    init(data: Data) {
        self.payload = data
    }

    func data(for url: URL) throws -> Data {
        requestedURLs.append(url.absoluteString)
        return payload
    }
}
