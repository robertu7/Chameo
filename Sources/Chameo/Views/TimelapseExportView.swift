import SwiftUI

struct TimelapseExportView: View {
    @EnvironmentObject private var libraryStore: LibraryStore
    @EnvironmentObject private var export: TimelapseExportController
    @EnvironmentObject private var localizationController: LocalizationController
    @FocusState private var createFocused: Bool
    var onCreate: (() -> Void)?
    var onTakeChameo: () -> Void = {}
    var thumbnailLoader: (ChameoAsset) async -> NSImage? = TimelapsePreview.thumbnail

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 0) {
                        header.padding(.bottom, 8)
                        TimelapsePhotoStack(assets: previewAssets, side: photoSide(height: geometry.size.height),
                                            loader: thumbnailLoader)
                            .padding(.bottom, 4)
                        if export.allAssets.isEmpty {
                            Text(L10n.string("Take your first Chameo to create a timelapse."))
                                .font(.callout).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            videoSummary
                            if showsOptions {
                                TimelapseOptionsView(export: export).padding(.top, 6)
                            }
                            if !showsOptions {
                                statusContent.frame(minHeight: 64, alignment: .top).padding(.top, 12)
                            }
                        }
                        supplementaryFeedback
                    }
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 70)
                    .padding(.top, 14)
                    .padding(.bottom, 2)
                    .frame(maxWidth: .infinity)
                }
                .defaultScrollAnchor(.top, for: .alignment)
                footer.padding(.horizontal, 24).padding(.top, 8).padding(.bottom, 14)
            }
            .background(.background)
            .buttonBorderShape(.roundedRectangle(radius: 8))
        }
        .environment(\.locale, localizationController.displayLocale)
    }

    private func photoSide(height: CGFloat) -> CGFloat {
        // Preserve the reference photo proportions while leaving room for expanded date fields.
        let extraFields: CGFloat
        if showsOptions {
            switch export.options.range {
            case .allPhotos: extraFields = 0
            case .month, .year: extraFields = 40
            }
        } else { extraFields = 0 }
        return min(144, max(88, height - 286 - extraFields))
    }

    private var showsOptions: Bool {
        switch export.state {
        case .summary, .choosingDestination, .cancelled, .failed: return true
        default: return false
        }
    }

    private var header: some View {
        VStack(spacing: 4) {
            Text(headerTitle).font(.system(size: 22, weight: .bold))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(headerSubtitle).font(.system(size: 14)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var headerTitle: String {
        switch export.state {
        case .succeeded: return L10n.string("Timelapse Created")
        case .cancelling: return L10n.string("Cancelling…")
        case .running: return L10n.string("Creating Timelapse…")
        case .cancelled: return L10n.string("Export cancelled")
        case .failed: return L10n.string("Timelapse export failed")
        case .summary, .choosingDestination: return L10n.string("Create Timelapse")
        }
    }

    private var headerSubtitle: String {
        switch export.state {
        case .succeeded: return L10n.string("Saved and ready to watch.")
        case .running, .cancelling: return L10n.string("Bringing your Chameos together.")
        default: return L10n.string("See how far you've come.")
        }
    }

    private var previewAssets: [ChameoAsset] {
        guard !export.assets.isEmpty else { return [] }
        return Array(Set([0, export.assets.count / 2, export.assets.count - 1])).sorted().map { export.assets[$0] }
    }

    private var dateSpan: String {
        let dates = export.assets.compactMap(\.createdAt)
        guard let first = dates.min(), let last = dates.max() else { return "" }
        let style = Date.FormatStyle(date: .abbreviated, time: .omitted,
                                    locale: localizationController.displayLocale,
                                    calendar: export.calendar, timeZone: export.calendar.timeZone)
        guard first != last else { return first.formatted(style) }
        let formatter = DateIntervalFormatter()
        formatter.locale = localizationController.displayLocale
        formatter.calendar = export.calendar
        formatter.timeZone = export.calendar.timeZone
        formatter.dateTemplate = "MMM d, yyyy"
        return formatter.string(from: first, to: last)
    }

    private var videoSummary: some View {
        VStack(spacing: 4) {
            if !dateSpan.isEmpty {
                Text(dateSpan).font(.system(size: 12)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(photoCount + " → " + L10n.format("%.1f seconds", export.duration))
                .font(.system(size: 18, weight: .bold)).monospacedDigit()
                .fixedSize(horizontal: false, vertical: true)
            Text(verbatim: "1080 × 1080 · MP4")
                .font(.system(size: 11)).foregroundStyle(.secondary)
            if !showsOptions {
                Text(L10n.format("%lld photos/sec", Int64(export.options.speed.rawValue)))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var photoCount: String {
        export.assets.count == 1 ? L10n.string("1 photo") : L10n.format("%lld photos", Int64(export.assets.count))
    }

    @ViewBuilder
    private var statusContent: some View {
        switch export.state {
        case .running, .cancelling:
            VStack(spacing: 8) {
                ProgressView(value: export.completedPhotoFraction, total: 1)
                    .progressViewStyle(.linear)
                    .accessibilityLabel(L10n.string("Creating Timelapse…"))
                    .accessibilityValue(export.completedPhotoText)
                VStack(spacing: 4) {
                    Text(export.completedPhotoText).font(.caption.weight(.medium)).monospacedDigit()
                        .fixedSize(horizontal: false, vertical: true)
                    Text(progressDescription).font(.caption).foregroundStyle(.secondary).monospacedDigit()
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: 310)
        case .succeeded(let result):
            VStack(spacing: 4) {
                Text(result.url.lastPathComponent).font(.callout.weight(.medium)).textSelection(.enabled)
                    .lineLimit(1).truncationMode(.middle).help(result.url.lastPathComponent)
                Label(L10n.format("Saved in %@", result.url.deletingLastPathComponent().lastPathComponent), systemImage: "folder")
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                    .help(result.url.deletingLastPathComponent().path)
                    .accessibilityLabel(L10n.format("Saved in %@", result.url.deletingLastPathComponent().path))
            }
        case .summary, .choosingDestination, .cancelled, .failed:
            Text(L10n.string("Every photo in your Chameo album."))
                .font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var supplementaryFeedback: some View {
        if showsOptions, !export.allAssets.isEmpty {
            if export.assets.isEmpty {
                Text(L10n.string("No photos in this period. Choose another date range."))
                    .font(.callout).foregroundStyle(.secondary).padding(.top, 8)
            }
            if export.options.range != .allPhotos, export.hasUndatedPhotos {
                Text(L10n.string("Photos without dates are only included in All Photos."))
                    .font(.caption).foregroundStyle(.secondary).padding(.top, 8)
            }
        }
        if case .failed(let message) = export.state {
            messagePanel(message).padding(.top, 12)
        }
        if let error = export.resultActionError {
            messagePanel(error).padding(.top, 12)
        }
        if let note = export.completionNote {
            Text(note).font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true).padding(.top, 12)
        }
    }

    private var footer: some View {
        VStack(spacing: 8) {
            GlassEffectContainer(spacing: 12) {
                actionButtons.controlSize(.large)
            }
            .frame(minHeight: 32)
            if !showsOptions { footerDetail.frame(minHeight: 15) }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var actionButtons: some View {
        switch export.state {
        case .running, .cancelling:
            Button(L10n.string("Cancel"), action: export.cancel)
                .buttonStyle(.glass).disabled(export.state == .cancelling)
                .keyboardShortcut(.cancelAction)
        case .succeeded(let result):
            HStack(spacing: 12) {
                Button(L10n.string("Open Folder"), systemImage: "folder") { export.openResult(id: result.id) }
                    .buttonStyle(.glass)
                Button(L10n.string("Open Video"), systemImage: "play.fill") { export.openResult(id: result.id, play: true) }
                    .buttonStyle(.glassProminent).keyboardShortcut(.defaultAction)
            }
        case .summary, .choosingDestination, .cancelled, .failed:
            if export.allAssets.isEmpty {
                Button(L10n.string("Take Chameo"), systemImage: "camera", action: onTakeChameo)
                    .buttonStyle(.glassProminent).keyboardShortcut(.defaultAction)
            } else {
                Button {
                    if let onCreate { onCreate() } else { export.chooseDestination() }
                } label: {
                    Text(L10n.string(isFailure ? "Retry…" : "Create Timelapse…"))
                        .font(.system(size: 13, weight: .semibold))
                }
                .buttonStyle(TimelapseCreateButtonStyle())
                .focused($createFocused)
                .overlay {
                    RoundedRectangle(cornerRadius: 12).inset(by: -3)
                        .strokeBorder(createFocused ? Color.accentColor : .clear, lineWidth: 2)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(export.isBusy || export.assets.isEmpty)
            }
        }
    }

    @ViewBuilder
    private var footerDetail: some View {
        switch export.state {
        case .running, .cancelling:
            Text(L10n.string("You can close this window. Creation continues."))
                .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        case .succeeded:
            Button(L10n.string("Create Another")) { export.prepare(assets: libraryStore.timelapseAssets()) }
                .buttonStyle(.borderless).font(.caption).foregroundStyle(Color.accentColor)
        default:
            Color.clear.frame(height: 15).accessibilityHidden(true)
        }
    }

    private var isFailure: Bool {
        if case .failed = export.state { return true }
        return false
    }

    private var progressDescription: String {
        if export.state == .running, case .framesWritten = export.progress {
            return L10n.string(export.progress.phaseTitleKey)
        }
        return export.footerText
    }

    private func messagePanel(_ text: String) -> some View {
        Label(text, systemImage: "exclamationmark.triangle")
            .font(.callout).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
            .padding(12).frame(maxWidth: .infinity)
            .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct TimelapseCreateButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .frame(width: 244, height: 30)
            .background(Color(red: 0, green: 0.48, blue: 1).gradient, in: RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.12), radius: 6, y: 4)
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.45)
    }
}
