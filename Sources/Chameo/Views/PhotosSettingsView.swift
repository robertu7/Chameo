import CoreLocation
import Photos
import SwiftUI

struct PhotosSettingsView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var localPhotos: LocalPhotoSettingsController
    @AppStorage(AppPreferenceKey.albumName)
    private var albumName = AppDistribution.current.defaultAlbumName
    @AppStorage(AppPreferenceKey.saveLocation) private var saveLocation = false
    @State private var errorMessage: LocalizedMessage?
    @State private var photosAuthorizationStatus = PhotoLibraryService.authorizationStatus()
    @State private var photosAlbumNames: [String] = []
    @State private var isLoadingPhotosAlbums = false
    @State private var isShowingNewAlbumSheet = false
    @State private var newAlbumName = ""
    @State private var isCreatingPhotosAlbum = false
    @State private var locationAuthorizationStatus = CLLocationManager().authorizationStatus

    var body: some View {
        SettingsPage(title: L10n.string("settings.photos.section"), subtitle: L10n.string("Choose where your Chameos live."), spacing: 8) {
            SettingsGroup(title: L10n.string("Album")) {
                HStack {
                    SettingsLabel(title: L10n.string("Album"),
                                  description: L10n.string("Used for new captures and Library."))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityHidden(true)
                    Picker(L10n.string("Album"), selection: $albumName) {
                        ForEach(albumChoices, id: \.self) { albumName in Text(albumName).tag(albumName) }
                    }
                    .labelsHidden().fixedSize()
                    .accessibilityLabel(L10n.string("Album"))
                    .accessibilityValue(albumName)
                    .accessibilityHint(L10n.string("Saves new photos here and shows them in Library."))
                }
                .disabled(albumChoices.isEmpty || isLoadingPhotosAlbums)

                HStack {
                    if isLoadingPhotosAlbums {
                        ProgressView()
                            .controlSize(.small)
                            .accessibilityLabel(L10n.string("Loading Photos albums"))
                    }

                    Button {
                        errorMessage = nil
                        newAlbumName = defaultNewAlbumName
                        isShowingNewAlbumSheet = true
                    } label: {
                        Label(L10n.string("New Album…"), systemImage: "plus")
                    }
                    .disabled(isCreatingPhotosAlbum || !canReadPhotosAlbums)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)

                if isPhotosPermissionDenied {
                    PermissionStatusInline(
                        message: L10n.string("Allow Photos access to save and view Chameos."),
                        destination: .photos
                    )
                } else if canReadPhotosAlbums && albumChoices.count == 1 && photosAlbumNames.isEmpty {
                    Text(L10n.string("No existing albums found. Chameo will create one when you save a photo."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            LocalPhotoSettingsView()

            SettingsGroup(title: L10n.string("Location")) {
                SettingsToggle(title: L10n.string("Add Location to Photos"),
                    description: L10n.string("Saves geographic coordinates. Shared photos may include this location."),
                    isOn: $saveLocation)

                if saveLocation && isLocationPermissionDenied {
                    PermissionStatusInline(
                        message: L10n.string("Location access is off. Chameo will save photos without location data."),
                        destination: .location
                    )
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let errorMessage { SettingsErrorView(message: errorMessage.text) }
        }
        .sheet(isPresented: $isShowingNewAlbumSheet) { newAlbumSheet }
        .task { await refresh() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await refresh() } }
        }
        .onChange(of: errorMessage?.text) { _, text in
            if let text { AccessibilityAnnouncement.post(text, priority: .high) }
        }
    }

    private func refresh() async {
        refreshPermissionStatuses()
        await localPhotos.refresh()
        await refreshPhotosAlbums()
    }

    private var newAlbumSheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.string("New Photos Album"))
                .font(.headline)

            Text(L10n.string("Album name"))
                .font(.subheadline.weight(.semibold))

            TextField(L10n.string("Album name"), text: $newAlbumName)
                .textFieldStyle(.roundedBorder)
                .disabled(isCreatingPhotosAlbum)
                .onSubmit {
                    guard canCreatePhotosAlbum else {
                        return
                    }

                    Task {
                        await createPhotosAlbum()
                    }
                }

            if isDuplicateNewAlbumName {
                Text(L10n.string("An album with this name already exists."))
                    .font(.caption)
                    .foregroundStyle(.red)
            } else if let errorMessage {
                Text(errorMessage.text)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            GlassEffectContainer(spacing: 12) {
                HStack(spacing: 12) {
                    if isCreatingPhotosAlbum {
                        ProgressView()
                            .controlSize(.small)
                            .accessibilityLabel(L10n.string("Creating Photos album"))
                    }

                    Spacer()

                    Button(L10n.string("Cancel")) {
                        isShowingNewAlbumSheet = false
                        newAlbumName = ""
                    }
                    .buttonStyle(.glass)
                    .disabled(isCreatingPhotosAlbum)
                    .keyboardShortcut(.cancelAction)

                    Button(L10n.string("Create")) {
                        Task {
                            await createPhotosAlbum()
                        }
                    }
                    .buttonStyle(.glassProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canCreatePhotosAlbum)
                }
            }
        }
        .padding()
        .frame(width: 340)
        .buttonBorderShape(.roundedRectangle(radius: ChameoLayout.cornerRadius))
    }

    private var albumChoices: [String] {
        var choices = [PhotoLibraryService.normalizedAlbumName(albumName)]
        choices.append(contentsOf: photosAlbumNames)

        var seen = Set<String>()
        return choices.filter { choice in
            seen.insert(choice).inserted
        }
    }

    private var normalizedNewAlbumName: String {
        newAlbumName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var defaultNewAlbumName: String {
        let defaultAlbumName = AppDistribution.current.defaultAlbumName
        return albumNameExists(defaultAlbumName) ? "" : defaultAlbumName
    }

    private var isDuplicateNewAlbumName: Bool {
        !normalizedNewAlbumName.isEmpty && albumNameExists(normalizedNewAlbumName)
    }

    private func albumNameExists(_ name: String) -> Bool {
        albumChoices.contains { existingName in
            existingName.trimmingCharacters(in: .whitespacesAndNewlines)
                .localizedCaseInsensitiveCompare(name) == .orderedSame
        }
    }

    private var canCreatePhotosAlbum: Bool {
        !normalizedNewAlbumName.isEmpty && !isDuplicateNewAlbumName && !isCreatingPhotosAlbum
    }

    private var canReadPhotosAlbums: Bool {
        switch photosAuthorizationStatus {
        case .authorized, .limited:
            return true
        default:
            return false
        }
    }

    private var isPhotosPermissionDenied: Bool {
        switch photosAuthorizationStatus {
        case .denied, .restricted:
            return true
        default:
            return false
        }
    }

    private var isLocationPermissionDenied: Bool {
        switch locationAuthorizationStatus {
        case .denied, .restricted:
            return true
        default:
            return false
        }
    }

    private func refreshPermissionStatuses() {
        photosAuthorizationStatus = PhotoLibraryService.authorizationStatus()
        locationAuthorizationStatus = CLLocationManager().authorizationStatus
    }

    private func refreshPhotosAlbums() async {
        guard !isLoadingPhotosAlbums else {
            return
        }

        errorMessage = nil
        photosAuthorizationStatus = PhotoLibraryService.authorizationStatus()

        switch PhotoLibraryService.authorizationStatus() {
        case .authorized, .limited:
            break
        default:
            photosAlbumNames = []
            photosAuthorizationStatus = PhotoLibraryService.authorizationStatus()
            return
        }

        isLoadingPhotosAlbums = true
        defer {
            isLoadingPhotosAlbums = false
            photosAuthorizationStatus = PhotoLibraryService.authorizationStatus()
        }

        do {
            photosAlbumNames = try await PhotoLibraryService.fetchAlbumNames()
        } catch {
            photosAlbumNames = []
            errorMessage = .error(error)
        }
    }

    private func createPhotosAlbum() async {
        guard canCreatePhotosAlbum else {
            return
        }

        let albumNameToCreate = normalizedNewAlbumName
        errorMessage = nil
        isCreatingPhotosAlbum = true
        defer {
            isCreatingPhotosAlbum = false
            photosAuthorizationStatus = PhotoLibraryService.authorizationStatus()
        }

        do {
            photosAlbumNames = try await PhotoLibraryService.fetchAlbumNames()
            guard !albumNameExists(albumNameToCreate) else {
                return
            }

            _ = try await PhotoLibraryService.createAlbum(named: albumNameToCreate)
            if let refreshedAlbumNames = try? await PhotoLibraryService.fetchAlbumNames() {
                photosAlbumNames = refreshedAlbumNames
            } else if !photosAlbumNames.contains(albumNameToCreate) {
                photosAlbumNames.append(albumNameToCreate)
                photosAlbumNames.sort { lhs, rhs in
                    lhs.localizedStandardCompare(rhs) == .orderedAscending
                }
            }
            albumName = albumNameToCreate
            newAlbumName = ""
            isShowingNewAlbumSheet = false
        } catch {
            errorMessage = .error(error)
        }
    }
}
