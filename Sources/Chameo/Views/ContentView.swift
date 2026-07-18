import AppKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var cameraService: CameraService
    @EnvironmentObject private var libraryStore: LibraryStore
    @Environment(\.openSettings) private var openSettings

    @AppStorage(AppPreferenceKey.albumName) private var albumName = "Chameo"
    @AppStorage(AppPreferenceKey.showFaceGuide) private var showFaceGuide = true
    @AppStorage(AppPreferenceKey.saveLocation) private var saveLocation = false

    @State private var statusMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            Picker("View", selection: $appState.selectedTab) {
                ForEach(ChameoTab.allCases) { tab in
                    Label(tab.title, systemImage: tab.systemImage).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding([.top, .horizontal], 14)
            .padding(.bottom, 10)

            Group {
                switch appState.selectedTab {
                case .camera:
                    CameraView(
                        albumName: albumName,
                        showFaceGuide: showFaceGuide,
                        saveLocation: saveLocation,
                        statusMessage: $statusMessage
                    )
                case .library:
                    LibraryView(albumName: albumName)
                }
            }
            .frame(width: 420, height: 380)

            Divider()

            HStack {
                Button {
                    openSettings()
                    NSApplication.shared.activate(ignoringOtherApps: true)
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
                .labelStyle(.iconOnly)
                .help("Settings")

                Spacer()

                if let statusMessage {
                    Text(statusMessage)
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
                    Label("Quit", systemImage: "power")
                }
                .labelStyle(.iconOnly)
                .help("Quit Chameo")
            }
            .padding(12)
        }
        .frame(width: 448)
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
