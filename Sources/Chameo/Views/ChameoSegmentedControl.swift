import SwiftUI

struct ChameoSegmentedControl<Option: Hashable & Identifiable>: View {
    let options: [Option]
    @Binding var selection: Option
    let title: (Option) -> String
    var systemImage: ((Option) -> String)? = nil
    var cornerRadius: CGFloat = 7
    let accessibilityTitle: String
    @FocusState private var focusedTab: Option?
    @State private var hoveredTab: Option?
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options) { tab in
                Button {
                    selection = tab
                } label: {
                    Group {
                        if let systemImage {
                            Label(title(tab), systemImage: systemImage(tab)).labelStyle(.titleAndIcon)
                        } else {
                            Text(title(tab))
                        }
                    }
                        .font(.system(size: 13, weight: selection == tab ? .medium : .regular))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, minHeight: 30)
                        .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
                }
                .buttonStyle(.plain)
                .background {
                    if selection == tab {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(Color(nsColor: .controlBackgroundColor))
                            .shadow(color: .black.opacity(0.12), radius: 2, y: 1)
                    } else if hoveredTab == tab {
                        RoundedRectangle(cornerRadius: cornerRadius).fill(.primary.opacity(0.05))
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(focusedTab == tab ? Color.accentColor : .clear, lineWidth: 2)
                }
                .focused($focusedTab, equals: tab)
                .onHover { hoveredTab = $0 ? tab : nil }
                .accessibilityLabel(title(tab))
                .accessibilityAddTraits(selection == tab ? .isSelected : [])
            }
        }
        .padding(2)
        .background(.quaternary.opacity(0.7), in: RoundedRectangle(cornerRadius: cornerRadius + 2))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius + 2)
                .strokeBorder(.primary.opacity(contrast == .increased ? 0.5 : 0), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityTitle)
        .onMoveCommand { direction in
            guard let index = options.firstIndex(of: selection) else { return }
            let next: Int
            switch direction {
            case .left: next = max(0, index - 1)
            case .right: next = min(options.count - 1, index + 1)
            default: return
            }
            selection = options[next]
            focusedTab = selection
        }
    }
}
