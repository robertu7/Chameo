import ChameoCore
import CoreLocation
import SwiftUI
import UIKit

struct MobileLibraryView: View {
    @Environment(MobileAppModel.self) private var appModel
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("albumName") private var albumName = "Chameo"
    @State private var model = MobileLibraryModel()
    @State private var timelapse = MobileTimelapseModel()
    @State private var displayedMonth = Date()
    @State private var selectedDay: SelectedDay?

    private var calendar: Calendar {
        var value = Calendar.current
        value.locale = Locale.current
        return value
    }

    var body: some View {
        Group {
            if appModel.permissions.photosStatus.isGranted {
                libraryContent
            } else {
                PermissionRecoveryView(
                    title: "Photos unavailable",
                    message: appModel.permissions.photosStatus == .limited
                        ? "Full Photos Access is required to manage the Chameo album."
                        : "Allow Photos access in Settings to view and manage Chameos.",
                    systemImage: "photo.on.rectangle"
                )
            }
        }
        .navigationTitle("Library")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Timelapse", systemImage: "film") {
                    timelapse.export(assets: model.assets)
                }
                .disabled(model.assets.isEmpty || timelapse.isExporting)
            }
            if model.isLoading {
                ToolbarItem(placement: .topBarTrailing) {
                    ProgressView().accessibilityLabel("Refreshing Library")
                }
            }
        }
        .task(id: albumName) { await model.reload(albumName: albumName) }
        .onAppear { Task { await model.reload(albumName: albumName) } }
        .onChange(of: scenePhase) {
            if scenePhase != .active, timelapse.isExporting {
                timelapse.cancel()
            }
        }
        .overlay {
            if timelapse.isExporting {
                TimelapseProgressView(
                    progress: timelapse.progress,
                    cancel: { timelapse.cancel() }
                )
            }
        }
        .sheet(isPresented: timelapseOutputBinding) {
            if let outputURL = timelapse.outputURL {
                TimelapseExportView(
                    outputURL: outputURL,
                    saveToPhotos: { await timelapse.saveToPhotos() }
                )
            }
        }
        .alert("Timelapse", isPresented: timelapseMessageBinding) {
            Button("OK") { timelapse.message = nil }
        } message: {
            Text(timelapse.message ?? "")
        }
        .sheet(item: $selectedDay) { selection in
            DayDetailView(
                date: selection.date,
                assets: model.assets(on: selection.date),
                albumName: albumName,
                delete: { asset in await model.delete(asset, albumName: albumName) }
            )
        }
    }

    private var timelapseOutputBinding: Binding<Bool> {
        Binding(
            get: { timelapse.outputURL != nil },
            set: {
                if !$0 { timelapse.cancel(removeCompletedOutput: true) }
            }
        )
    }

    private var timelapseMessageBinding: Binding<Bool> {
        Binding(
            get: { timelapse.message != nil && timelapse.outputURL == nil },
            set: { if !$0 { timelapse.message = nil } }
        )
    }

    private var libraryContent: some View {
        VStack(spacing: 12) {
            monthHeader
            weekdayHeader
            calendarGrid
            if let error = model.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal)
    }

    private var monthHeader: some View {
        HStack {
            Button("Previous Month", systemImage: "chevron.left") {
                displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth)
                    ?? displayedMonth
            }
            .labelStyle(.iconOnly)
            Spacer()
            Text(displayedMonth, format: .dateTime.month(.wide).year())
                .font(.headline)
            Spacer()
            Button("Next Month", systemImage: "chevron.right") {
                displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth)
                    ?? displayedMonth
            }
            .labelStyle(.iconOnly)
        }
    }

    private var weekdayHeader: some View {
        return LazyVGrid(columns: columns) {
            ForEach(weekdayLabels) { label in
                Text(label.symbol)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
        }
    }

    private var calendarGrid: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(
                DailyCaptureHistory.calendarDates(
                    inMonthContaining: displayedMonth,
                    calendar: calendar
                ),
                id: \.self
            ) { date in
                CalendarDayButton(
                    date: date,
                    displayedMonth: displayedMonth,
                    captureDates: model.assets.map(\.createdAt),
                    isAvailable: model.hasLoaded,
                    calendar: calendar
                ) {
                    selectedDay = SelectedDay(date: date)
                }
            }
        }
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    }

    private var weekdayLabels: [WeekdayLabel] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        return (0..<7).map { offset in
            let symbolIndex = (calendar.firstWeekday - 1 + offset) % 7
            return WeekdayLabel(weekday: symbolIndex + 1, symbol: symbols[symbolIndex])
        }
    }
}

private struct TimelapseProgressView: View {
    let progress: Double
    let cancel: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            ProgressView(value: progress)
                .progressViewStyle(.linear)
            Text("Creating timelapse…")
                .font(.headline)
            Text(progress, format: .percent.precision(.fractionLength(0)))
                .monospacedDigit()
                .foregroundStyle(.secondary)
            Button("Cancel", role: .cancel, action: cancel)
        }
        .padding(24)
        .frame(maxWidth: 320)
        .background(.regularMaterial, in: .rect(cornerRadius: 20))
        .padding()
        .accessibilityElement(children: .contain)
    }
}

private struct TimelapseExportView: View {
    @Environment(\.dismiss) private var dismiss
    let outputURL: URL
    let saveToPhotos: () async -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "film.stack")
                    .font(.system(size: 56))
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
                Text("Your 1080 × 1080 timelapse is ready.")
                    .multilineTextAlignment(.center)
                Button("Save to Photos", systemImage: "photo.badge.plus") {
                    Task { await saveToPhotos() }
                }
                .buttonStyle(.borderedProminent)
                ShareLink(item: outputURL) {
                    Label("Save to Files or Share", systemImage: "square.and.arrow.up")
                }
            }
            .padding()
            .navigationTitle("Timelapse")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct WeekdayLabel: Identifiable {
    let weekday: Int
    let symbol: String
    var id: Int { weekday }
}

private struct SelectedDay: Identifiable {
    let date: Date
    var id: Date { date }
}

private struct CalendarDayButton: View {
    let date: Date
    let displayedMonth: Date
    let captureDates: [Date]
    let isAvailable: Bool
    let calendar: Calendar
    let action: () -> Void

    private var status: DailyCaptureStatus {
        DailyCaptureHistory.status(
            for: date,
            captureDates: captureDates,
            calendar: calendar,
            isAvailable: isAvailable
        )
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Text(date, format: .dateTime.day())
                    .font(.body)
                Circle()
                    .fill(statusColor)
                    .frame(width: 7, height: 7)
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .foregroundStyle(
                calendar.isDate(date, equalTo: displayedMonth, toGranularity: .month)
                    ? .primary : .tertiary
            )
            .background(
                calendar.isDateInToday(date) ? Color.accentColor.opacity(0.12) : .clear,
                in: .rect(cornerRadius: 10)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(date.formatted(date: .complete, time: .omitted))
        .accessibilityValue(statusDescription)
    }

    private var statusColor: Color {
        switch status {
        case .captured: .green
        case .pendingToday: .orange
        case .missed: .red.opacity(0.7)
        case .future, .outsideTracking, .unknown: .clear
        }
    }

    private var statusDescription: String {
        switch status {
        case .captured: String(localized: "Captured")
        case .pendingToday: String(localized: "Not captured yet")
        case .missed: String(localized: "Missed")
        case .future: String(localized: "Future")
        case .outsideTracking: String(localized: "Before tracking began")
        case .unknown: String(localized: "Status unavailable")
        }
    }
}

private struct DayDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let date: Date
    let assets: [MobileChameoAsset]
    let albumName: String
    let delete: (MobileChameoAsset) async -> Void
    @State private var deletionCandidate: MobileChameoAsset?

    var body: some View {
        NavigationStack {
            Group {
                if assets.isEmpty {
                    ContentUnavailableView("No Chameos", systemImage: "photo")
                } else {
                    List(assets) { asset in
                        HStack(spacing: 14) {
                            MobileAssetThumbnail(asset: asset, size: 84)
                            VStack(alignment: .leading, spacing: 6) {
                                Text(asset.createdAt, format: .dateTime.hour().minute())
                                if let location = asset.location,
                                   let url = googleMapsURL(location) {
                                    Link("Open in Google Maps", destination: url)
                                        .font(.footnote)
                                }
                            }
                            Spacer()
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                deletionCandidate = asset
                            }
                            .labelStyle(.iconOnly)
                        }
                    }
                }
            }
            .navigationTitle(date.formatted(date: .long, time: .omitted))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Delete Photo?", isPresented: deletionBinding) {
                Button("Delete", role: .destructive) {
                    guard let candidate = deletionCandidate else { return }
                    Task {
                        await delete(candidate)
                        deletionCandidate = nil
                    }
                }
                Button("Cancel", role: .cancel) { deletionCandidate = nil }
            } message: {
                Text("This deletes the original from Photos, every album, and synced devices. Photos may keep it in Recently Deleted.")
            }
        }
    }

    private var deletionBinding: Binding<Bool> {
        Binding(
            get: { deletionCandidate != nil },
            set: { if !$0 { deletionCandidate = nil } }
        )
    }

    private func googleMapsURL(_ location: CLLocation) -> URL? {
        var components = URLComponents(string: "https://www.google.com/maps/search/")
        components?.queryItems = [
            URLQueryItem(name: "api", value: "1"),
            URLQueryItem(
                name: "query",
                value: "\(location.coordinate.latitude),\(location.coordinate.longitude)"
            ),
        ]
        return components?.url
    }
}

private struct MobileAssetThumbnail: View {
    let asset: MobileChameoAsset
    let size: CGFloat
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ProgressView()
            }
        }
        .frame(width: size, height: size)
        .clipShape(.rect(cornerRadius: 10))
        .task(id: asset.id) {
            image = await MobilePhotoLibraryService.thumbnail(
                for: asset,
                size: CGSize(width: size * 2, height: size * 2)
            )
        }
        .accessibilityLabel("Chameo captured \(asset.createdAt.formatted(date: .abbreviated, time: .shortened))")
    }
}
