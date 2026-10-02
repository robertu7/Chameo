import SwiftUI

struct TimelapseExportView: View {
    @EnvironmentObject private var libraryStore: LibraryStore
    @EnvironmentObject private var export: TimelapseExportController
    @EnvironmentObject private var localizationController: LocalizationController
    var onCreate: (() -> Void)?
    var onTakeChameo: () -> Void = {}
    var thumbnailLoader: (ChameoAsset) async -> NSImage? = TimelapsePreview.thumbnail

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 0) {
                        header.padding(.bottom, 16)
                        TimelapsePhotoStack(assets: previewAssets, side: photoSide(height: geometry.size.height),
                                            loader: thumbnailLoader)
                            .padding(.bottom, 14)
                        if export.assets.isEmpty {
                            Text(L10n.string("Take your first Chameo to create a timelapse."))
                                .font(.callout).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            videoSummary.padding(.bottom, 12)
                            statusContent.frame(minHeight: 44, alignment: .top)
                        }
                        supplementaryFeedback
                    }
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                    .frame(maxWidth: .infinity)
                }
                .defaultScrollAnchor(.center, for: .alignment)
                footer.padding(.horizontal, 24).padding(.top, 8).padding(.bottom, 12)
            }
            .background(.background)
        }
        .environment(\.locale, localizationController.displayLocale)
    }

    private func photoSide(height: CGFloat) -> CGFloat {
        // Preserve room for the status and fixed actions at the minimum window height.
        min(170, max(110, height - 310))
    }

    private var header: some View {
        VStack(spacing: 4) {
            Text(headerTitle).font(.system(size: 22, weight: .semibold))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(headerSubtitle).font(.callout).foregroundStyle(.secondary)
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
        let style = Date.FormatStyle(date: .abbreviated, time: .omitted).locale(localizationController.displayLocale)
        return first == last ? first.formatted(style) : first.formatted(style) + " – " + last.formatted(style)
    }

    private var videoSummary: some View {
        VStack(spacing: 6) {
            if !dateSpan.isEmpty {
                Text(dateSpan).font(.caption).foregroundStyle(.secondary).padding(.bottom, 2)
            }
            Text(photoCount + " → " + L10n.format("%.1f seconds", export.duration))
                .font(.system(size: 17, weight: .semibold)).monospacedDigit()
                .fixedSize(horizontal: false, vertical: true)
            Text(verbatim: "1080 × 1080 · MP4 · " + L10n.string("10 photos/sec"))
                .font(.caption).foregroundStyle(.secondary)
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
                if export.state == .running, let fraction = export.progress.phaseFraction(total: export.assets.count) {
                    ProgressView(value: fraction, total: 1)
                        .progressViewStyle(.linear)
                        .accessibilityLabel(L10n.string(export.progress.phaseTitleKey))
                        .accessibilityValue(progressDescription)
                } else {
                    ProgressView().progressViewStyle(.linear).accessibilityLabel(progressDescription)
                }
                Text(progressDescription).font(.caption).foregroundStyle(.secondary).monospacedDigit()
                    .fixedSize(horizontal: false, vertical: true)
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
            footerDetail.frame(minHeight: 15)
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
            if export.assets.isEmpty {
                Button(L10n.string("Take Chameo"), systemImage: "camera", action: onTakeChameo)
                    .buttonStyle(.glassProminent).keyboardShortcut(.defaultAction)
            } else {
                Button {
                    if let onCreate { onCreate() } else { export.chooseDestination() }
                } label: {
                    Text(L10n.string(isFailure ? "Retry…" : "Create Timelapse…")).frame(minWidth: 200)
                }
                .buttonStyle(.glassProminent).keyboardShortcut(.defaultAction)
                .disabled(export.isBusy)
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
        if export.state == .running, case .framesWritten(let count) = export.progress {
            return L10n.format("Encoding video · %lld of %lld photos", Int64(count), Int64(export.assets.count))
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
