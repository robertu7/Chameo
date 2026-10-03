import AppKit
import SwiftUI

struct MainSurfaceNavigation: View {
    @Binding var selection: ChameoTab
    let onOpenSettings: () -> Void

    var body: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 12) {
                Color.clear.frame(width: ChameoLayout.compactControlSize)
                    .accessibilityHidden(true)
                Spacer(minLength: 0)
                TabPicker(selection: $selection)
                    .frame(width: 244)
                Spacer(minLength: 0)
                ChameoMoreMenu(title: L10n.string("App Menu")) {
                    Button(L10n.string("Settings…"), systemImage: "gearshape", action: onOpenSettings)
                        .keyboardShortcut(",", modifiers: .command)
                    Divider()
                    Button(L10n.string("Quit Chameo"), systemImage: "power") {
                        NSApplication.shared.terminate(nil)
                    }
                    .keyboardShortcut("q", modifiers: .command)
                }
            }
            .padding(.horizontal, ChameoLayout.outerInset)
        }
    }

}
