import Foundation

enum TimelapseSelection {
    static func mostRecentDailyItems<Item>(
        from items: [Item],
        limit: Int,
        calendar: Calendar = .current,
        date: (Item) -> Date?
    ) -> [Item] {
        guard limit > 0 else {
            return []
        }

        let datedItems = items.compactMap { item -> (item: Item, date: Date)? in
            guard let itemDate = date(item) else {
                return nil
            }
            return (item, itemDate)
        }
        .sorted { $0.date > $1.date }

        var selectedDays = Set<Date>()
        var selectedItems: [(item: Item, date: Date)] = []

        for datedItem in datedItems {
            let day = calendar.startOfDay(for: datedItem.date)
            guard selectedDays.insert(day).inserted else {
                continue
            }

            selectedItems.append(datedItem)
            if selectedItems.count == limit {
                break
            }
        }

        return selectedItems.reversed().map(\.item)
    }
}
