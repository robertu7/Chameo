import AppKit
import SwiftUI
import XCTest
@preconcurrency import UserNotifications
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
        let updates = UpdateController(isEnabled: false)
        let day = Calendar.current.date(from: DateComponents(year: 2026, month: 3, day: 15))!

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
                let export = TimelapseExportController(notifications: PreviewNotifications())
                let camera = CameraService()
                let main = ContentView(surface: .popover, onOpenTimelapse: {}, onOpenSettings: {})
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
                    try await render(settings, size: NSSize(width: 560, height: 480), appearance: appearance,
                        to: directory.appendingPathComponent(name + "-settings-" + category.rawValue + ".png"))
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
        let hosting = NSHostingView(rootView: view.frame(width: size.width, height: size.height)
            .background(Color(nsColor: .windowBackgroundColor)))
        let window = NSWindow(contentRect: rect, styleMask: .borderless, backing: .buffered, defer: false)
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
private final class PreviewNotifications: TimelapseNotifying {
    func authorizationStatus() async -> UNAuthorizationStatus { .denied }
    func prepareAuthorization() async -> UNAuthorizationStatus { .denied }
    func deliver(exportID: UUID, filename: String) async throws {}
}
