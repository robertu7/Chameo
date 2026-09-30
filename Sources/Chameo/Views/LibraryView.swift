import AppKit
import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var libraryStore: LibraryStore
    let albumName: String

    @State private var didDeletePhoto = false
    @EnvironmentObject private var timelapseExport: TimelapseExportController

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
                    Label(L10n.string("Photos access is off"), systemImage: "photo.on.rectangle.angled")
                } description: {
                    Text(L10n.string("Allow Photos access to view and save Chameos."))
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
                    isExportingTimelapse: timelapseExport.isGenerating,
                    onTakeChameo: {
                        appState.selectedTab = .camera
                    },
                    onExportTimelapse: exportTimelapse,
                    onDelete: delete
                )
            }

            if let error = libraryStore.errorMessage {
                PermissionStatusInline(
                    message: error.text,
                    destination: isPhotosPermissionError ? .photos : nil
                )
                .padding(.horizontal, 14)
                .padding(.bottom, 8)
            }
        }
        .task {
            await libraryStore.reload(albumName: albumName)
        }
        .onChange(of: libraryStore.errorMessage?.text) { _, newValue in
            guard let newValue else {
                return
            }

            AccessibilityAnnouncement.post(newValue, priority: .high)
        }
    }

    private func delete(_ asset: ChameoAsset) async {
        let didDelete = await libraryStore.deleteFromLibrary(asset, albumName: albumName)
        if didDelete {
            didDeletePhoto = true
        }
    }

    private func exportTimelapse() {
        if !timelapseExport.hasStatus && !timelapseExport.isBusy {
            timelapseExport.prepare(assets: libraryStore.timelapseAssets())
        }
        appState.destination = .timelapse
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
                .accessibilityAddTraits(.updatesFrequently)

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
