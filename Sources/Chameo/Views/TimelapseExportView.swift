import SwiftUI

struct TimelapseExportView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var libraryStore: LibraryStore
    @EnvironmentObject private var export: TimelapseExportController

    var body: some View {
        VStack(alignment: .leading, spacing: ChameoLayout.sectionSpacing) {
            HStack {
                Button(L10n.string("Back to Library"), systemImage: "chevron.left") {
                    appState.selectedTab = .library
                    appState.destination = .main
                }
                .buttonStyle(.borderless)
                Spacer()
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(L10n.string("Create Timelapse"))
                        .font(.title2).bold()
                    switch export.state {
                    case .succeeded(let result):
                        resultContent(result)
                    case .running, .cancelling:
                        progressContent
                    case .summary, .choosingDestination, .cancelled, .failed:
                        summaryContent
                    }
                    if export.notificationStatus == .denied || !isComplete { notificationInfo }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(ChameoLayout.sectionSpacing)
            }
            .background(Color(nsColor: .controlBackgroundColor),
                        in: RoundedRectangle(cornerRadius: ChameoLayout.cornerRadius))
            .chameoImageOutline(cornerRadius: ChameoLayout.cornerRadius)
        }
        .padding(.horizontal, ChameoLayout.outerInset)
        .padding(.bottom, ChameoLayout.sectionSpacing)
        .task { await export.refreshNotificationStatus() }
    }

    private var summaryContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.string("Includes every Chameo in this album, across all months."))
                .foregroundStyle(.secondary)
            LabeledContent(L10n.string("Photos")) {
                Text(export.assets.count == 1 ? L10n.string("1 photo") : L10n.format("%lld photos", Int64(export.assets.count)))
            }
            if let first = export.assets.compactMap(\.createdAt).min(),
               let last = export.assets.compactMap(\.createdAt).max() {
                LabeledContent(L10n.string("Date span")) {
                    Text(first.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted).locale(L10n.currentLocalization.displayLocale)) + " – "
                         + last.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted).locale(L10n.currentLocalization.displayLocale)))
                        .multilineTextAlignment(.trailing)
                }
            }
            LabeledContent(L10n.string("Video")) {
                Text(L10n.format("%.1f seconds · 1080p · MP4", export.duration))
            }
            Text(L10n.string("10 photos per second, oldest to newest."))
                .font(.callout).foregroundStyle(.secondary)
            if case .failed(let message) = export.state {
                Label(message, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            if export.state == .cancelled {
                Label(L10n.string("Export cancelled"), systemImage: "xmark.circle")
            }
            Button(action: export.chooseDestination) {
                Text(L10n.string(isFailure ? "Retry" : "Create Timelapse"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(export.isBusy || export.assets.isEmpty)
            if export.assets.isEmpty {
                Text(L10n.string("No Chameos are available for a timelapse."))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var isComplete: Bool {
        if case .succeeded = export.state { return true }
        return false
    }

    private var isFailure: Bool {
        if case .failed = export.state { return true }
        return false
    }

    private var progressTitle: String {
        if export.state == .running, case .framesWritten = export.progress {
            return L10n.string("Creating timelapse")
        }
        return export.footerText
    }

    private var progressContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(progressTitle).font(.headline)
                .accessibilityAddTraits(.updatesFrequently)
            if export.state == .running, export.progress != .saving,
               export.completedPhotos < export.assets.count {
                ProgressView(value: Double(export.completedPhotos), total: Double(max(1, export.assets.count)))
                    .accessibilityLabel(L10n.string("Creating timelapse"))
                    .accessibilityValue(L10n.format("Photos completed: %lld of %lld",
                                                   Int64(export.completedPhotos), Int64(export.assets.count)))
            } else {
                ProgressView().controlSize(.small)
                    .accessibilityLabel(export.footerText)
            }
            if export.state == .running, export.progress != .saving {
                Text(L10n.format("Photos completed: %lld of %lld", Int64(export.completedPhotos), Int64(export.assets.count)))
                    .font(.callout).foregroundStyle(.secondary)
            }
            Text(L10n.string("You can browse Chameo or close this window while it generates."))
                .foregroundStyle(.secondary)
            Button(L10n.string("Cancel"), action: export.cancel)
                .buttonStyle(.bordered)
                .disabled(export.state == .cancelling)
        }
    }

    private func resultContent(_ result: TimelapseResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(L10n.string("Timelapse ready"), systemImage: "checkmark.circle")
                .font(.headline)
            Text(result.url.lastPathComponent).bold()
                .textSelection(.enabled)
            Text(result.url.deletingLastPathComponent().path)
                .font(.callout).foregroundStyle(.secondary)
                .textSelection(.enabled)
            HStack {
                Button(L10n.string("Open Folder"), systemImage: "folder") {
                    export.openResult(id: result.id)
                }.buttonStyle(.borderedProminent)
                Button(L10n.string("Open Video"), systemImage: "play") {
                    export.openResult(id: result.id, play: true)
                }.buttonStyle(.bordered)
            }
            if let error = export.resultActionError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.secondary)
            }
            if let note = export.completionNote {
                Text(note).font(.callout).foregroundStyle(.secondary)
            }
            Button(L10n.string("Create Another")) {
                export.prepare(assets: libraryStore.timelapseAssets())
            }.buttonStyle(.borderless)
        }
    }

    private var notificationInfo: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()
            if export.notificationStatus == .denied {
                Text(L10n.string("Notifications are off. Your video will still appear here when ready."))
                    .font(.callout).foregroundStyle(.secondary)
                Button(PermissionRecoveryDestination.notifications.title) {
                    PermissionRecoveryService.open(.notifications)
                }.buttonStyle(.borderless)
            } else {
                Text(L10n.string("Chameo can notify you when your timelapse is ready."))
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
    }
}
