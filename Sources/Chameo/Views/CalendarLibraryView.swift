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
    @FocusState private var focusedDay: Date?

    private var calendar: Calendar {
        var calendar = Calendar.current
        calendar.locale = L10n.currentLocalization.displayLocale
        calendar.firstWeekday = 2
        return calendar
    }

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
        focusedDay ?? selectedDay ?? calendar.startOfDay(for: Date())
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
        VStack(spacing: ChameoLayout.compactSpacing) {
            calendarHeader
            weekdayHeader
                .padding(.top, 12)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 7),
                spacing: 3
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
                        isFocused: calendar.isDate(date, inSameDayAs: focusedDay ?? .distantPast),
                        focusedDay: $focusedDay,
                        onSelect: {
                            select(date)
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
            .frame(height: 96)
            .padding(.top, ChameoLayout.compactSpacing)
        }
        .padding(ChameoLayout.sectionSpacing)
        .background(
            Color(nsColor: .controlBackgroundColor),
            in: RoundedRectangle(cornerRadius: ChameoLayout.cornerRadius)
        )
        .overlay {
            RoundedRectangle(cornerRadius: ChameoLayout.cornerRadius)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        }
        .padding(.horizontal, ChameoLayout.outerInset)
        .padding(.bottom, ChameoLayout.sectionSpacing)
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
        HStack(spacing: ChameoLayout.compactSpacing) {
            HStack(spacing: 0) {
                Button {
                    changeMonth(by: -1)
                } label: {
                    Label(L10n.string("Previous Month"), systemImage: "chevron.left")
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .frame(
                    width: ChameoLayout.compactControlSize,
                    height: ChameoLayout.compactControlSize
                )
                .contentShape(Rectangle())
                .help(L10n.string("Previous Month"))

                Button {
                    changeMonth(by: 1)
                } label: {
                    Label(L10n.string("Next Month"), systemImage: "chevron.right")
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .frame(
                    width: ChameoLayout.compactControlSize,
                    height: ChameoLayout.compactControlSize
                )
                .contentShape(Rectangle())
                .help(L10n.string("Next Month"))
            }

            HStack(spacing: ChameoLayout.compactSpacing) {
                Text(DateFormatters.monthAndYear.string(from: displayedMonth))
                    .font(.headline)

                if isRefreshing {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel(L10n.string("Refreshing Library"))
                }
            }
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(L10n.string("Today")) {
                select(Date())
            }
            .buttonStyle(.bordered)

            Button(action: onExportTimelapse) {
                if isExportingTimelapse {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel(L10n.string("Creating timelapse"))
                } else {
                    Label(L10n.string("Timelapse"), systemImage: "film")
                }
            }
            .buttonStyle(.bordered)
            .disabled(isExportingTimelapse || assets.isEmpty)
            .help(L10n.string("Create Timelapse"))
        }
    }

    private var weekdayHeader: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7),
            spacing: 0
        ) {
            ForEach(weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.caption)
                    .bold()
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.shortStandaloneWeekdaySymbols
        guard symbols.count == 7 else { return symbols }
        return Array(symbols[1...]) + [symbols[0]]
    }

    private func select(_ date: Date) {
        let day = calendar.startOfDay(for: date)
        selectedDay = day
        displayedMonth = day
    }

    private func changeMonth(by value: Int) {
        guard
            let newMonth = calendar.date(
                byAdding: .month,
                value: value,
                to: displayedMonth
            )
        else {
            return
        }

        displayedMonth = newMonth
        if let firstDay = calendar.dateInterval(of: .month, for: newMonth)?.start,
            firstDay <= calendar.startOfDay(for: Date())
        {
            selectedDay = firstDay
        }
    }
}

private struct CalendarDayCell: View {
    let date: Date
    let status: DailyCaptureStatus
    let isInDisplayedMonth: Bool
    let isSelected: Bool
    let isFocused: Bool
    let focusedDay: FocusState<Date?>.Binding
    let onSelect: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            ZStack {
                Circle()
                    .fill(backgroundColor)
                    .frame(width: 29, height: 29)

                Circle()
                    .stroke(isFocused ? Color.accentColor : Color.clear, lineWidth: 1)
                    .frame(width: 29, height: 29)

                VStack(spacing: 1) {
                    Text(date.formatted(.dateTime.day()))
                        .font(.caption)
                        .fontWeight(Calendar.current.isDateInToday(date) ? .semibold : .regular)

                    CalendarStatusDot(status: status)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 29)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(status == .future)
        .focused(focusedDay, equals: date)
        .onHover { isHovering in
            isHovered = isHovering
        }
        .opacity(isInDisplayedMonth ? 1 : 0.35)
        .help(status.accessibilityDescription)
        .accessibilityLabel(DateFormatters.completeDate.string(from: date))
        .accessibilityValue(status.accessibilityDescription)
    }

    private var backgroundColor: Color {
        if isSelected {
            return Color.accentColor.opacity(0.16)
        }
        if isHovered {
            return Color.secondary.opacity(0.08)
        }
        return .clear
    }
}

private struct CalendarStatusDot: View {
    let status: DailyCaptureStatus

    var body: some View {
        Circle()
            .fill(fillColor)
            .overlay {
                Circle()
                    .stroke(strokeColor, lineWidth: status == .missed ? 1 : 0)
            }
            .frame(width: 6, height: 6)
            .accessibilityHidden(true)
    }

    private var fillColor: Color {
        switch status {
        case .captured:
            return .green
        case .pendingToday:
            return .orange
        case .missed, .future, .outsideTracking, .unknown:
            return .clear
        }
    }

    private var strokeColor: Color {
        switch status {
        case .missed:
            return Color(nsColor: .secondaryLabelColor)
        case .captured, .pendingToday, .future, .outsideTracking, .unknown:
            return .clear
        }
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
        Group {
            if let selectedAsset {
                populatedPreview(selectedAsset)
            } else {
                emptyPreview
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

    private func populatedPreview(_ selectedAsset: ChameoAsset) -> some View {
        HStack(alignment: .top, spacing: 12) {
            CalendarAssetImage(asset: selectedAsset, size: 96)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(DateFormatters.longDate.string(from: date))
                        .font(.callout)
                        .fontWeight(.semibold)
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    Text(
                        selectedAsset.createdAt.map(DateFormatters.shortTime.string(from:))
                            ?? L10n.string("Unknown time"))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    deleteControls
                }
                .frame(height: ChameoLayout.compactControlSize)

                locationRow(for: selectedAsset)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if assets.count > 1 {
                    Spacer(minLength: 0)
                    assetStrip
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private func locationRow(for asset: ChameoAsset) -> some View {
        let content = HStack(spacing: 5) {
            if isLoadingLocationName {
                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.65)
                    .frame(width: 12, height: 12)
            } else {
                Image(systemName: "location")
                    .accessibilityHidden(true)
            }

            Text(locationText)
                .lineLimit(1)
                .truncationMode(.middle)
        }

        if let location = asset.asset.location,
            let url = GoogleMapsLink.url(for: location)
        {
            Link(destination: url) {
                content
            }
            .buttonStyle(.plain)
            .help(L10n.string("Open in Google Maps"))
            .accessibilityLabel(L10n.string("Open in Google Maps"))
        } else {
            content
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
                Text(DateFormatters.longDate.string(from: date))
                    .font(.callout)
                    .fontWeight(.medium)

                Text(status.accessibilityDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if status == .pendingToday {
                Button(L10n.string("Take Chameo"), action: onTakeChameo)
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    private var assetStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(assets) { asset in
                    CalendarAssetThumbnail(
                        asset: asset,
                        isSelected: selectedAsset?.id == asset.id,
                        size: 22
                    ) {
                        selectedAssetID = asset.id
                        isConfirmingDeletion = false
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 24)
    }

    @ViewBuilder
    private var deleteControls: some View {
        if isConfirmingDeletion {
            HStack(spacing: 6) {
                Button(L10n.string("Delete"), role: .destructive) {
                    guard let selectedAsset else { return }
                    isConfirmingDeletion = false
                    Task {
                        await onDelete(selectedAsset)
                    }
                }
                .buttonStyle(.borderless)

                Button(L10n.string("Cancel")) {
                    isConfirmingDeletion = false
                }
                .buttonStyle(.borderless)
            }
            .font(.caption)
        } else {
            Button {
                isConfirmingDeletion = true
            } label: {
                Label(L10n.string("Delete Photo"), systemImage: "trash")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .frame(
                width: ChameoLayout.compactControlSize,
                height: ChameoLayout.compactControlSize
            )
            .contentShape(Rectangle())
            .help(L10n.string("Delete Photo"))
        }
    }

    private var locationText: String {
        if isLoadingLocationName {
            return L10n.string("Loading location…")
        }
        if !locationName.isEmpty {
            return locationName
        }
        if assets.count > 1 {
            return L10n.format("%lld Chameos", Int64(assets.count))
        }
        return L10n.string("No location")
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

private struct CalendarAssetImage: View {
    let asset: ChameoAsset
    let size: CGFloat

    @State private var thumbnail: NSImage?

    var body: some View {
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
        .frame(width: size, height: size)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .task(id: asset.id) {
            thumbnail = await PhotoLibraryService.thumbnail(
                for: asset.asset,
                size: CGSize(width: size * 2, height: size * 2)
            )
        }
    }
}

private struct CalendarAssetThumbnail: View {
    let asset: ChameoAsset
    let isSelected: Bool
    let size: CGFloat
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            CalendarAssetImage(asset: asset, size: size)
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            asset.createdAt.map(DateFormatters.libraryDate.string(from:)) ?? "Chameo")
    }
}
