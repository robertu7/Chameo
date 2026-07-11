import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var libraryStore: LibraryStore
    let albumName: String

    @State private var didDeletePhoto = false
    @State private var isExportingTimelapse = false
    @State private var timelapseErrorMessage: String?

    private var sections: [LibrarySection] {
        LibrarySection.sections(for: libraryStore.assets)
    }

    private var captureProgress: CaptureProgress? {
        CaptureProgress.calculate(captureDates: libraryStore.assets.compactMap(\.createdAt))
    }

    private var isPhotosPermissionError: Bool {
        switch PhotoLibraryService.authorizationStatus() {
        case .denied, .restricted:
            return true
        default:
            return false
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if libraryStore.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if isPhotosPermissionError {
                ContentUnavailableView {
                    Label("Photos Access Is Off", systemImage: "photo.on.rectangle.angled")
                } description: {
                    Text("Allow Photos access to show and save Chameos.")
                } actions: {
                    Button(PermissionRecoveryDestination.photos.title) {
                        PermissionRecoveryService.open(.photos)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if libraryStore.assets.isEmpty {
                ContentUnavailableView {
                    Label("No Chameos", systemImage: "photo")
                } description: {
                    Text("Photos saved to \(PhotoLibraryService.normalizedAlbumName(albumName)) appear here.")
                } actions: {
                    Button {
                        appState.selectedTab = .camera
                    } label: {
                        Label("Take First Chameo", systemImage: "camera")
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        if let captureProgress {
                            CaptureProgressView(progress: captureProgress)
                        }

                        Button(action: exportTimelapse) {
                            HStack {
                                if isExportingTimelapse {
                                    ProgressView()
                                        .controlSize(.small)
                                        .accessibilityLabel("Creating timelapse")
                                }

                                Text(isExportingTimelapse ? "Creating Timelapse…" : "Create Timelapse")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(isExportingTimelapse)

                        ForEach(sections) { section in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(section.title)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)
                                    .textCase(.uppercase)
                                    .padding(.horizontal, 2)

                                VStack(spacing: 1) {
                                    ForEach(section.assets) { asset in
                                        LibraryRow(asset: asset) {
                                            let didDelete = await libraryStore.deleteFromLibrary(asset, albumName: albumName)

                                            if didDelete {
                                                didDeletePhoto = true
                                            }
                                        }

                                        if asset.id != section.assets.last?.id {
                                            Divider()
                                                .padding(.leading, 76)
                                        }
                                    }
                                }
                                .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(.quaternary, lineWidth: 1)
                                }
                            }
                        }
                    }
                    .padding(14)
                }
                .background(Color(nsColor: .controlBackgroundColor))
            }

            if let error = libraryStore.errorMessage ?? timelapseErrorMessage {
                PermissionStatusInline(
                    message: error,
                    destination: isPhotosPermissionError ? .photos : nil
                )
                .padding(.horizontal, 14)
                .padding(.bottom, 8)
            }

            if didDeletePhoto {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .foregroundStyle(.secondary)

                    Text("Deleted from Photos")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 8)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .task {
            await libraryStore.reload(albumName: albumName)
        }
    }

    @MainActor
    private func exportTimelapse() {
        guard !isExportingTimelapse else {
            return
        }

        timelapseErrorMessage = nil
        isExportingTimelapse = true

        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.mpeg4Movie]
        savePanel.nameFieldStringValue = "Chameo Timelapse.mp4"
        savePanel.prompt = "Create"

        savePanel.begin { response in
            guard response == .OK, let url = savePanel.url else {
                isExportingTimelapse = false
                return
            }

            Task {
                let isAccessingSecurityScopedResource = url.startAccessingSecurityScopedResource()
                defer {
                    if isAccessingSecurityScopedResource {
                        url.stopAccessingSecurityScopedResource()
                    }
                    isExportingTimelapse = false
                }

                do {
                    let assets = libraryStore.timelapseAssets()
                    try await TimelapseService.generate(assets: assets, to: url)
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                } catch {
                    timelapseErrorMessage = error.localizedDescription
                }
            }
        }
    }
}

private struct CaptureProgressView: View {
    let progress: CaptureProgress

    private var missedDatesText: String {
        progress.missedDates
            .map { $0.formatted(.dateTime.month(.abbreviated).day()) }
            .joined(separator: ", ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("30-Day Progress", systemImage: "calendar")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(progress.capturedDayCount)/\(progress.elapsedDayCount) days captured")
                    .font(.callout)
                    .fontWeight(.semibold)
            }

            if progress.elapsedDayCount == 0 {
                Text("Today is pending. Tracking starts when the day is complete.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if progress.missedDates.isEmpty {
                Text("No missed days")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Missed: \(missedDatesText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.quaternary, lineWidth: 1)
        }
    }
}

private struct LibrarySection: Identifiable {
    let id: Date
    let title: String
    let assets: [ChameoAsset]

    static func sections(for assets: [ChameoAsset]) -> [LibrarySection] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: assets) { asset in
            calendar.startOfDay(for: asset.createdAt ?? .distantPast)
        }

        return grouped
            .map { day, assets in
                LibrarySection(
                    id: day,
                    title: sectionTitle(for: day, calendar: calendar),
                    assets: assets.sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
                )
            }
            .sorted { $0.id > $1.id }
    }

    private static func sectionTitle(for day: Date, calendar: Calendar) -> String {
        if calendar.isDateInToday(day) {
            return "Today"
        }

        if calendar.isDateInYesterday(day) {
            return "Yesterday"
        }

        return DateFormatters.librarySectionDate.string(from: day)
    }
}

private struct LibraryRow: View {
    let asset: ChameoAsset
    let onDelete: () async -> Void

    @State private var thumbnail: NSImage?
    @State private var locationName = ""
    @State private var isLoadingLocationName = false
    @State private var isConfirmingDeletion = false

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "photo")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(asset.createdAt.map(DateFormatters.libraryDate.string(from:)) ?? "Unknown Date")
                    .font(.callout)
                HStack(spacing: 5) {
                    if isLoadingLocationName {
                        ProgressView()
                            .controlSize(.small)
                            .scaleEffect(0.65)
                            .frame(width: 12, height: 12)
                    }

                    Text(isLoadingLocationName ? "Loading location..." : locationName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if isConfirmingDeletion {
                HStack(spacing: 6) {
                    Button("Delete", role: .destructive) {
                        isConfirmingDeletion = false
                        Task {
                            await onDelete()
                        }
                    }
                    .buttonStyle(.borderless)

                    Button("Cancel") {
                        isConfirmingDeletion = false
                    }
                    .buttonStyle(.borderless)
                }
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
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .task(id: asset.id) {
            thumbnail = await PhotoLibraryService.thumbnail(for: asset.asset, size: CGSize(width: 128, height: 128))
            isLoadingLocationName = true
            locationName = await LocationNameService.name(for: asset.asset.location)
            isLoadingLocationName = false
        }
    }
}

struct PermissionStatusInline: View {
    let message: String
    let destination: PermissionRecoveryDestination?

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.orange)

            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Spacer()

            if let destination {
                Button(destination.title) {
                    PermissionRecoveryService.open(destination)
                }
                .font(.caption)
                .buttonStyle(.borderless)
            }
        }
    }
}
