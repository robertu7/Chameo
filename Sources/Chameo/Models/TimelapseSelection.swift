import Foundation

enum TimelapseSelection {
    static func allItemsChronologically<Item>(
        from items: [Item],
        date: (Item) -> Date?
    ) -> [Item] {
        items.enumerated().map { index, item in
            (index: index, item: item, date: date(item))
        }
        .sorted { lhs, rhs in
            switch (lhs.date, rhs.date) {
            case let (lhsDate?, rhsDate?) where lhsDate != rhsDate:
                return lhsDate < rhsDate
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            default:
                return lhs.index < rhs.index
            }
        }
        .map(\.item)
    }
}
