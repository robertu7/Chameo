import SwiftUI

/// App and photo menus share the same glyph, target, and native glass treatment.
struct ChameoMoreMenu<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        Menu {
            content
        } label: {
            Label(title, systemImage: "ellipsis")
                .labelStyle(.iconOnly)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: ChameoLayout.compactControlSize, height: ChameoLayout.compactControlSize)
                .contentShape(Circle())
                .chameoGlassControl(in: Circle())
        }
        // Keep the label's full circle as the target; borderless menus use a smaller native popup button.
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .help(title)
        .accessibilityLabel(title)
    }
}
