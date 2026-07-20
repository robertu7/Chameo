import CoreLocation
import Photos
import SwiftUI

struct GeneralSettingsView: View {
    @AppStorage(AppPreferenceKey.albumName) private var albumName = "Chameo"
    @AppStorage(AppPreferenceKey.handsFreeCountdown) private var handsFreeCountdown = false
    @AppStorage(AppPreferenceKey.showFaceGuide) private var showFaceGuide = true
    @AppStorage(AppPreferenceKey.autoAlignPhotos) private var autoAlignPhotos = true
    @AppStorage(AppPreferenceKey.saveLocation) private var saveLocation = false
    @AppStorage(AppPreferenceKey.launchAtLogin) private var storedLaunchAtLogin = false

    @State private var launchAtLogin = false
    @State private var isUpdatingLaunchAtLogin = false
    @State private var isLoadingSettings = true
    @State private var errorMessage: String?
    @State private var photosAuthorizationStatus = PhotoLibraryService.authorizationStatus()
    @State private var photosAlbumNames: [String] = []
    @State private var isLoadingPhotosAlbums = false
    @State private var isShowingNewAlbumSheet = false
    @State private var newAlbumName = ""
    @State private var isCreatingPhotosAlbum = false
    @State private var locationAuthorizationStatus = CLLocationManager().authorizationStatus

    var body: some View {
        Form {
            Section("Photos Album") {
                Picker("Album", selection: $albumName) {
                    ForEach(albumChoices, id: \.self) { albumName in
                        Text(albumName).tag(albumName)
                    }
                }
                .disabled(albumChoices.isEmpty || isLoadingPhotosAlbums)

                Text("Saves and shows Chameos from this Photos album.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    if isLoadingPhotosAlbums {
                        ProgressView()
                            .controlSize(.small)
                            .accessibilityLabel("Loading Photos albums")
                    }

                    Spacer()

                    Button {
                        Task {
                            await refreshPhotosAlbums(requestAuthorization: true)
                        }
                    } label: {
                        Label("Refresh Albums", systemImage: "arrow.clockwise")
                    }
                    .disabled(isLoadingPhotosAlbums || isCreatingPhotosAlbum)

                    Button {
                        errorMessage = nil
                        newAlbumName = defaultNewAlbumName
                        isShowingNewAlbumSheet = true
                    } label: {
                        Label("New Album...", systemImage: "plus")
                    }
                    .disabled(isCreatingPhotosAlbum)
                }

                if isPhotosPermissionDenied {
                    PermissionStatusInline(
                        message: "Photos permission is required to save and show Chameos.",
                        destination: .photos
                    )
                } else if canReadPhotosAlbums && albumChoices.count == 1 && photosAlbumNames.isEmpty {
                    Text("No Photos albums found.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Camera") {
                Toggle("Show Face Guide", isOn: $showFaceGuide)
                Toggle("Hands-Free Countdown", isOn: $handsFreeCountdown)
                    .disabled(!showFaceGuide)

                Text("Starts a silent 3-second countdown when framing is Ready.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle("Auto Align Photos", isOn: $autoAlignPhotos)
            }

            Section("Location") {
                Toggle("Save Location with Photo", isOn: $saveLocation)

                if saveLocation && isLocationPermissionDenied {
                    PermissionStatusInline(
                        message: "Location permission is off. Photos will save without location.",
                        destination: .location
                    )
                }
            }

            Section("Startup") {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .disabled(isUpdatingLaunchAtLogin)
            }

            Section("About") {
                LabeledContent("Version", value: AppVersion.current.version)
                LabeledContent("Build ID", value: AppVersion.current.buildID)
            }
        }
        .formStyle(.grouped)
        .safeAreaInset(edge: .bottom) {
            if let errorMessage {
                settingsError(errorMessage)
            }
        }
        .sheet(isPresented: $isShowingNewAlbumSheet) {
            newAlbumSheet
        }
        .onAppear {
            isLoadingSettings = true
            launchAtLogin = LaunchAtLoginService.isEnabled
            storedLaunchAtLogin = launchAtLogin
            isLoadingSettings = false

            Task {
                refreshPermissionStatuses()
                await refreshPhotosAlbums(requestAuthorization: false)
            }
        }
        .onChange(of: launchAtLogin) { _, newValue in
            guard !isLoadingSettings, newValue != LaunchAtLoginService.isEnabled else {
                return
            }

            Task {
                await updateLaunchAtLogin(newValue)
            }
        }
    }

    private var newAlbumSheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("New Photos Album")
                .font(.headline)

            TextField("Album name", text: $newAlbumName)
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
                Text("An album with this name already exists.")
                    .font(.caption)
                    .foregroundStyle(.red)
            } else if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                if isCreatingPhotosAlbum {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel("Creating Photos album")
                }

                Spacer()

                Button("Cancel") {
                    isShowingNewAlbumSheet = false
                    newAlbumName = ""
                }
                .disabled(isCreatingPhotosAlbum)

                Button("Create") {
                    Task {
                        await createPhotosAlbum()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canCreatePhotosAlbum)
            }
        }
        .padding()
        .frame(width: 340)
    }

    private func settingsError(_ message: String) -> some View {
        Text(message)
            .font(.caption)
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.bottom, 8)
    }

    private func updateLaunchAtLogin(_ isEnabled: Bool) async {
        errorMessage = nil
        isUpdatingLaunchAtLogin = true

        do {
            try LaunchAtLoginService.setEnabled(isEnabled)
            if isEnabled && LaunchAtLoginService.requiresApproval {
                errorMessage = "Allow Chameo in System Settings > General > Login Items."
            }
            launchAtLogin = LaunchAtLoginService.isEnabled
            storedLaunchAtLogin = launchAtLogin
        } catch {
            launchAtLogin = LaunchAtLoginService.isEnabled
            storedLaunchAtLogin = launchAtLogin
            errorMessage = error.localizedDescription
        }

        isUpdatingLaunchAtLogin = false
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
        albumNameExists("Chameo") ? "" : "Chameo"
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

    private func refreshPhotosAlbums(requestAuthorization: Bool) async {
        errorMessage = nil
        photosAuthorizationStatus = PhotoLibraryService.authorizationStatus()

        if requestAuthorization {
            do {
                try await PhotoLibraryService.ensureAuthorized()
            } catch {
                photosAuthorizationStatus = PhotoLibraryService.authorizationStatus()
                errorMessage = error.localizedDescription
                return
            }
        }

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
            errorMessage = error.localizedDescription
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
            errorMessage = error.localizedDescription
        }
    }
}
