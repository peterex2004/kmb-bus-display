import Foundation

struct APIResponse<Value: Decodable>: Decodable {
    let data: Value
}

struct KMBRouteDTO: Decodable {
    let route: String
    let bound: String
    let serviceType: String
    let originTc: String?
    let originEn: String?
    let destinationTc: String?
    let destinationEn: String?

    enum CodingKeys: String, CodingKey {
        case route, bound
        case serviceType = "service_type"
        case originTc = "orig_tc"
        case originEn = "orig_en"
        case destinationTc = "dest_tc"
        case destinationEn = "dest_en"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        route = try container.decode(String.self, forKey: .route)
        bound = try container.decode(String.self, forKey: .bound)
        serviceType = try container.decodeLenientString(forKey: .serviceType) ?? "1"
        originTc = try container.decodeIfPresent(String.self, forKey: .originTc)
        originEn = try container.decodeIfPresent(String.self, forKey: .originEn)
        destinationTc = try container.decodeIfPresent(String.self, forKey: .destinationTc)
        destinationEn = try container.decodeIfPresent(String.self, forKey: .destinationEn)
    }
}

struct KMBRouteStopDTO: Decodable {
    let route: String
    let bound: String
    let serviceType: String
    let sequence: Int
    let stopId: String

    enum CodingKeys: String, CodingKey {
        case route, bound, seq, stop
        case serviceType = "service_type"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        route = try container.decode(String.self, forKey: .route)
        bound = try container.decode(String.self, forKey: .bound)
        serviceType = try container.decodeLenientString(forKey: .serviceType) ?? "1"
        sequence = try container.decodeLenientInt(forKey: .seq) ?? 0
        stopId = try container.decode(String.self, forKey: .stop)
    }
}

struct KMBStopDTO: Decodable {
    let stopId: String
    let nameTc: String?
    let nameEn: String?
    let latitude: Double?
    let longitude: Double?

    enum CodingKeys: String, CodingKey {
        case stop, nameTc = "name_tc", nameEn = "name_en", lat, long
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        stopId = try container.decode(String.self, forKey: .stop)
        nameTc = try container.decodeIfPresent(String.self, forKey: .nameTc)
        nameEn = try container.decodeIfPresent(String.self, forKey: .nameEn)
        latitude = try container.decodeLenientDouble(forKey: .lat)
        longitude = try container.decodeLenientDouble(forKey: .long)
    }
}

struct KMBEtaDTO: Decodable {
    let route: String?
    let direction: String
    let stopId: String?
    let serviceType: String?
    let sequence: Int?
    let destinationTc: String?
    let destinationEn: String?
    let etaSequence: Int?
    let eta: String?

    enum CodingKeys: String, CodingKey {
        case route, dir, stop, seq
        case serviceType = "service_type"
        case destinationTc = "dest_tc"
        case destinationEn = "dest_en"
        case etaSequence = "eta_seq"
        case eta
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        route = try container.decodeIfPresent(String.self, forKey: .route)
        direction = try container.decode(String.self, forKey: .dir)
        stopId = try container.decodeIfPresent(String.self, forKey: .stop)
        serviceType = try container.decodeLenientString(forKey: .serviceType)
        sequence = try container.decodeLenientInt(forKey: .seq)
        destinationTc = try container.decodeIfPresent(String.self, forKey: .destinationTc)
        destinationEn = try container.decodeIfPresent(String.self, forKey: .destinationEn)
        etaSequence = try container.decodeLenientInt(forKey: .etaSequence)
        eta = try container.decodeIfPresent(String.self, forKey: .eta)
    }
}

struct CTBRouteDTO: Decodable {
    let route: String
    let originTc: String?
    let originEn: String?
    let destinationTc: String?
    let destinationEn: String?

    enum CodingKeys: String, CodingKey {
        case route
        case originTc = "orig_tc"
        case originEn = "orig_en"
        case destinationTc = "dest_tc"
        case destinationEn = "dest_en"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        route = try container.decode(String.self, forKey: .route)
        originTc = try container.decodeIfPresent(String.self, forKey: .originTc)
        originEn = try container.decodeIfPresent(String.self, forKey: .originEn)
        destinationTc = try container.decodeIfPresent(String.self, forKey: .destinationTc)
        destinationEn = try container.decodeIfPresent(String.self, forKey: .destinationEn)
    }
}

struct CTBRouteStopDTO: Decodable {
    let route: String
    let direction: String
    let sequence: Int
    let stopId: String

    enum CodingKeys: String, CodingKey { case route, dir, seq, stop }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        route = try container.decode(String.self, forKey: .route)
        direction = try container.decode(String.self, forKey: .dir)
        sequence = try container.decodeLenientInt(forKey: .seq) ?? 0
        stopId = try container.decode(String.self, forKey: .stop)
    }
}

struct CTBStopDTO: Decodable {
    let stopId: String
    let nameTc: String?
    let nameEn: String?
    let latitude: Double?
    let longitude: Double?

    enum CodingKeys: String, CodingKey {
        case stop, nameTc = "name_tc", nameEn = "name_en", lat, long
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        stopId = try container.decode(String.self, forKey: .stop)
        nameTc = try container.decodeIfPresent(String.self, forKey: .nameTc)
        nameEn = try container.decodeIfPresent(String.self, forKey: .nameEn)
        latitude = try container.decodeLenientDouble(forKey: .lat)
        longitude = try container.decodeLenientDouble(forKey: .long)
    }
}

struct CTBEtaDTO: Decodable {
    let route: String?
    let direction: String
    let stopId: String?
    let sequence: Int?
    let destinationTc: String?
    let destinationEn: String?
    let etaSequence: Int?
    let eta: String?

    enum CodingKeys: String, CodingKey {
        case route, dir, stop, seq
        case destinationTc = "dest_tc"
        case destinationEn = "dest_en"
        case etaSequence = "eta_seq"
        case eta
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        route = try container.decodeIfPresent(String.self, forKey: .route)
        direction = try container.decode(String.self, forKey: .dir)
        stopId = try container.decodeIfPresent(String.self, forKey: .stop)
        sequence = try container.decodeLenientInt(forKey: .seq)
        destinationTc = try container.decodeIfPresent(String.self, forKey: .destinationTc)
        destinationEn = try container.decodeIfPresent(String.self, forKey: .destinationEn)
        etaSequence = try container.decodeLenientInt(forKey: .etaSequence)
        eta = try container.decodeIfPresent(String.self, forKey: .eta)
    }
}

private extension KeyedDecodingContainer {
    func decodeLenientString(forKey key: Key) throws -> String? {
        guard contains(key), try !decodeNil(forKey: key) else { return nil }
        if let value = try? decode(String.self, forKey: key) { return value }
        if let value = try? decode(Int.self, forKey: key) { return String(value) }
        if let value = try? decode(Double.self, forKey: key) { return String(value) }
        throw DecodingError.typeMismatch(
            String.self,
            DecodingError.Context(codingPath: codingPath + [key], debugDescription: "expected string or number")
        )
    }

    func decodeLenientInt(forKey key: Key) throws -> Int? {
        guard contains(key), try !decodeNil(forKey: key) else { return nil }
        if let value = try? decode(Int.self, forKey: key) { return value }
        if let value = try? decode(String.self, forKey: key), let int = Int(value) { return int }
        if let value = try? decode(Double.self, forKey: key), value.rounded() == value { return Int(value) }
        throw DecodingError.typeMismatch(
            Int.self,
            DecodingError.Context(codingPath: codingPath + [key], debugDescription: "expected integer or numeric string")
        )
    }

    func decodeLenientDouble(forKey key: Key) throws -> Double? {
        guard contains(key), try !decodeNil(forKey: key) else { return nil }
        if let value = try? decode(Double.self, forKey: key) { return value }
        if let value = try? decode(String.self, forKey: key), let double = Double(value) { return double }
        throw DecodingError.typeMismatch(
            Double.self,
            DecodingError.Context(codingPath: codingPath + [key], debugDescription: "expected number or numeric string")
        )
    }
}
