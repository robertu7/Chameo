import AppKit
import SwiftUI
import XCTest
@testable import Chameo

@MainActor
final class PhotoDeletionConfirmationTests: XCTestCase {
    func testConsequencesAndControlsFitTheInlinePreviewInEveryLanguage() throws {
        let previous = UserDefaults.standard.object(forKey: AppPreferenceKey.language)
        defer {
            if let previous { UserDefaults.standard.set(previous, forKey: AppPreferenceKey.language) }
            else { UserDefaults.standard.removeObject(forKey: AppPreferenceKey.language) }
        }
        let directory = URL(fileURLWithPath: "/private/tmp/chameo-photo-policy-previews")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        // The calendar is 420 points wide, with 14-point outer and 12-point inner insets.
        let width = ChameoLayout.contentWidth - 2 * (ChameoLayout.outerInset + ChameoLayout.sectionSpacing)
        for language in [AppLanguage.english, .simplifiedChinese, .traditionalChinese] {
            UserDefaults.standard.set(language.rawValue, forKey: AppPreferenceKey.language)
            let confirmation = PhotoDeletionConfirmationView(trashLocalCopy: .constant(false),
                                                             onDelete: {}, onCancel: {})
                .frame(width: width)
                .environment(\.locale, L10n.currentLocalization.displayLocale)
            let sizingView = NSHostingView(rootView: confirmation)
            XCTAssertLessThanOrEqual(sizingView.fittingSize.height, 96,
                                     "Deletion consequences and controls must fit for \(language.rawValue)")

            let rect = NSRect(x: 0, y: 0, width: width, height: 96)
            let hosting = NSHostingView(rootView: confirmation.frame(height: 96)
                .background(Color(nsColor: .controlBackgroundColor)))
            let window = NSWindow(contentRect: rect, styleMask: .borderless, backing: .buffered, defer: false)
            window.contentView = hosting
            hosting.frame = rect
            hosting.layoutSubtreeIfNeeded()
            hosting.displayIfNeeded()
            let bitmap = try XCTUnwrap(hosting.bitmapImageRepForCachingDisplay(in: rect))
            hosting.cacheDisplay(in: rect, to: bitmap)
            let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
            try png.write(to: directory.appendingPathComponent(language.rawValue + ".png"))
        }
    }
}
