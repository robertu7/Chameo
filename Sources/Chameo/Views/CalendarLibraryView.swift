import AppKit
import SwiftUI

struct CalendarLibraryView: View {
    let assets: [ChameoAsset]
    @Binding var selectedDay: Date?
    let isRefreshing: Bool
    let isExportingTimelapse: Bool
    let onTakeChameo: () -> Void
    let onExportTimelapse: () -> Void
    let onDelete: (ChameoAsset) async -> Void

    @State private var displayedMonth = Calendar.current.startOfDay(for: Date())
    @State private var hoveredDay: Date?
    @FocusState private var focusedDay: Date?

    private let calendar = Calendar.current

    private var captureDates: [Date] {
        assets.compactMap(\.createdAt)
    }

    private var dates: [Date] {
        DailyCaptureHistory.calendarDates(
            inMonthContaining: displayedMonth,
            calendar: calendar
        )
    }

    private var previewDay: Date {
        hoveredDay ?? focusedDay ?? selectedDay ?? calendar.startOfDay(for: Date())
    }

    private var assetsByDay: [Date: [ChameoAsset]] {
        Dictionary(grouping: assets) { asset in
            calendar.startOfDay(for: asset.createdAt ?? .distantPast)
        }
        .mapValues {
            $0.sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            calendarHeader
            weekdayHeader

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7),
                spacing: 4
            ) {
                ForEach(dates, id: \.self) { date in
                    let status = DailyCaptureHistory.status(
                        for: date,
                        captureDates: captureDates,
                        calendar: calendar
                    )

                    CalendarDayCell(
                        date: date,
                        status: status,
                        isInDisplayedMonth: DailyCaptureHistory.isDate(
                            date,
                            inSameMonthAs: displayedMonth,
                            calendar: calendar
                        ),
                        isSelected: calendar.isDate(date, inSameDayAs: selectedDay ?? .distantPast),
                        focusedDay: $focusedDay,
                        onSelect: {
                            select(date)
                        },
                        onHover: { isHovering in
                            if isHovering {
                                hoveredDay = date
                            } else if hoveredDay.map({ calendar.isDate($0, inSameDayAs: date) }) == true {
                                hoveredDay = nil
                            }
                        }
                    )
                }
            }

            Divider()

            CalendarDayPreview(
                date: previewDay,
                status: DailyCaptureHistory.status(
                    for: previewDay,
                    captureDates: captureDates,
                    calendar: calendar
                ),
                assets: assetsByDay[calendar.startOfDay(for: previewDay)] ?? [],
                onTakeChameo: onTakeChameo,
                onDelete: onDelete
            )
            .frame(maxHeight: .infinity)
        }
        .padding(12)
        .overlay(alignment: .topTrailing) {
            if isRefreshing {
                ProgressView()
                    .controlSize(.small)
                    .padding(.top, 17)
                    .padding(.trailing, 112)
                    .accessibilityLabel("Refreshing Library")
            }
        }
        .task {
            let initialDay = selectedDay ?? calendar.startOfDay(for: Date())
            selectedDay = initialDay
            displayedMonth = initialDay
        }
        .onChange(of: selectedDay) { _, newValue in
            guard let newValue else { return }
            displayedMonth = newValue
        }
    }

    private var calendarHeader: some View {
        HStack(spacing: 6) {
            Button {
                changeMonth(by: -1)
            } label: {
                Label("Previous Month", systemImage: "chevron.left")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .help("Previous Month")

            Button {
                changeMonth(by: 1)
            } label: {
                Label("Next Month", systemImage: "chevron.right")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .help("Next Month")

            Text(displayedMonth.formatted(.dateTime.month(.wide).year()))
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button("Today") {
                select(Date())
            }
            .buttonStyle(.borderless)

            Button(action: onExportTimelapse) {
                if isExportingTimelapse {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel("Creating timelapse")
                } else {
                    Label("Timelapse", systemImage: "film")
                }
            }
            .buttonStyle(.bordered)
            .disabled(isExportingTimelapse || assets.isEmpty)
            .help("Create Timelapse")
        }
    }

    private var weekdayHeader: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7),
            spacing: 0
        ) {
            ForEach(weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var weekdaySymbols: [String] {
        let symbols = DateFormatter().veryShortStandaloneWeekdaySymbols ?? []
        guard symbols.count == 7 else {
            return symbols
        }

        let startIndex = max(0, min(6, calendar.firstWeekday - 1))
        return Array(symbols[startIndex...] + symbols[..<startIndex])
    }

    private func select(_ date: Date) {
        let day = calendar.startOfDay(for: date)
        selectedDay = day
        displayedMonth = day
    }

    private func changeMonth(by value: Int) {
        guard let newMonth = calendar.date(
            byAdding: .month,
            value: value,
            to: displayedMonth
        ) else {
            return
        }

        displayedMonth = newMonth
        selectedDay = calendar.dateInterval(of: .month, for: newMonth)?.start
    }
}

private struct CalendarDayCell: View {
    let date: Date
    let status: DailyCaptureStatus
    let isInDisplayedMonth: Bool
    let isSelected: Bool
    let focusedDay: FocusState<Date?>.Binding
    let onSelect: () -> Void
    let onHover: (Bool) -> Void

    var body: some View {
        Button(action: onSelect) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.16) : Color.clear)

                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(
                        isSelected ? Color.accentColor : borderColor,
                        lineWidth: isSelected ? 1.5 : 1
                    )

                Text(date.formatted(.dateTime.day()))
                    .font(.caption)
                    .fontWeight(Calendar.current.isDateInToday(date) ? .semibold : .regular)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(5)

                statusIndicator
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(5)
            }
            .frame(height: 37)
            .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .focused(focusedDay, equals: date)
        .onHover(perform: onHover)
        .opacity(isInDisplayedMonth ? 1 : 0.35)
        .accessibilityLabel(date.formatted(date: .complete, time: .omitted))
        .accessibilityValue(status.accessibilityDescription)
    }

    @ViewBuilder
    private var statusIndicator: some View {
        switch status {
        case .captured:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .pendingToday:
            Image(systemName: "camera.circle")
                .foregroundStyle(Color.accentColor)
        case .missed:
            Image(systemName: "minus.circle")
                .foregroundStyle(.tertiary)
        case .unknown:
            Image(systemName: "questionmark.circle")
                .foregroundStyle(.secondary)
        case .future, .outsideTracking:
            EmptyView()
        }
    }

    private var borderColor: Color {
        if Calendar.current.isDateInToday(date) {
            return Color.accentColor.opacity(0.65)
        }
        return Color.secondary.opacity(0.18)
    }
}

private struct CalendarDayPreview: View {
    let date: Date
    let status: DailyCaptureStatus
    let assets: [ChameoAsset]
    let onTakeChameo: () -> Void
    let onDelete: (ChameoAsset) async -> Void

    @State private var selectedAssetID: String?
    @State private var locationName = ""
    @State private var isLoadingLocationName = false
    @State private var isConfirmingDeletion = false

    private var selectedAsset: ChameoAsset? {
        assets.first { $0.id == selectedAssetID } ?? assets.first
    }

    var body: some View {
        HStack(spacing: 10) {
            if assets.isEmpty {
                emptyPreview
            } else {
                assetStrip

                VStack(alignment: .leading, spacing: 3) {
                    Text(date.formatted(date: .long, time: .omitted))
                        .font(.callout)
                        .fontWeight(.medium)
                        .lineLimit(1)

                    if let selectedAsset {
                        Text(selectedAsset.createdAt.map(DateFormatters.libraryDate.string(from:)) ?? "Unknown Date")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    HStack(spacing: 5) {
                        if isLoadingLocationName {
                            ProgressView()
                                .controlSize(.small)
                                .scaleEffect(0.65)
                                .frame(width: 12, height: 12)
                        }

                        Text(locationText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                deleteControls
            }
        }
        .task(id: selectedAsset?.id) {
            guard let selectedAsset else {
                locationName = ""
                isLoadingLocationName = false
                return
            }

            selectedAssetID = selectedAsset.id
            isLoadingLocationName = true
            locationName = await LocationNameService.name(for: selectedAsset.asset.location)
            isLoadingLocationName = false
        }
        .onChange(of: assets.map(\.id)) { _, assetIDs in
            if let selectedAssetID, assetIDs.contains(selectedAssetID) {
                return
            }
            self.selectedAssetID = assetIDs.first
            isConfirmingDeletion = false
        }
    }

    private var emptyPreview: some View {
        HStack(spacing: 10) {
            Image(systemName: emptyStateSymbol)
                .font(.title2)
                .foregroundStyle(emptyStateColor)
                .frame(width: 52, height: 52)
                .background(.background, in: RoundedRectangle(cornerRadius: 7, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(date.formatted(date: .long, time: .omitted))
                    .font(.callout)
                    .fontWeight(.medium)

                Text(status.accessibilityDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if status == .pendingToday {
                Button("Take Chameo", action: onTakeChameo)
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    private var assetStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 5) {
                ForEach(assets) { asset in
                    CalendarAssetThumbnail(
                        asset: asset,
                        isSelected: selectedAsset?.id == asset.id
                    ) {
                        selectedAssetID = asset.id
                        isConfirmingDeletion = false
                    }
                }
            }
        }
        .frame(width: assets.count > 1 ? 116 : 54, height: 54)
    }

    @ViewBuilder
    private var deleteControls: some View {
        if isConfirmingDeletion {
            VStack(spacing: 4) {
                Button("Delete", role: .destructive) {
                    guard let selectedAsset else { return }
                    isConfirmingDeletion = false
                    Task {
                        await onDelete(selectedAsset)
                    }
                }
                .buttonStyle(.borderless)

                Button("Cancel") {
                    isConfirmingDeletion = false
                }
                .buttonStyle(.borderless)
            }
            .font(.caption)
        } else {
            Button {
                isConfirmingDeletion = true
            } label: {
                Label("Delete Photo", systemImage: "trash")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .help("Delete Photo")
        }
    }

    private var locationText: String {
        if isLoadingLocationName {
            return "Loading location..."
        }
        if !locationName.isEmpty {
            return locationName
        }
        if assets.count > 1 {
            return "\(assets.count) Chameos"
        }
        return "No location"
    }

    private var emptyStateSymbol: String {
        switch status {
        case .pendingToday:
            return "camera"
        case .missed:
            return "minus.circle"
        case .future:
            return "calendar"
        case .outsideTracking:
            return "calendar.badge.clock"
        case .unknown:
            return "questionmark.circle"
        case .captured:
            return "photo"
        }
    }

    private var emptyStateColor: Color {
        status == .pendingToday ? Color.accentColor : Color.secondary
    }
}

private struct CalendarAssetThumbnail: View {
    let asset: ChameoAsset
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var thumbnail: NSImage?

    var body: some View {
        Button(action: onSelect) {
            Group {
                if let thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(width: 52, height: 52)
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(asset.createdAt.map(DateFormatters.libraryDate.string(from:)) ?? "Chameo")
        .task(id: asset.id) {
            thumbnail = await PhotoLibraryService.thumbnail(
                for: asset.asset,
                size: CGSize(width: 128, height: 128)
            )
        }
    }
}
