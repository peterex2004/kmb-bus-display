import Foundation
import BoardCore

public struct CTBProvider: TransitProvider {
    public let operatorCode: TransitOperator = .ctb
    private let transport: any TransitTransport

    public init(transport: any TransitTransport) {
        self.transport = transport
    }

    public func route(
        _ route: String,
        direction: String?,
        serviceType: String?
    ) throws -> TransitRoute {
        let dto: CTBRouteDTO = try get(path: "route/ctb/\(route)")
        return TransitRoute(
            operatorCode: .ctb,
            route: dto.route,
            bound: nil,
            serviceType: nil,
            originTc: dto.originTc,
            originEn: dto.originEn,
            destinationTc: dto.destinationTc,
            destinationEn: dto.destinationEn
        )
    }

    public func routeStops(
        _ route: String,
        direction: String,
        serviceType: String?
    ) throws -> [TransitRouteStop] {
        let dtos: [CTBRouteStopDTO] = try get(
            path: "route-stop/ctb/\(route)/\(direction)"
        )
        return dtos.map {
            TransitRouteStop(
                operatorCode: .ctb,
                route: $0.route,
                direction: $0.direction,
                bound: nil,
                serviceType: nil,
                sequence: $0.sequence,
                stopId: $0.stopId
            )
        }
    }

    public func stop(_ stopId: String) throws -> TransitStop {
        let dto: CTBStopDTO = try get(path: "stop/\(stopId)")
        return TransitStop(
            operatorCode: .ctb,
            stopId: dto.stopId,
            nameTc: dto.nameTc,
            nameEn: dto.nameEn,
            latitude: dto.latitude,
            longitude: dto.longitude
        )
    }

    public func eta(
        stopId: String,
        route: String,
        serviceType: String?
    ) throws -> [TransitEtaRow] {
        let dtos: [CTBEtaDTO] = try get(path: "eta/ctb/\(stopId)/\(route)")
        return dtos.map {
            TransitEtaRow(
                operatorCode: .ctb,
                route: $0.route,
                direction: $0.direction,
                stopId: $0.stopId,
                serviceType: nil,
                sequence: $0.sequence,
                destinationTc: $0.destinationTc,
                destinationEn: $0.destinationEn,
                etaSequence: $0.etaSequence,
                eta: $0.eta
            )
        }
    }

    private func get<Value: Decodable>(path: String) throws -> Value {
        guard let url = URL(string: "https://rt.data.gov.hk/v1/transport/citybus-nwfb/\(path)") else {
            throw TransitProviderError.invalidURL(path)
        }
        let data = try transport.data(for: url)
        do {
            return try JSONDecoder().decode(APIResponse<Value>.self, from: data).data
        } catch {
            throw TransitProviderError.malformedResponse("CTB \(path): \(error)")
        }
    }
}
