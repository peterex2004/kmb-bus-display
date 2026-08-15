import Foundation
import BoardCore

public struct KMBProvider: TransitProvider {
    public let operatorCode: TransitOperator = .kmb
    private let transport: any TransitTransport

    public init(transport: any TransitTransport) {
        self.transport = transport
    }

    public func route(
        _ route: String,
        direction: String?,
        serviceType: String?
    ) throws -> TransitRoute {
        let direction = try required(direction, named: "direction")
        let serviceType = try required(serviceType, named: "serviceType")
        let dto: KMBRouteDTO = try get(
            path: "route/\(route)/\(direction)/\(serviceType)"
        )
        return TransitRoute(
            operatorCode: .kmb,
            route: dto.route,
            bound: dto.bound,
            serviceType: dto.serviceType,
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
        let serviceType = try required(serviceType, named: "serviceType")
        let dtos: [KMBRouteStopDTO] = try get(
            path: "route-stop/\(route)/\(direction)/\(serviceType)"
        )
        return dtos.map {
            TransitRouteStop(
                operatorCode: .kmb,
                route: $0.route,
                direction: nil,
                bound: $0.bound,
                serviceType: $0.serviceType,
                sequence: $0.sequence,
                stopId: $0.stopId
            )
        }
    }

    /// KMB exposes stop details as a bulk `/stop` response; select the
    /// requested detail after decoding that response.
    public func stop(_ stopId: String) throws -> TransitStop {
        let dtos: [KMBStopDTO] = try get(path: "stop")
        guard let dto = dtos.first(where: { $0.stopId == stopId }) else {
            throw TransitProviderError.stopNotFound(stopId)
        }
        return TransitStop(
            operatorCode: .kmb,
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
        let serviceType = try required(serviceType, named: "serviceType")
        let dtos: [KMBEtaDTO] = try get(
            path: "eta/\(stopId)/\(route)/\(serviceType)"
        )
        return dtos.map(makeEtaRow)
    }

    /// KMB's nearby-stop endpoint has a different response shape but the same
    /// ETA row fields. It is kept as a provider-specific convenience because
    /// CTB has no corresponding endpoint.
    public func stopEtas(stopId: String) throws -> [TransitEtaRow] {
        let dtos: [KMBEtaDTO] = try get(path: "stop-eta/\(stopId)")
        return dtos.map(makeEtaRow)
    }

    private func makeEtaRow(_ dto: KMBEtaDTO) -> TransitEtaRow {
        TransitEtaRow(
            operatorCode: .kmb,
            route: dto.route,
            direction: dto.direction,
            stopId: dto.stopId,
            serviceType: dto.serviceType,
            sequence: dto.sequence,
            destinationTc: dto.destinationTc,
            destinationEn: dto.destinationEn,
            etaSequence: dto.etaSequence,
            eta: dto.eta
        )
    }

    private func get<Value: Decodable>(path: String) throws -> Value {
        let url = try makeURL(path: path)
        let data = try transport.data(for: url)
        do {
            return try JSONDecoder().decode(APIResponse<Value>.self, from: data).data
        } catch {
            throw TransitProviderError.malformedResponse("KMB \(path): \(error)")
        }
    }

    private func makeURL(path: String) throws -> URL {
        guard let url = URL(string: "https://data.etabus.gov.hk/v1/transport/kmb/\(path)") else {
            throw TransitProviderError.invalidURL(path)
        }
        return url
    }

    private func required(_ value: String?, named name: String) throws -> String {
        guard let value, !value.isEmpty else {
            throw TransitProviderError.missingParameter(name)
        }
        return value
    }
}
