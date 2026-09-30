import SwiftUI

struct TimelapseExportView: View {
    @EnvironmentObject private var libraryStore: LibraryStore
    @EnvironmentObject private var export: TimelapseExportController
    @EnvironmentObject private var localizationController: LocalizationController
    var onCreate: (() -> Void)?
    var thumbnailLoader: (ChameoAsset) async -> NSImage? = TimelapsePreview.thumbnail

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                filmstrip
                switch export.state {
                case .succeeded(let result): resultContent(result)
                case .running, .cancelling: progressContent
                case .summary, .choosingDestination, .cancelled, .failed: summaryContent
                }
            }
            .padding(28)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .environment(\.locale, localizationController.displayLocale)
        .task { await export.refreshNotificationStatus() }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: isComplete ? "checkmark.circle.fill" : "film.stack")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(isComplete ? Color.green : Color.accentColor)
                .frame(width: 52, height: 52)
                .background((isComplete ? Color.green : Color.accentColor).opacity(0.1),
                            in: RoundedRectangle(cornerRadius: 14))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.string(isComplete ? "Timelapse ready" : "Create Timelapse"))
                    .font(.title2.bold())
                Text(L10n.string("Your Chameos, brought together."))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }

    private var previewAssets: [ChameoAsset] {
        guard !export.assets.isEmpty else { return [] }
        return Array(Set([0, export.assets.count / 2, export.assets.count - 1])).sorted().map { export.assets[$0] }
    }

    private var filmstrip: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                if previewAssets.isEmpty {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 36)).foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity).frame(height: 132)
                } else {
                    ForEach(previewAssets) { asset in
                        TimelapsePhotoPreview(asset: asset, loader: thumbnailLoader)
                            .frame(maxWidth: .infinity).frame(height: 132)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            .accessibilityHidden(true)
            HStack {
                Label(L10n.string("All album photos"), systemImage: "photo.stack")
                Spacer()
                Text(dateSpan).multilineTextAlignment(.trailing)
            }
            .font(.caption).foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.primary.opacity(0.06)))
    }

    private var dateSpan: String {
        let dates = export.assets.compactMap(\.createdAt)
        guard let first = dates.min(), let last = dates.max() else { return "" }
        let style = Date.FormatStyle(date: .abbreviated, time: .omitted).locale(localizationController.displayLocale)
        return first == last ? first.formatted(style) : first.formatted(style) + " – " + last.formatted(style)
    }

    private var videoDetails: some View {
        HStack(spacing: 0) {
            metric("Photos", value: export.assets.count == 1 ? L10n.string("1 photo") : L10n.format("%lld photos", Int64(export.assets.count)), icon: "photo")
            Divider().frame(height: 34)
            metric("Video duration", value: L10n.format("%.1f seconds", export.duration), icon: "clock")
            Divider().frame(height: 34)
            metric("Format", value: "1080p · MP4", icon: "square")
        }
    }

    private func metric(_ title: String, value: String, icon: String) -> some View {
        VStack(spacing: 6) {
            Label(L10n.string(title), systemImage: icon).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.headline).monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var summaryContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            videoDetails
            VStack(alignment: .leading, spacing: 5) {
                Text(L10n.string("Includes every Chameo in this album, across all months."))
                Text(L10n.string("10 photos per second, oldest to newest."))
            }
            .font(.callout).foregroundStyle(.secondary)
            if case .failed(let message) = export.state { messagePanel(message, icon: "exclamationmark.triangle", color: .orange) }
            if export.state == .cancelled { messagePanel(L10n.string("Export cancelled"), icon: "xmark.circle", color: .secondary) }
            if export.assets.isEmpty {
                messagePanel(L10n.string("No Chameos are available for a timelapse."), icon: "photo", color: .secondary)
            }
            Divider()
            HStack(alignment: .center, spacing: 20) {
                notificationInfo
                Spacer(minLength: 0)
                Button(L10n.string(isFailure ? "Retry" : "Create Timelapse")) {
                    if let onCreate { onCreate() } else { export.chooseDestination() }
                }
                    .buttonStyle(.borderedProminent).controlSize(.large)
                    .keyboardShortcut(.defaultAction)
                    .disabled(export.isBusy || export.assets.isEmpty)
            }
        }
    }

    private var isComplete: Bool {
        if case .succeeded = export.state { return true }; return false
    }
    private var isFailure: Bool {
        if case .failed = export.state { return true }; return false
    }
    private var isDeterminate: Bool {
        export.state == .running && export.progress != .saving && export.completedPhotos < export.assets.count
    }

    private var progressContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.string(export.state == .cancelling ? "Cancelling…" : export.progress == .saving ? "Saving video…" : "Creating timelapse"))
                        .font(.title3.bold())
                    Text(export.footerText).font(.callout).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                if isDeterminate {
                    Text(Double(export.completedPhotos) / Double(max(1, export.assets.count)), format: .percent.precision(.fractionLength(0)))
                        .font(.system(size: 30, weight: .semibold, design: .rounded)).monospacedDigit()
                        .foregroundStyle(Color.accentColor).accessibilityHidden(true)
                } else { ProgressView().controlSize(.small).accessibilityLabel(export.footerText) }
            }
            if isDeterminate {
                ProgressView(value: Double(export.completedPhotos), total: Double(max(1, export.assets.count)))
                    .accessibilityLabel(L10n.string("Creating timelapse"))
                    .accessibilityValue(L10n.format("Photos completed: %lld of %lld", Int64(export.completedPhotos), Int64(export.assets.count)))
                Text(L10n.format("Photos completed: %lld of %lld", Int64(export.completedPhotos), Int64(export.assets.count)))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Divider()
            HStack(spacing: 20) {
                Label(L10n.string("You can browse Chameo or close this window while it generates."), systemImage: "arrow.up.forward.app")
                    .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Button(L10n.string("Cancel"), action: export.cancel)
                    .buttonStyle(.bordered).controlSize(.large).disabled(export.state == .cancelling)
            }
        }
    }

    private func resultContent(_ result: TimelapseResult) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                Image(systemName: "video.fill").font(.title).foregroundStyle(Color.accentColor).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 5) {
                    Text(result.url.lastPathComponent).font(.headline).textSelection(.enabled)
                    Text(result.url.deletingLastPathComponent().path)
                        .font(.callout).foregroundStyle(.secondary).textSelection(.enabled)
                        .lineLimit(2).truncationMode(.middle).help(result.url.deletingLastPathComponent().path)
                }
            }
            videoDetails
            if let error = export.resultActionError { messagePanel(error, icon: "exclamationmark.triangle", color: .orange) }
            if let note = export.completionNote { Text(note).font(.callout).foregroundStyle(.secondary) }
            if export.notificationStatus == .denied { notificationInfo }
            Divider()
            HStack(spacing: 10) {
                Button(L10n.string("Create Another")) { export.prepare(assets: libraryStore.timelapseAssets()) }
                    .buttonStyle(.borderless)
                Spacer()
                Button(L10n.string("Open Video"), systemImage: "play") { export.openResult(id: result.id, play: true) }
                    .buttonStyle(.bordered).controlSize(.large)
                Button(L10n.string("Open Folder"), systemImage: "folder") { export.openResult(id: result.id) }
                    .buttonStyle(.borderedProminent).controlSize(.large).keyboardShortcut(.defaultAction)
            }
        }
    }

    private func messagePanel(_ text: String, icon: String, color: Color) -> some View {
        Label(text, systemImage: icon)
            .font(.callout).foregroundStyle(color).fixedSize(horizontal: false, vertical: true)
            .padding(12).frame(maxWidth: .infinity, alignment: .leading)
            .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }

    private var notificationInfo: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(L10n.string(export.notificationStatus == .denied
                              ? "Notifications are off. Your video will still appear here when ready."
                              : "Chameo can notify you when your timelapse is ready."), systemImage: "bell")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if export.notificationStatus == .denied {
                Button(PermissionRecoveryDestination.notifications.title) { PermissionRecoveryService.open(.notifications) }
                    .buttonStyle(.borderless).font(.caption)
            }
        }
    }
}

private struct TimelapsePhotoPreview: View {
    let asset: ChameoAsset
    let loader: (ChameoAsset) async -> NSImage?
    @State private var image: NSImage?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(nsColor: .separatorColor).opacity(0.2)
                if let image {
                    Image(nsImage: image).resizable().scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height).clipped()
                } else {
                    Image(systemName: "photo").font(.largeTitle).foregroundStyle(.tertiary)
                }
            }
        }
        .task(id: asset.id) {
            image = nil
            let loaded = await loader(asset)
            guard !Task.isCancelled else { return }
            image = loaded
        }
    }
}
