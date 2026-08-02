import Foundation

public enum TimelapseSelection {
    /// Selects only dated items, ordered by creation date and then stable ID.
    public static func datedItemsChronologically<Item>(
        from items: [Item],
        date: (Item) -> Date?,
        identifier: (Item) -> String
    ) -> [Item] {
        items.compactMap { item -> (item: Item, date: Date, identifier: String)? in
            guard let creationDate = date(item) else { return nil }
            return (item, creationDate, identifier(item))
        }
        .sorted { lhs, rhs in
            if lhs.date != rhs.date { return lhs.date < rhs.date }
            return lhs.identifier < rhs.identifier
        }
        .map(\.item)
    }

    /// Compatibility overload for callers that do not yet expose a stable ID.
    public static func allItemsChronologically<Item>(
        from items: [Item],
        date: (Item) -> Date?
    ) -> [Item] {
        datedItemsChronologically(
            from: items.enumerated().map { ($0.offset, $0.element) },
            date: { date($0.1) },
            identifier: { String(format: "%020d", $0.0) }
        ).map(\.1)
    }
}
