import AppKit
import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var libraryStore: LibraryStore
    @EnvironmentObject private var localPhotos: LocalPhotoSettingsController
    let albumName: String
    let onOpenTimelapse: () -> Void

    @State private var localCopyStatus: LocalizedMessage?
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
                    canSaveLocalCopy: localPhotos.configuration.isEnabled,
                    onTakeChameo: {
                        appState.selectedTab = .camera
                    },
                    onExportTimelapse: exportTimelapse,
                    onDelete: delete,
                    onSaveLocalCopy: saveLocalCopy
                )
            }

            if let error = libraryStore.errorMessage {
                PermissionStatusInline(
                    message: error.text,
                    destination: isPhotosPermissionError ? .photos : nil
                )
                .padding(.horizontal, 14)
                .padding(.bottom, 8)
            } else if let localCopyStatus {
                Text(localCopyStatus.text)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 8)
            } else if let warning = libraryStore.deletionWarning {
                PermissionStatusInline(message: warning.text, destination: nil)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 8)
            }
        }
        .task {
            await libraryStore.reload(albumName: albumName)
        }
        .onChange(of: libraryStore.errorMessage?.text ?? libraryStore.deletionWarning?.text) { _, newValue in
            guard let newValue else {
                return
            }

            AccessibilityAnnouncement.post(newValue, priority: .high)
        }
        .onChange(of: localCopyStatus?.text) { _, newValue in
            if let newValue { AccessibilityAnnouncement.post(newValue) }
        }
    }

    private func delete(_ asset: ChameoAsset, trashLocalCopy: Bool) async {
        localCopyStatus = nil
        _ = await libraryStore.deleteFromLibrary(asset, albumName: albumName,
                                                trashLocalCopy: trashLocalCopy, localPhotos: localPhotos.store)
    }

    private func saveLocalCopy(_ asset: ChameoAsset) async {
        localCopyStatus = nil
        libraryStore.errorMessage = nil
        do {
            guard await localPhotos.store.settings().isEnabled else {
                localCopyStatus = .localized("Local copies are off. Turn on Keep Local Copies in Settings.")
                return
            }
            let source = PhotosTimelapsePhotoSource()
            if try await localPhotos.store.original(for: source.snapshot(for: asset.id)) != nil {
                localCopyStatus = .localized("Local copy saved.")
                return
            }
            let original = try await source.original(for: asset.id, onDownload: { _ in })
            let current = try source.snapshot(for: asset.id)
            let saved = try await localPhotos.store.saveOriginal(
                original.data, source: original.source, fileExtension: original.fileExtension,
                representsCurrentOriginal: original.source.matchesCurrentOriginal(current),
                restoreMissingCopy: true
            )
            if saved {
                localCopyStatus = .localized("Local copy saved.")
            } else {
                localCopyStatus = .localized("Local copies are off. Turn on Keep Local Copies in Settings.")
            }
        } catch {
            libraryStore.errorMessage = .error(error)
        }
    }

    private func exportTimelapse() {
        if !timelapseExport.hasStatus && !timelapseExport.isBusy {
            timelapseExport.prepare(assets: libraryStore.timelapseAssets())
        }
        onOpenTimelapse()
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
                .help(message)
                .accessibilityLabel(message)
                .accessibilityAddTraits(.updatesFrequently)

            Spacer()

            if let destination {
                Button(destination.title) {
                    PermissionRecoveryService.open(destination)
                }
                .font(.caption)
                .buttonStyle(.borderless)
                .foregroundStyle(Color.accentColor)
            }
        }
    }
}
