/// Reorders cards and rewrites their zero-based manual order.
public func reorder(_ items: [BoardItem], from fromIndex: Int?, to toIndex: Int?) -> [BoardItem] {
    var reordered = items

    if let fromIndex,
       let toIndex,
       fromIndex >= 0,
       fromIndex < reordered.count,
       toIndex >= 0,
       toIndex < reordered.count,
       fromIndex != toIndex {
        let moved = reordered.remove(at: fromIndex)
        reordered.insert(moved, at: toIndex)
    }

    return reordered.enumerated().map { index, item in
        var copy = item
        copy.boardOrder = index
        return copy
    }
}
