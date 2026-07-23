import CoreLocation
import Photos
import SwiftUI

struct GeneralSettingsView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var localizationController: LocalizationController
    @EnvironmentObject private var updateController: UpdateController
    @AppStorage(AppPreferenceKey.albumName) private var albumName = "Chameo"
    @AppStorage(AppPreferenceKey.handsFreeCountdown) private var handsFreeCountdown = false
    @AppStorage(AppPreferenceKey.showFaceGuide) private var showFaceGuide = true
    @AppStorage(AppPreferenceKey.autoAlignPhotos) private var autoAlignPhotos = true
    @AppStorage(AppPreferenceKey.saveLocation) private var saveLocation = false
    @AppStorage(AppPreferenceKey.launchAtLogin) private var storedLaunchAtLogin = false

    @State private var launchAtLogin = false
    @State private var isUpdatingLaunchAtLogin = false
    @State private var isLoadingSettings = true
    @State private var errorMessage: LocalizedMessage?
    @State private var photosAuthorizationStatus = PhotoLibraryService.authorizationStatus()
    @State private var photosAlbumNames: [String] = []
    @State private var isLoadingPhotosAlbums = false
    @State private var isShowingNewAlbumSheet = false
    @State private var newAlbumName = ""
    @State private var isCreatingPhotosAlbum = false
    @State private var locationAuthorizationStatus = CLLocationManager().authorizationStatus

    var body: some View {
        Form {
            Section(L10n.string("Capture")) {
                SettingsToggle(
                    title: L10n.string("Framing Guide"),
                    description: L10n.string("Helps position your face with live guidance."),
                    isOn: $showFaceGuide
                )

                if showFaceGuide {
                    SettingsToggle(
                        title: L10n.string("Auto Capture"),
                        description: L10n.string(
                            "Captures after a three-second countdown when framing is ready."
                        ),
                        isOn: $handsFreeCountdown
                    )
                }

                SettingsToggle(
                    title: L10n.string("Face Alignment"),
                    description: L10n.string(
                        "Straightens and crops photos for consistent framing."
                    ),
                    isOn: $autoAlignPhotos
                )

                Button {
                    resetCaptureSettings()
                } label: {
                    Label(
                        L10n.string("Reset to Defaults"),
                        systemImage: "arrow.counterclockwise"
                    )
                }
                .disabled(isUsingDefaultCaptureSettings)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }

            ReminderSettingsView()

            Section(L10n.string("settings.photos.section")) {
                Picker(selection: $albumName) {
                    ForEach(albumChoices, id: \.self) { albumName in
                        Text(albumName).tag(albumName)
                    }
                } label: {
                    SettingsLabel(
                        title: L10n.string("Album"),
                        description: L10n.string(
                            "Saves new photos here and shows them in Library."
                        )
                    )
                }
                .disabled(albumChoices.isEmpty || isLoadingPhotosAlbums)
                .accessibilityHint(
                    L10n.string(
                        "Saves new photos here and shows them in Library."
                    )
                )

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
                Toggle(L10n.string("Add Location to Photos"), isOn: $saveLocation)

                if saveLocation && isLocationPermissionDenied {
                    PermissionStatusInline(
                        message: L10n.string("Location access is off. Chameo will save photos without location data."),
                        destination: .location
                    )
                }
            }

            Section {
                Picker(
                    L10n.string("settings.language.picker"),
                    selection: languageBinding
                ) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.pickerTitle).tag(language)
                    }
                }

                Toggle(L10n.string("Launch at Login"), isOn: $launchAtLogin)
                    .disabled(isUpdatingLaunchAtLogin)

                Toggle(
                    L10n.string("Automatically Check for Updates"),
                    isOn: automaticUpdateChecksBinding
                )

                Button(L10n.string("Check for Updates…")) {
                    updateController.checkForUpdates()
                }
                .disabled(!updateController.canCheckForUpdates)
                .frame(maxWidth: .infinity, alignment: .trailing)
            } header: {
                Text(L10n.string("App"))
            } footer: {
                Text(
                    L10n.format(
                        "Version %@ · Build %@",
                        AppVersion.current.version,
                        AppVersion.current.buildID
                    )
                )
            }
        }
        .formStyle(.grouped)
        .safeAreaInset(edge: .bottom) {
            if let errorMessage {
                settingsError(errorMessage.text)
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
                await refreshPhotosAlbums()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else {
                return
            }

            Task {
                refreshPermissionStatuses()
                await refreshPhotosAlbums()
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

    private var languageBinding: Binding<AppLanguage> {
        Binding(
            get: { localizationController.preference },
            set: { localizationController.select($0) }
        )
    }

    private var automaticUpdateChecksBinding: Binding<Bool> {
        Binding(
            get: { updateController.automaticallyChecksForUpdates },
            set: { updateController.setAutomaticallyChecksForUpdates($0) }
        )
    }

    private var isUsingDefaultCaptureSettings: Bool {
        showFaceGuide && !handsFreeCountdown && autoAlignPhotos
    }

    private func resetCaptureSettings() {
        showFaceGuide = true
        handsFreeCountdown = false
        autoAlignPhotos = true
    }

    private var newAlbumSheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.string("New Photos Album"))
                .font(.headline)

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

            HStack {
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
                .disabled(isCreatingPhotosAlbum)

                Button(L10n.string("Create")) {
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
                errorMessage = .localized("Open System Settings → General → Login Items, then allow Chameo.")
            }
            launchAtLogin = LaunchAtLoginService.isEnabled
            storedLaunchAtLogin = launchAtLogin
        } catch {
            launchAtLogin = LaunchAtLoginService.isEnabled
            storedLaunchAtLogin = launchAtLogin
            errorMessage = .error(error)
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

private struct SettingsToggle: View {
    let title: String
    let description: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            SettingsLabel(title: title, description: description)
        }
        .accessibilityHint(description)
    }
}

private struct SettingsLabel: View {
    let title: String
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
