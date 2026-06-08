import CoreLocation
import Photos
import SwiftUI
import UserNotifications

struct SettingsView: View {
    @AppStorage("albumName") private var albumName = "Chameo"
    @AppStorage("showGrid") private var showFaceGuide = true
    @AppStorage("saveLocation") private var saveLocation = false
    @AppStorage("launchAtLogin") private var storedLaunchAtLogin = false
    @AppStorage("reminderDate") private var reminderDateTimeInterval = Date().timeIntervalSinceReferenceDate
    @AppStorage("reminderRepeat") private var reminderRepeatRawValue = ReminderRepeat.none.rawValue

    @State private var launchAtLogin = false
    @State private var reminderDate = Date()
    @State private var reminderRepeat = ReminderRepeat.none
    @State private var isUpdatingLaunchAtLogin = false
    @State private var isUpdatingReminder = false
    @State private var isLoadingSettings = true
    @State private var errorMessage: String?
    @State private var photosAuthorizationStatus = PhotoLibraryService.authorizationStatus()
    @State private var locationAuthorizationStatus = CLLocationManager().authorizationStatus
    @State private var notificationAuthorizationStatus = UNAuthorizationStatus.notDetermined

    var body: some View {
        TabView {
            Form {
                Section("Album") {
                    TextField("Album Name", text: $albumName)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            albumName = PhotoLibraryService.normalizedAlbumName(albumName)
                        }

                    if isPhotosPermissionDenied {
                        PermissionStatusInline(
                            message: "Photos permission is required to save and show Chameos.",
                            destination: .photos
                        )
                    }
                }

                Section("Camera") {
                    Toggle("Show Face Guide", isOn: $showFaceGuide)
                }

                Section("Location") {
                    Toggle("Save Photo Location", isOn: $saveLocation)

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
            }
            .formStyle(.grouped)
            .tabItem {
                Label("General", systemImage: "gearshape")
            }

            Form {
                Section("Reminder") {
                    DatePicker("Time", selection: $reminderDate, displayedComponents: .hourAndMinute)
                        .disabled(isUpdatingReminder)

                    Picker("Repeats", selection: $reminderRepeat) {
                        ForEach(ReminderRepeat.allCases) { repeatMode in
                            Text(repeatMode.title).tag(repeatMode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .disabled(isUpdatingReminder)
                }

                if isUpdatingReminder {
                    ProgressView("Updating Reminder…")
                }

                if isNotificationPermissionDenied {
                    PermissionStatusInline(
                        message: "Notification permission is required to schedule reminders.",
                        destination: .notifications
                    )
                }
            }
            .formStyle(.grouped)
            .tabItem {
                Label("Reminder", systemImage: "bell")
            }
        }
        .frame(width: 460, height: 300)
        .scenePadding()
        .safeAreaInset(edge: .bottom) {
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }
        }
        .onAppear {
            isLoadingSettings = true
            launchAtLogin = LaunchAtLoginService.isEnabled
            storedLaunchAtLogin = launchAtLogin
            reminderDate = Date(timeIntervalSinceReferenceDate: reminderDateTimeInterval)
            reminderRepeat = ReminderRepeat(rawValue: reminderRepeatRawValue) ?? .none
            isLoadingSettings = false

            Task {
                await refreshPermissionStatuses()
            }
        }
        .onChange(of: launchAtLogin) { _, newValue in
            guard !isLoadingSettings else {
                return
            }
            guard newValue != LaunchAtLoginService.isEnabled else {
                return
            }

            Task {
                await updateLaunchAtLogin(newValue)
            }
        }
        .onChange(of: reminderDate) { _, newValue in
            guard !isLoadingSettings else {
                return
            }
            guard abs(newValue.timeIntervalSinceReferenceDate - reminderDateTimeInterval) > 1 else {
                return
            }

            reminderDateTimeInterval = newValue.timeIntervalSinceReferenceDate
            Task {
                await updateReminder()
            }
        }
        .onChange(of: reminderRepeat) { _, newValue in
            guard !isLoadingSettings else {
                return
            }
            guard newValue.rawValue != reminderRepeatRawValue else {
                return
            }

            reminderRepeatRawValue = newValue.rawValue
            Task {
                await updateReminder()
            }
        }
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

    private func updateReminder() async {
        errorMessage = nil
        isUpdatingReminder = true

        do {
            try await ReminderService.configureReminder(date: reminderDate, repeatMode: reminderRepeat)
            notificationAuthorizationStatus = await ReminderService.authorizationStatus()
        } catch {
            notificationAuthorizationStatus = await ReminderService.authorizationStatus()
            errorMessage = error.localizedDescription
        }

        isUpdatingReminder = false
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

    private var isNotificationPermissionDenied: Bool {
        switch notificationAuthorizationStatus {
        case .denied:
            return true
        default:
            return false
        }
    }

    private func refreshPermissionStatuses() async {
        photosAuthorizationStatus = PhotoLibraryService.authorizationStatus()
        locationAuthorizationStatus = CLLocationManager().authorizationStatus
        notificationAuthorizationStatus = await ReminderService.authorizationStatus()
    }
}
