import Foundation

/// Comparison functions used by the automatic and manual board sort modes.
public enum BoardComparator {
    public static func auto(_ lhs: BoardItem, _ rhs: BoardItem) -> ComparisonResult {
        switch (lhs.nearestEta, rhs.nearestEta) {
        case (nil, .some):
            return .orderedDescending
        case (.some, nil):
            return .orderedAscending
        case let (.some(left), .some(right)) where left != right:
            return left < right ? .orderedAscending : .orderedDescending
        default:
            break
        }

        if let left = lhs.boardOrder, let right = rhs.boardOrder, left != right {
            return left < right ? .orderedAscending : .orderedDescending
        }

        // Automatic mode intentionally lets a missing boardOrder fall through
        // to the same deterministic key as the web implementation.
        return compareKey(for: lhs, and: rhs)
    }

    public static func manual(_ lhs: BoardItem, _ rhs: BoardItem) -> ComparisonResult {
        switch (lhs.boardOrder, rhs.boardOrder) {
        case (nil, .some):
            return .orderedDescending
        case (.some, nil):
            return .orderedAscending
        case let (.some(left), .some(right)) where left != right:
            return left < right ? .orderedAscending : .orderedDescending
        default:
            break
        }

        return compareKey(for: lhs, and: rhs)
    }

    private static func compareKey(for lhs: BoardItem, and rhs: BoardItem) -> ComparisonResult {
        let left = "\(lhs.company.nilOrEmpty(default: "KMB")):\(lhs.route ?? ""):\(lhs.stopId ?? ""):\(lhs.dir ?? "")"
        let right = "\(rhs.company.nilOrEmpty(default: "KMB")):\(rhs.route ?? ""):\(rhs.stopId ?? ""):\(rhs.dir ?? "")"

        // This is the Swift equivalent of localeCompare(..., { numeric: true }).
        return left.compare(right, options: [.numeric])
    }
}

private extension Optional where Wrapped == String {
    func nilOrEmpty(default fallback: String) -> String {
        switch self {
        case .some(let value) where !value.isEmpty:
            return value
        default:
            return fallback
        }
    }
}
