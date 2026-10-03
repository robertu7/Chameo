import SwiftUI

struct TabPicker: View {
    @Binding var selection: ChameoTab
    @FocusState private var focusedTab: ChameoTab?
    @State private var hoveredTab: ChameoTab?
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        HStack(spacing: 2) {
            ForEach(ChameoTab.allCases) { tab in
                Button {
                    selection = tab
                } label: {
                    Label(tab.title, systemImage: tab.systemImage)
                        .labelStyle(.titleAndIcon)
                        .font(.system(size: 13, weight: selection == tab ? .medium : .regular))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, minHeight: 30)
                        .contentShape(RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(.plain)
                .background {
                    if selection == tab {
                        RoundedRectangle(cornerRadius: 7)
                            .fill(Color(nsColor: .controlBackgroundColor))
                            .shadow(color: .black.opacity(0.12), radius: 2, y: 1)
                    } else if hoveredTab == tab {
                        RoundedRectangle(cornerRadius: 7).fill(.primary.opacity(0.05))
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 7)
                        .strokeBorder(focusedTab == tab ? Color.accentColor : .clear, lineWidth: 2)
                }
                .focused($focusedTab, equals: tab)
                .onHover { hoveredTab = $0 ? tab : nil }
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(selection == tab ? .isSelected : [])
            }
        }
        .padding(2)
        .background(.quaternary.opacity(0.7), in: RoundedRectangle(cornerRadius: 9))
        .overlay {
            RoundedRectangle(cornerRadius: 9)
                .strokeBorder(.primary.opacity(contrast == .increased ? 0.5 : 0), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L10n.string("View"))
        .onMoveCommand { direction in
            switch direction {
            case .left: selection = .camera
            case .right: selection = .library
            default: return
            }
            focusedTab = selection
        }
    }
}
