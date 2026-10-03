import AppKit
import SwiftUI

struct ContentView: View {
    let surface: ChameoMainSurface
    let onOpenTimelapse: () -> Void
    let onOpenSettings: () -> Void

    @EnvironmentObject private var timelapseExport: TimelapseExportController
    @EnvironmentObject private var cameraService: CameraService
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
            MainSurfaceNavigation(selection: $appState.selectedTab, onOpenSettings: onOpenSettings)
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
        .buttonBorderShape(.roundedRectangle(radius: 8))
        .environment(\.locale, localizationController.displayLocale)
        .task { await reloadLibraryIfAuthorized(albumName: albumName) }
        .onChange(of: statusMessage?.text) { _, text in
            if let text { AccessibilityAnnouncement.post(text) }
        }
        .onChange(of: albumName) { _, name in
            Task { await reloadLibraryIfAuthorized(albumName: name) }
        }
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
            if appState.selectedTab == .camera, statusMessage == nil, case .ready = cameraService.status {
                Text(L10n.string("Press Return to capture")).foregroundStyle(.secondary)
            }
            if timelapseExport.hasStatus {
                Button(action: onOpenTimelapse) {
                    Label(timelapseExport.footerText, systemImage: "film")
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(Color.accentColor)
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
