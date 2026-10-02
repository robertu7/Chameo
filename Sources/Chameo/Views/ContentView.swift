import AppKit
import SwiftUI

struct ContentView: View {
    let surface: ChameoMainSurface
    let onOpenTimelapse: () -> Void
    let onOpenSettings: () -> Void

    @EnvironmentObject private var timelapseExport: TimelapseExportController
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var libraryStore: LibraryStore
    @EnvironmentObject private var localizationController: LocalizationController
    @AppStorage(AppPreferenceKey.albumName)
    private var albumName = AppDistribution.current.defaultAlbumName
    @AppStorage(AppPreferenceKey.handsFreeCountdown) private var handsFreeCountdown = false
    @AppStorage(AppPreferenceKey.showFaceGuide) private var showFaceGuide = true
    @AppStorage(AppPreferenceKey.saveLocation) private var saveLocation = false
    @State private var statusMessage: LocalizedMessage?

    var body: some View {
        VStack(spacing: 0) {
            navigation
                .frame(height: 66)
            Group {
                switch appState.selectedTab {
                case .camera:
                    CameraView(surface: surface, albumName: albumName, handsFreeCountdown: handsFreeCountdown,
                               showFaceGuide: showFaceGuide, saveLocation: saveLocation,
                               statusMessage: $statusMessage)
                case .library:
                    LibraryView(albumName: albumName, onOpenTimelapse: onOpenTimelapse)
                }
            }
            .frame(width: ChameoLayout.contentWidth, height: ChameoLayout.contentHeight, alignment: .top)
            feedback
                .frame(height: 53)
        }
        .frame(width: ChameoLayout.popoverWidth, height: ChameoLayout.popoverHeight)
        .environment(\.locale, localizationController.displayLocale)
        .task { await reloadLibraryIfAuthorized(albumName: albumName) }
        .onChange(of: statusMessage?.text) { _, text in
            if let text { AccessibilityAnnouncement.post(text) }
        }
        .onChange(of: albumName) { _, name in
            Task { await reloadLibraryIfAuthorized(albumName: name) }
        }
    }

    private var navigation: some View {
        HStack(spacing: 12) {
            Color.clear.frame(width: ChameoLayout.compactControlSize)
                .accessibilityHidden(true)
            Spacer(minLength: 0)
            TabPicker(selection: $appState.selectedTab)
                .frame(width: 248)
            Spacer(minLength: 0)
            Menu {
                Button(L10n.string("Settings…"), systemImage: "gearshape", action: onOpenSettings)
                    .keyboardShortcut(",", modifiers: .command)
                Divider()
                Button(L10n.string("Quit Chameo"), systemImage: "power") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: .command)
            } label: {
                Label {
                    Text(L10n.string("App Menu"))
                } icon: {
                    Image(systemName: "ellipsis.circle")
                        .resizable().scaledToFit()
                        .frame(width: 18, height: 18)
                }
            }
            .labelStyle(.iconOnly)
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: ChameoLayout.compactControlSize, height: ChameoLayout.compactControlSize)
            .help(L10n.string("App Menu"))
        }
        .padding(.horizontal, ChameoLayout.outerInset)
    }

    private var feedback: some View {
        VStack(spacing: 3) {
            if appState.selectedTab == .camera, let statusMessage {
                Text(statusMessage.text)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .help(statusMessage.text)
                    .accessibilityLabel(statusMessage.text)
            }
            if timelapseExport.hasStatus {
                Button(action: onOpenTimelapse) {
                    Label(timelapseExport.footerText, systemImage: "film")
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .buttonStyle(.borderless)
                .help(timelapseExport.footerText)
                .accessibilityHint(L10n.string("Show timelapse export"))
            }
        }
        .font(.caption)
        .frame(maxWidth: ChameoLayout.previewWidth)
    }

    private func reloadLibraryIfAuthorized(albumName: String) async {
        switch PhotoLibraryService.authorizationStatus() {
        case .authorized, .limited:
            await libraryStore.reload(albumName: albumName)
        default:
            return
        }
    }
}
