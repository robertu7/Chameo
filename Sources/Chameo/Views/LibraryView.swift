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
            if libraryStore.isLoading && !libraryStore.hasLoaded {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if isPhotosPermissionError {
                ContentUnavailableView {
                    Label("Photos access is off", systemImage: "photo.on.rectangle.angled")
                } description: {
                    Text("Allow Photos access to view and save Chameos.")
                } actions: {
                    Button(PermissionRecoveryDestination.photos.title) {
                        PermissionRecoveryService.open(.photos)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                CalendarLibraryView(
                    assets: libraryStore.assets,
                    selectedDay: $appState.selectedLibraryDay,
                    isRefreshing: libraryStore.isLoading,
                    isExportingTimelapse: isExportingTimelapse,
                    onTakeChameo: {
                        appState.selectedTab = .camera
                    },
                    onExportTimelapse: exportTimelapse,
                    onDelete: delete
                )
            }

            if let error = libraryStore.errorMessage ?? timelapseErrorMessage {
                PermissionStatusInline(
                    message: error,
                    destination: isPhotosPermissionError ? .photos : nil
                )
                .padding(.horizontal, 14)
                .padding(.bottom, 8)
            }
        }
        .task {
            await libraryStore.reload(albumName: albumName)
        }
    }

    private func delete(_ asset: ChameoAsset) async {
        let didDelete = await libraryStore.deleteFromLibrary(asset, albumName: albumName)
        if didDelete {
            didDeletePhoto = true
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
        savePanel.prompt = "Save"

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
