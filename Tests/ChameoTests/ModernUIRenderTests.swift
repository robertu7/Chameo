import AppKit
import SwiftUI
import Photos
import CoreLocation
import XCTest
@testable import Chameo

/// Opt-in native layout previews; never starts a camera or changes system appearance.
@MainActor
final class ModernUIRenderTests: XCTestCase {
    func testRenderReminderEditors() async throws {
        guard let path = ProcessInfo.processInfo.environment["CHAMEO_UI_PREVIEW_DIR"] else {
            throw XCTSkip("Set CHAMEO_UI_PREVIEW_DIR to export native layout previews.")
        }
        let directory = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let previousLanguage = UserDefaults.standard.object(forKey: AppPreferenceKey.language)
        defer {
            if let previousLanguage {
                UserDefaults.standard.set(previousLanguage, forKey: AppPreferenceKey.language)
            } else {
                UserDefaults.standard.removeObject(forKey: AppPreferenceKey.language)
            }
        }
        let date = Calendar.current.date(from:
            DateComponents(year: 2026, month: 10, day: 5, hour: 9, minute: 30))!
        for language in [AppLanguage.english, .simplifiedChinese, .traditionalChinese] {
            UserDefaults.standard.set(language.rawValue, forKey: AppPreferenceKey.language)
            for (name, appearanceName) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
                let appearance = NSAppearance(named: appearanceName)!
                let prefix = language.rawValue + "-" + name
                for component in [ReminderDateTimeComponent.date, .time] {
                    let editor = ReminderDateTimeEditor(
                        draft: .constant(ReminderDateTimeDraft(date: date, locale: L10n.currentLocalization.displayLocale)), component: component,
                        repeatMode: component == .date ? .none : .daily,
                        onCancel: {}, onDone: {})
                        .environment(\.locale, L10n.currentLocalization.displayLocale)
                    try await render(editor,
                        size: NSSize(width: 332, height: component == .date ? 450 : 240),
                        appearance: appearance,
                        to: directory.appendingPathComponent(prefix + (component == .date ? "-date-editor.png" : "-time-editor.png")))
                }
                let rows = SettingsPage(title: L10n.string("Reminders"),
                    subtitle: L10n.string("A gentle nudge for your daily photo.")) {
                    SettingsGroup {
                        HStack {
                            Text(L10n.string("Date"))
                            Spacer()
                            ReminderDateTimePicker(selection: .constant(date), component: .date, repeatMode: .none)
                        }
                        Divider()
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L10n.string("Time"))
                                Text(L10n.format("Next reminder: %@", DateFormatters.reminderPreview.string(from: date)))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            ReminderDateTimePicker(selection: .constant(date), component: .time, repeatMode: .none)
                        }
                    }
                }
                try await render(rows, size: NSSize(width: 480, height: 250), appearance: appearance,
                    to: directory.appendingPathComponent(prefix + "-reminder-controls.png"))
                let weekly = SettingsPage(title: L10n.string("Reminders"),
                    subtitle: L10n.string("A gentle nudge for your daily photo.")) {
                    SettingsGroup {
                        HStack {
                            Text(L10n.string("Frequency"))
                            Spacer()
                            Picker(L10n.string("Frequency"), selection: .constant(ReminderRepeat.weekly)) {
                                ForEach(ReminderRepeat.allCases) { Text($0.title).tag($0) }
                            }.labelsHidden().pickerStyle(.menu).fixedSize()
                        }
                        ReminderWeekdayPicker(selection: .constant(2))
                        Divider()
                        HStack {
                            Text(L10n.string("Time"))
                            Spacer()
                            ReminderDateTimePicker(selection: .constant(date), component: .time,
                                repeatMode: .weekly, weekday: 2)
                        }
                    }
                }.environment(\.locale, L10n.currentLocalization.displayLocale)
                try await render(weekly, size: NSSize(width: 480, height: 250), appearance: appearance,
                    to: directory.appendingPathComponent(prefix + "-weekly-reminder-controls.png"))
            }
        }
        UserDefaults.standard.set(AppLanguage.english.rawValue, forKey: AppPreferenceKey.language)
        for identifier in ["en_US", "en_GB"] {
            let locale = Locale(identifier: identifier)
            let valid = ReminderDateTimeDraft(date: date, locale: locale)
            var invalid = valid
            invalid.time.hourText = "99"
            invalid.time.minuteText = ""
            for (name, draft) in [("valid", valid), ("invalid", invalid)] {
                let editor = ReminderDateTimeEditor(draft: .constant(draft), component: .time,
                    repeatMode: .daily, onCancel: {}, onDone: {})
                    .environment(\.locale, locale)
                try await render(editor, size: NSSize(width: 332, height: 250),
                    appearance: NSAppearance(named: .aqua)!,
                    to: directory.appendingPathComponent(identifier + "-" + name + "-time-input.png"))
            }
        }
    }

    func testRenderModernScreensInAllLanguagesAndAppearances() async throws {
        guard let path = ProcessInfo.processInfo.environment["CHAMEO_UI_PREVIEW_DIR"] else {
            throw XCTSkip("Set CHAMEO_UI_PREVIEW_DIR to export native layout previews.")
        }
        guard Bundle.main.bundleURL.pathExtension == "app" else {
            throw XCTSkip("Run script/render_ui_previews.sh so native status queries have an app host.")
        }
        let directory = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let previousLanguage = UserDefaults.standard.object(forKey: AppPreferenceKey.language)
        defer {
            if let previousLanguage {
                UserDefaults.standard.set(previousLanguage, forKey: AppPreferenceKey.language)
            } else {
                UserDefaults.standard.removeObject(forKey: AppPreferenceKey.language)
            }
        }
        let suite = "ModernUIRenderTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: AppPreferenceKey.hasCompletedPermissionOnboarding)
        let fixture = try LocalPhotoFixture()
        defer { fixture.remove() }
        let localPhotos = LocalPhotoSettingsController(store: fixture.store)
        await localPhotos.refresh()
        defaults.set(true, forKey: AppPreferenceKey.reminderEnabled)
        defaults.set(ReminderRepeat.daily.rawValue, forKey: AppPreferenceKey.reminderRepeat)
        defaults.set(true, forKey: AppPreferenceKey.reminderSettingsMigrated)
        let updates = UpdateController(isEnabled: true)
        let day = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 2))!

        let guideStates: [(String, LiveFramingGuidanceState)] = [
            ("ready", .ready), ("eye-adjustment", .adjusting(.moveHigher)),
            ("hold-still", .adjusting(.holdStill)),
        ]
        for (name, guidance) in guideStates {
            let guides = HStack(spacing: 12) {
                ForEach([false, true], id: \.self) { dark in
                    ZStack {
                        dark ? Color.black : Color.white
                        CameraGuideView(guidanceState: guidance)
                    }
                    .frame(width: ChameoLayout.previewWidth, height: ChameoLayout.livePreviewHeight)
                }
            }.padding(12)
            try await render(guides, size: NSSize(width: 820, height: 373),
                appearance: NSAppearance(named: .aqua)!,
                to: directory.appendingPathComponent("camera-guide-" + name + ".png"))
        }

        for language in [AppLanguage.english, .simplifiedChinese, .traditionalChinese] {
            UserDefaults.standard.set(language.rawValue, forKey: AppPreferenceKey.language)
            let localization = LocalizationController()
            let appearances: [(String, NSAppearance.Name)] = [
                ("light", .aqua), ("dark", .darkAqua),
                ("contrast-light", .accessibilityHighContrastAqua),
                ("contrast-dark", .accessibilityHighContrastDarkAqua),
            ]
            for (appearanceTitle, appearanceName) in appearances {
                let name = language.rawValue + "-" + appearanceTitle
                let appearance = NSAppearance(named: appearanceName)!
                let state = AppState()
                state.selectedTab = .library
                state.visibleMainSurface = .popover
                state.selectedLibraryDay = day
                let library = LibraryStore(assetLoader: { _ in [] })
                await library.reload(albumName: "Preview")
                let export = TimelapseExportController(announce: { _ in })
                let camera = CameraService()
                let main = ContentView(captureReview: state.captureReview, surface: .popover, onOpenTimelapse: {}, onOpenSettings: {})
                    .environmentObject(state)
                    .environmentObject(library)
                    .environmentObject(export)
                    .environmentObject(camera)
                    .environmentObject(localization)
                    .environmentObject(updates)
                    .environmentObject(localPhotos)
                    .defaultAppStorage(defaults)
                try await render(main, size: NSSize(width: 448, height: 526), appearance: appearance,
                                 to: directory.appendingPathComponent(name + "-library.png"))
                state.selectedTab = .camera
                try await render(main, size: NSSize(width: 448, height: 526), appearance: appearance,
                                 to: directory.appendingPathComponent(name + "-camera-idle.png"))
                for category in SettingsCategory.allCases {
                    let settingsState = SettingsState()
                    settingsState.category = category
                    let settings = SettingsView(state: settingsState)
                        .environmentObject(localization)
                        .environmentObject(updates)
                        .environmentObject(localPhotos)
                        .defaultAppStorage(defaults)
                    try await render(settings, size: SettingsWindowController.minimumContentSize, appearance: appearance,
                        to: directory.appendingPathComponent(name + "-settings-" + category.rawValue + ".png"))
                }
                try await render(LocalCopyExplanation(folderPath: localPhotos.configuration.activeFolder?.displayPath),
                    size: NSSize(width: 320, height: 380), appearance: appearance,
                    to: directory.appendingPathComponent(name + "-local-copy-help.png"))
                for step in PermissionOnboardingStep.allCases {
                    let model = PermissionOnboardingModel(permissionProvider: PreviewPermissions())
                    let onboarding = PermissionOnboardingView(model: model, initialStep: step,
                        onContinue: {}, onQuit: {}, onPermissionRequestFinished: {})
                        .environmentObject(localization)
                        .environment(\.locale, localization.displayLocale)
                    try await render(onboarding, size: ChameoLayout.onboardingWindowSize, appearance: appearance,
                        to: directory.appendingPathComponent(name + "-onboarding-" + String(step.rawValue) + ".png"))
                }
                let imageURL = try XCTUnwrap(Bundle.module.url(forResource: "onboarding-portrait", withExtension: "png", subdirectory: "Onboarding"))
                let portrait = try XCTUnwrap(NSImage(contentsOf: imageURL))
                let preview = CapturedPreview(data: try XCTUnwrap(portrait.tiffRepresentation),
                    qualityEvaluation: .scored(0.9), qualitySuggestion: nil)
                let review = VStack(spacing: 0) {
                    MainSurfaceNavigation(selection: .constant(.camera), onOpenSettings: {}).frame(height: 66)
                    CapturedPreviewView(preview: preview, isSaving: false, photosPermissionDenied: false,
                        locationPermissionDenied: false, onRetake: {}, onKeep: {})
                    Text(L10n.string("Review your Chameo before saving."))
                        .font(.caption).foregroundStyle(.secondary).frame(height: 53)
                }
                try await render(review, size: NSSize(width: 448, height: 526), appearance: appearance,
                    to: directory.appendingPathComponent(name + "-camera-review.png"))
                for previewDay in [day, day.addingTimeInterval(-86400)] {
                    let assets = (0..<3).map { ChameoAsset(asset: PreviewPhoto(date: day.addingTimeInterval(-86400 + Double($0) * 60))) }
                    let calendar = CalendarLibraryView(snapshot: LibraryCalendarSnapshot(assets: assets, calendar: LibraryCalendarSnapshot.displayCalendar), selectedDay: .constant(previewDay),
                        isRefreshing: false, isExportingTimelapse: false, canSaveLocalCopy: true,
                        onTakeChameo: {}, onExportTimelapse: {}, onDelete: { _, _ in }, onSaveLocalCopy: { _ in },
                        thumbnailLoader: { _, _ in portrait })
                    let libraryPreview = VStack(spacing: 0) {
                        MainSurfaceNavigation(selection: .constant(.library), onOpenSettings: {}).frame(height: 66)
                        calendar.frame(width: ChameoLayout.contentWidth, height: ChameoLayout.contentHeight, alignment: .top)
                        Color.clear.frame(height: 53)
                    }
                    try await render(libraryPreview, size: NSSize(width: 448, height: 526), appearance: appearance,
                        to: directory.appendingPathComponent(name + (previewDay == day ? "-library-today.png" : "-library-captured.png")))
                }
                let overlay = HStack(spacing: 12) {
                    overlaySample(background: .white)
                    overlaySample(background: .black)
                }
                .padding(12)
                try await render(overlay, size: NSSize(width: 448, height: 200), appearance: appearance,
                                 to: directory.appendingPathComponent(name + "-overlays.png"))

            }
        }
    }

    private func overlaySample(background: Color) -> some View {
        GlassEffectContainer(spacing: 12) {
            ZStack {
                background
                VStack(spacing: 20) {
                    Label(L10n.string("Camera"), systemImage: "video")
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .chameoGlassControl(in: Capsule())
                    Text(L10n.string("Framing ready"))
                        .font(.caption).padding(8)
                        .chameoReadableSurface(in: Capsule())
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func render<V: View>(_ view: V, size: NSSize, appearance: NSAppearance, to url: URL) async throws {
        let rect = NSRect(origin: .zero, size: size)
        let hosting = NSHostingView(rootView: view.environment(\.colorScheme, appearance.name == .darkAqua || appearance.name == .accessibilityHighContrastDarkAqua ? .dark : .light)
            .frame(width: size.width, height: size.height)
            .background(Color(nsColor: .windowBackgroundColor)))
        let window = NSWindow(contentRect: rect, styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        window.appearance = appearance
        window.contentView = hosting
        hosting.frame = rect
        hosting.layoutSubtreeIfNeeded()
        // Allow view tasks and native control layout to settle without starting real hardware.
        try await Task.sleep(for: .milliseconds(80))
        hosting.layoutSubtreeIfNeeded()
        hosting.displayIfNeeded()
        let bitmap = try XCTUnwrap(hosting.bitmapImageRepForCachingDisplay(in: rect))
        hosting.cacheDisplay(in: rect, to: bitmap)
        XCTAssertGreaterThanOrEqual(bitmap.pixelsWide, Int(size.width))
        XCTAssertGreaterThanOrEqual(bitmap.pixelsHigh, Int(size.height))
        try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: url)
    }
}

@MainActor
private final class PreviewPermissions: RequiredPermissionProviding {
    var cameraStatus: RequiredPermissionStatus { .authorized }
    var photosStatus: RequiredPermissionStatus { .notDetermined }
    func requestCameraAuthorization() async {}
    func requestPhotosAuthorization() async {}
}

private final class PreviewPhoto: PHAsset, @unchecked Sendable {
    private let date: Date
    private let identifier = UUID().uuidString
    init(date: Date) { self.date = date; super.init() }
    override var localIdentifier: String { identifier }
    override var creationDate: Date? { date }
    override var location: CLLocation? { nil }
}
