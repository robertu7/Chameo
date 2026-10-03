import AppKit
import SwiftUI

struct CalendarLibraryView: View {
    let assets: [ChameoAsset]
    @Binding var selectedDay: Date?
    let isRefreshing: Bool
    let isExportingTimelapse: Bool
    let canSaveLocalCopy: Bool
    let onTakeChameo: () -> Void
    let onExportTimelapse: () -> Void
    let onDelete: (ChameoAsset, Bool) async -> Void
    let onSaveLocalCopy: (ChameoAsset) async -> Void
    var thumbnailLoader: (ChameoAsset, CGFloat) async -> NSImage? = { asset, size in
        await PhotoLibraryService.thumbnail(for: asset.asset, size: CGSize(width: size * 2, height: size * 2))
    }

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
        VStack(spacing: 4) {
            calendarHeader
            weekdayHeader
                .padding(.top, 8)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 7),
                spacing: 2
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
                canSaveLocalCopy: canSaveLocalCopy,
                onTakeChameo: onTakeChameo,
                onDelete: onDelete,
                onSaveLocalCopy: onSaveLocalCopy,
                thumbnailLoader: thumbnailLoader
            )
            .frame(height: 96)
            .padding(.top, 4)
        }
        .padding(ChameoLayout.sectionSpacing)
        .background(
            Color(nsColor: .controlBackgroundColor),
            in: RoundedRectangle(cornerRadius: ChameoLayout.cornerRadius)
        )
        .padding(.horizontal, ChameoLayout.outerInset)
        .padding(.bottom, 4)
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
        VStack(spacing: 12) {
            HStack(spacing: 6) {
                Text(DateFormatters.monthAndYear.string(from: displayedMonth))
                    .font(.headline)
                if isRefreshing {
                    ProgressView().controlSize(.small)
                        .accessibilityLabel(L10n.string("Refreshing Library"))
                }
                Spacer(minLength: 0)
                monthNavigationControl(L10n.string("Previous Month"), symbol: "chevron.left", offset: -1)
                monthNavigationControl(L10n.string("Next Month"), symbol: "chevron.right", offset: 1)
            }
            .frame(height: 24)

            HStack(spacing: 8) {
                Button(L10n.string("Today")) { select(Date()) }
                    .buttonStyle(.glass)
                Button(action: onExportTimelapse) {
                    HStack(spacing: ChameoLayout.compactSpacing) {
                        if isExportingTimelapse {
                            ProgressView().controlSize(.small).accessibilityHidden(true)
                        }
                        Label(L10n.string("Timelapse"), systemImage: "film")
                    }
                }
                .buttonStyle(.glass)
                .help(L10n.string("Create Timelapse"))
                .accessibilityLabel(L10n.string(isExportingTimelapse ? "Creating timelapse" : "Timelapse"))
            }
            .controlSize(.small)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .frame(height: 28)
        }
    }

    private func monthNavigationControl(_ title: String, symbol: String, offset: Int) -> some View {
        Button { changeMonth(by: offset) } label: {
            Label(title, systemImage: symbol)
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
        .frame(width: 28, height: 24)
        .contentShape(Rectangle())
        .help(title)
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

    @Environment(\.colorSchemeContrast) private var contrast
    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            ZStack {
                Circle()
                    .fill(backgroundColor)
                    .frame(width: 28, height: 28)

                Circle()
                    .stroke(isFocused ? Color.accentColor : Color.clear, lineWidth: 1)
                    .frame(width: 28, height: 28)

                VStack(spacing: 1) {
                    Text(date.formatted(.dateTime.day()))
                        .font(.caption)
                        .fontWeight(Calendar.current.isDateInToday(date) ? .semibold : .regular)

                    CalendarStatusDot(status: status)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 28)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(status == .future)
        .focused(focusedDay, equals: date)
        .onHover { isHovering in
            isHovered = isHovering
        }
        .opacity(isInDisplayedMonth ? 1 : contrast == .increased ? 0.65 : 0.35)
        .help(status.accessibilityDescription)
        .accessibilityLabel(DateFormatters.completeDate.string(from: date))
        .accessibilityValue(status.accessibilityDescription)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var backgroundColor: Color {
        if isSelected {
            return Color.accentColor.opacity(contrast == .increased ? 0.3 : 0.16)
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
    let canSaveLocalCopy: Bool
    let onTakeChameo: () -> Void
    let onDelete: (ChameoAsset, Bool) async -> Void
    let onSaveLocalCopy: (ChameoAsset) async -> Void
    let thumbnailLoader: (ChameoAsset, CGFloat) async -> NSImage?

    @State private var selectedAssetID: String?
    @State private var locationName = ""
    @State private var isLoadingLocationName = false
    @State private var isConfirmingDeletion = false
    @State private var trashLocalCopy = false
    @State private var isPerformingAction = false

    private var selectedAsset: ChameoAsset? {
        assets.first { $0.id == selectedAssetID } ?? assets.first
    }

    var body: some View {
        Group {
            if let selectedAsset {
                if isConfirmingDeletion {
                    PhotoDeletionConfirmationView(trashLocalCopy: $trashLocalCopy) {
                        delete(selectedAsset)
                    } onCancel: {
                        isConfirmingDeletion = false
                        trashLocalCopy = false
                    }
                } else {
                    populatedPreview(selectedAsset)
                }
            } else {
                emptyPreview
            }
        }
        .disabled(isPerformingAction)
        .onChange(of: selectedAsset?.id) { _, _ in
            isConfirmingDeletion = false
            trashLocalCopy = false
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
            CalendarAssetImage(asset: selectedAsset, size: 96, thumbnailLoader: thumbnailLoader)

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

                    photoActions
                }
                .frame(height: ChameoLayout.compactControlSize)

                locationRow(for: selectedAsset)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if isPerformingAction {
                    ProgressView().controlSize(.small)
                        .accessibilityLabel(L10n.string("Updating photo"))
                }

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
            .accessibilityLabel(L10n.format("Open %@ in Google Maps", locationText))
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
                    .buttonStyle(.glassProminent)
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
                        size: 32,
                        thumbnailLoader: thumbnailLoader
                    ) {
                        selectedAssetID = asset.id
                        isConfirmingDeletion = false
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 34)
    }

    private var photoActions: some View {
        ChameoMoreMenu(title: L10n.string("Photo Actions")) {
            Button(L10n.string("Save Local Copy")) {
                guard let selectedAsset else { return }
                isPerformingAction = true
                Task {
                    await onSaveLocalCopy(selectedAsset)
                    isPerformingAction = false
                }
            }
            .disabled(!canSaveLocalCopy)

            Divider()
            Button(L10n.string("Delete Photo"), role: .destructive) {
                trashLocalCopy = false
                isConfirmingDeletion = true
            }
        }
    }

    private func delete(_ asset: ChameoAsset) {
        let shouldTrash = trashLocalCopy
        trashLocalCopy = false
        isConfirmingDeletion = false
        isPerformingAction = true
        Task {
            await onDelete(asset, shouldTrash)
            isPerformingAction = false
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
    let thumbnailLoader: (ChameoAsset, CGFloat) async -> NSImage?

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
        .chameoImageOutline(cornerRadius: 8)
        .task(id: asset.id) {
            thumbnail = nil
            let loaded = await thumbnailLoader(asset, size)
            guard !Task.isCancelled else { return }
            thumbnail = loaded
        }
    }
}

private struct CalendarAssetThumbnail: View {
    let asset: ChameoAsset
    let isSelected: Bool
    let size: CGFloat
    let thumbnailLoader: (ChameoAsset, CGFloat) async -> NSImage?
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            CalendarAssetImage(asset: asset, size: size, thumbnailLoader: thumbnailLoader)
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                }
        }
        .buttonStyle(.plain)
        .frame(minWidth: 24, minHeight: 24)
        .contentShape(Rectangle())
        .accessibilityLabel(
            asset.createdAt.map(DateFormatters.libraryDate.string(from:)) ?? "Chameo")
    }
}
