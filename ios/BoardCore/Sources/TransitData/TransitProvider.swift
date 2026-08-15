import Foundation
import BoardCore

/// The transport seam used by providers. Production can supply an HTTP
/// adapter; tests supply a fixture-only implementation.
public protocol TransitTransport {
    func data(for url: URL) throws -> Data
}

public struct ClosureTransitTransport: TransitTransport {
    private let handler: (URL) throws -> Data

    public init(handler: @escaping (URL) throws -> Data) {
        self.handler = handler
    }

    public func data(for url: URL) throws -> Data {
        try handler(url)
    }
}

public enum TransitOperator: String, Equatable, Sendable {
    case kmb = "KMB"
    case ctb = "CTB"
}

public struct TransitRoute: Equatable, Sendable {
    public let operatorCode: TransitOperator
    public let route: String
    public let bound: String?
    public let serviceType: String?
    public let originTc: String?
    public let originEn: String?
    public let destinationTc: String?
    public let destinationEn: String?

    public init(
        operatorCode: TransitOperator,
        route: String,
        bound: String?,
        serviceType: String?,
        originTc: String?,
        originEn: String?,
        destinationTc: String?,
        destinationEn: String?
    ) {
        self.operatorCode = operatorCode
        self.route = route
        self.bound = bound
        self.serviceType = serviceType
        self.originTc = originTc
        self.originEn = originEn
        self.destinationTc = destinationTc
        self.destinationEn = destinationEn
    }
}

public struct TransitRouteStop: Equatable, Sendable {
    public let operatorCode: TransitOperator
    public let route: String
    public let direction: String?
    public let bound: String?
    public let serviceType: String?
    public let sequence: Int
    public let stopId: String

    public init(
        operatorCode: TransitOperator,
        route: String,
        direction: String?,
        bound: String?,
        serviceType: String?,
        sequence: Int,
        stopId: String
    ) {
        self.operatorCode = operatorCode
        self.route = route
        self.direction = direction
        self.bound = bound
        self.serviceType = serviceType
        self.sequence = sequence
        self.stopId = stopId
    }
}

public struct TransitStop: Equatable, Sendable {
    public let operatorCode: TransitOperator
    public let stopId: String
    public let nameTc: String?
    public let nameEn: String?
    public let latitude: Double?
    public let longitude: Double?

    public init(
        operatorCode: TransitOperator,
        stopId: String,
        nameTc: String?,
        nameEn: String?,
        latitude: Double?,
        longitude: Double?
    ) {
        self.operatorCode = operatorCode
        self.stopId = stopId
        self.nameTc = nameTc
        self.nameEn = nameEn
        self.latitude = latitude
        self.longitude = longitude
    }
}

/// A decoded ETA row. `eta` stays as the API string so `EtaParser` remains the
/// single owner of date parsing and row-selection semantics.
public struct TransitEtaRow: Equatable, Sendable {
    public let operatorCode: TransitOperator
    public let route: String?
    public let direction: String
    public let stopId: String?
    public let serviceType: String?
    public let sequence: Int?
    public let destinationTc: String?
    public let destinationEn: String?
    public let etaSequence: Int?
    public let eta: String?

    public init(
        operatorCode: TransitOperator,
        route: String?,
        direction: String,
        stopId: String?,
        serviceType: String?,
        sequence: Int?,
        destinationTc: String?,
        destinationEn: String?,
        etaSequence: Int?,
        eta: String?
    ) {
        self.operatorCode = operatorCode
        self.route = route
        self.direction = direction
        self.stopId = stopId
        self.serviceType = serviceType
        self.sequence = sequence
        self.destinationTc = destinationTc
        self.destinationEn = destinationEn
        self.etaSequence = etaSequence
        self.eta = eta
    }

    public var parserInput: EtaInputRow {
        EtaInputRow(dir: direction, eta: eta)
    }
}

public protocol TransitProvider {
    var operatorCode: TransitOperator { get }

    func route(
        _ route: String,
        direction: String?,
        serviceType: String?
    ) throws -> TransitRoute

    func routeStops(
        _ route: String,
        direction: String,
        serviceType: String?
    ) throws -> [TransitRouteStop]

    func stop(_ stopId: String) throws -> TransitStop

    func eta(
        stopId: String,
        route: String,
        serviceType: String?
    ) throws -> [TransitEtaRow]
}

public enum TransitProviderError: Error, Equatable, CustomStringConvertible {
    case invalidURL(String)
    case missingParameter(String)
    case malformedResponse(String)
    case stopNotFound(String)

    public var description: String {
        switch self {
        case .invalidURL(let value): return "invalid URL: \(value)"
        case .missingParameter(let value): return "missing parameter: \(value)"
        case .malformedResponse(let value): return "malformed response: \(value)"
        case .stopNotFound(let value): return "stop not found: \(value)"
        }
    }
}
