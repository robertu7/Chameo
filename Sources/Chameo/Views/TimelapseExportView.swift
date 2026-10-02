import SwiftUI

struct TimelapseExportView: View {
    @EnvironmentObject private var libraryStore: LibraryStore
    @EnvironmentObject private var export: TimelapseExportController
    @EnvironmentObject private var localizationController: LocalizationController
    var onCreate: (() -> Void)?
    var onTakeChameo: () -> Void = {}
    var thumbnailLoader: (ChameoAsset) async -> NSImage? = TimelapsePreview.thumbnail

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    switch export.state {
                    case .succeeded(let result): resultContent(result)
                    case .running, .cancelling: progressContent
                    case .summary, .choosingDestination, .cancelled, .failed: summaryContent
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .defaultScrollAnchor(export.isGenerating || isComplete ? .center : .top, for: .alignment)
            Divider()
            footer
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
        }
        .environment(\.locale, localizationController.displayLocale)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: headerSymbol)
                .font(.title2)
                .foregroundStyle(isComplete ? Color.green : Color.accentColor)
                .accessibilityHidden(true)
            Text(headerTitle).font(.title2.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
        }
    }

    private var headerTitle: String {
        switch export.state {
        case .succeeded: return L10n.string("Timelapse ready")
        case .cancelling: return L10n.string("Cancelling…")
        case .running: return L10n.string(export.progress.phaseTitleKey)
        case .cancelled: return L10n.string("Export cancelled")
        case .failed: return L10n.string("Timelapse export failed")
        case .summary, .choosingDestination: return L10n.string("Create Timelapse")
        }
    }

    private var headerSymbol: String {
        switch export.state {
        case .succeeded: return "checkmark.circle.fill"
        case .running, .cancelling: return "film"
        case .failed: return "exclamationmark.triangle"
        default: return "film.stack"
        }
    }

    private var isComplete: Bool {
        if case .succeeded = export.state { return true }
        return false
    }

    private var previewAssets: [ChameoAsset] {
        guard !export.assets.isEmpty else { return [] }
        return Array(Set([0, export.assets.count / 2, export.assets.count - 1])).sorted().map { export.assets[$0] }
    }

    private var filmstrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ForEach(previewAssets) { asset in
                    TimelapsePhotoPreview(asset: asset, loader: thumbnailLoader)
                        .frame(width: 72, height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityHidden(true)
            if !dateSpan.isEmpty {
                Text(dateSpan).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var dateSpan: String {
        let dates = export.assets.compactMap(\.createdAt)
        guard let first = dates.min(), let last = dates.max() else { return "" }
        let style = Date.FormatStyle(date: .abbreviated, time: .omitted).locale(localizationController.displayLocale)
        return first == last ? first.formatted(style) : first.formatted(style) + " – " + last.formatted(style)
    }

    private var videoDetails: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(photoCount + " · " + L10n.format("%.1f seconds", export.duration))
                .font(.headline).monospacedDigit()
            Text(verbatim: "1080p · MP4").font(.caption).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var photoCount: String {
        export.assets.count == 1 ? L10n.string("1 photo") : L10n.format("%lld photos", Int64(export.assets.count))
    }

    @ViewBuilder
    private var summaryContent: some View {
        if export.assets.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.string("No Chameos are available for a timelapse.")).font(.headline)
                Text(L10n.string("Take your first Chameo to create a timelapse."))
                    .foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
        } else {
            filmstrip
            videoDetails
            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.string("Includes every Chameo in this album, across all months."))
                Text(L10n.string("10 photos per second, oldest to newest.")).font(.caption)
            }
            .font(.callout).foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            if case .failed(let message) = export.state {
                messagePanel(message, icon: "exclamationmark.triangle", color: .orange)
            }
        }
    }

    private var progressContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if export.state == .running, let fraction = export.progress.phaseFraction(total: export.assets.count) {
                ProgressView(value: fraction, total: 1)
                    .progressViewStyle(.linear)
                    .accessibilityLabel(headerTitle)
                    .accessibilityValue(export.footerText)
            } else {
                ProgressView().progressViewStyle(.linear)
                    .accessibilityLabel(headerTitle)
            }
            if export.footerText != headerTitle {
                Text(export.footerText)
                    .font(.callout).foregroundStyle(.secondary).monospacedDigit()
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, 8)
    }

    private func resultContent(_ result: TimelapseResult) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text(result.url.lastPathComponent).font(.headline).textSelection(.enabled)
                    .lineLimit(2).truncationMode(.middle).help(result.url.lastPathComponent)
                Label(L10n.format("Saved in %@", result.url.deletingLastPathComponent().lastPathComponent), systemImage: "folder")
                    .font(.callout).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                    .help(result.url.deletingLastPathComponent().path)
                    .accessibilityLabel(L10n.format("Saved in %@", result.url.deletingLastPathComponent().path))
            }
            videoDetails
            if let error = export.resultActionError { messagePanel(error, icon: "exclamationmark.triangle", color: .orange) }
            if let note = export.completionNote {
                Text(note).font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var footer: some View {
        switch export.state {
        case .running, .cancelling:
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.string("You can close this window. Generation continues."))
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Spacer(minLength: 0)
                    Button(L10n.string("Cancel"), action: export.cancel)
                        .buttonStyle(.glass).disabled(export.state == .cancelling)
                        .keyboardShortcut(.cancelAction)
                }
            }
        case .succeeded(let result):
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    Button(L10n.string("Create Another")) { export.prepare(assets: libraryStore.timelapseAssets()) }
                        .buttonStyle(.borderless).font(.caption)
                    Spacer(minLength: 0)
                    Button(L10n.string("Open Video"), systemImage: "play") { export.openResult(id: result.id, play: true) }
                        .buttonStyle(.glass)
                    Button(L10n.string("Open Folder"), systemImage: "folder") { export.openResult(id: result.id) }
                        .buttonStyle(.glassProminent).keyboardShortcut(.defaultAction)
                }
            }
        case .summary, .choosingDestination, .cancelled, .failed:
            HStack {
                Spacer(minLength: 0)
                if export.assets.isEmpty {
                    Button(L10n.string("Take Chameo"), systemImage: "camera", action: onTakeChameo)
                        .buttonStyle(.glassProminent).keyboardShortcut(.defaultAction)
                } else {
                    Button(L10n.string(isFailure ? "Retry…" : "Create Timelapse…")) {
                        if let onCreate { onCreate() } else { export.chooseDestination() }
                    }
                    .buttonStyle(.glassProminent).keyboardShortcut(.defaultAction)
                    .disabled(export.isBusy)
                }
            }
        }
    }

    private var isFailure: Bool {
        if case .failed = export.state { return true }
        return false
    }

    private func messagePanel(_ text: String, icon: String, color: Color) -> some View {
        Label(text, systemImage: icon)
            .font(.callout).foregroundStyle(color).fixedSize(horizontal: false, vertical: true)
            .padding(12).frame(maxWidth: .infinity, alignment: .leading)
            .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
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
