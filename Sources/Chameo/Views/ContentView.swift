import AppKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var cameraService: CameraService
    @EnvironmentObject private var libraryStore: LibraryStore
    @EnvironmentObject private var localizationController: LocalizationController
    @Environment(\.openSettings) private var openSettings

    @AppStorage(AppPreferenceKey.albumName)
    private var albumName = AppDistribution.current.defaultAlbumName
    @AppStorage(AppPreferenceKey.handsFreeCountdown) private var handsFreeCountdown = false
    @AppStorage(AppPreferenceKey.showFaceGuide) private var showFaceGuide = true
    @AppStorage(AppPreferenceKey.saveLocation) private var saveLocation = false

    @State private var statusMessage: LocalizedMessage?

    var body: some View {
        VStack(spacing: 0) {
            TabPicker(selection: $appState.selectedTab)
                .frame(height: 24)
                .fixedSize(horizontal: true, vertical: false)
                .padding([.top, .horizontal], ChameoLayout.outerInset)
                .padding(.bottom, 28)

            Group {
                switch appState.selectedTab {
                case .camera:
                    CameraView(
                        albumName: albumName,
                        handsFreeCountdown: handsFreeCountdown,
                        showFaceGuide: showFaceGuide,
                        saveLocation: saveLocation,
                        statusMessage: $statusMessage
                    )
                case .library:
                    LibraryView(albumName: albumName)
                }
            }
            .frame(
                width: ChameoLayout.contentWidth,
                height: ChameoLayout.contentHeight,
                alignment: .top
            )

            Divider()

            HStack {
                Button {
                    openSettings()
                    NSApplication.shared.activate(ignoringOtherApps: true)
                } label: {
                    Label(L10n.string("Settings"), systemImage: "gearshape")
                }
                .labelStyle(.iconOnly)
                .frame(
                    width: ChameoLayout.compactControlSize,
                    height: ChameoLayout.compactControlSize
                )
                .help(L10n.string("Settings"))

                Spacer()

                if let statusMessage {
                    Text(statusMessage.text)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: 260)
                }

                Spacer()

                Button(role: .destructive) {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Label(L10n.string("Quit"), systemImage: "power")
                }
                .labelStyle(.iconOnly)
                .frame(
                    width: ChameoLayout.compactControlSize,
                    height: ChameoLayout.compactControlSize
                )
                .help(L10n.string("Quit Chameo"))
            }
            .padding(ChameoLayout.sectionSpacing)
        }
        .frame(width: ChameoLayout.popoverWidth)
        .environment(\.locale, localizationController.displayLocale)
        .task {
            syncCameraLifecycle()
            await reloadLibraryIfAuthorized(albumName: albumName)
        }
        .onDisappear {
            cameraService.stop()
        }
        .onChange(of: appState.selectedTab) { _, _ in
            syncCameraLifecycle()
        }
        .onChange(of: albumName) { _, newValue in
            Task {
                await reloadLibraryIfAuthorized(albumName: newValue)
            }
        }
    }

    private func syncCameraLifecycle() {
        if appState.selectedTab == .camera {
            cameraService.start()
        } else {
            cameraService.stop()
        }
    }

    private func reloadLibraryIfAuthorized(albumName: String) async {
        switch PhotoLibraryService.authorizationStatus() {
        case .authorized, .limited:
            await libraryStore.reload(albumName: albumName)
        case .notDetermined, .denied, .restricted:
            return
        @unknown default:
            return
        }
    }
}
