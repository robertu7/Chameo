import AppKit
import SwiftUI
import Photos
import CoreLocation
import XCTest
@testable import Chameo

/// Opt-in native layout previews; never starts a camera or changes system appearance.
@MainActor
final class ModernUIRenderTests: XCTestCase {
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
