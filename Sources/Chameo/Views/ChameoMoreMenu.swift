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
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
        }
        .labelStyle(.iconOnly)
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: ChameoLayout.compactControlSize, height: ChameoLayout.compactControlSize)
        .contentShape(Circle())
        .chameoGlassControl(in: Circle())
        .help(title)
        .accessibilityLabel(title)
    }
}
