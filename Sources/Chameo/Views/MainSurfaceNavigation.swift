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
                Menu {
                    Button(L10n.string("Settings…"), systemImage: "gearshape", action: onOpenSettings)
                        .keyboardShortcut(",", modifiers: .command)
                    Divider()
                    Button(L10n.string("Quit Chameo"), systemImage: "power") {
                        NSApplication.shared.terminate(nil)
                    }
                    .keyboardShortcut("q", modifiers: .command)
                } label: {
                    Label {
                        Text(L10n.string("App Menu"))
                    } icon: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.primary)
                            .frame(width: 28, height: 28)
                    }
                }
                .labelStyle(.iconOnly)
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .frame(width: ChameoLayout.compactControlSize, height: ChameoLayout.compactControlSize)
                .contentShape(Circle())
                .chameoGlassControl(in: Circle())
                .overlay {
                    Circle().strokeBorder(.secondary.opacity(0.45), lineWidth: 1)
                }
                .help(L10n.string("App Menu"))
            }
            .padding(.horizontal, ChameoLayout.outerInset)
        }
    }

}
