import SwiftUI

/// Scrollable content keeps expanded explanations and recovery actions accessible at a fixed size.
struct SettingsPage<Content: View>: View {
    let title: String
    let subtitle: String
    var spacing: CGFloat = 12
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: spacing) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 22, weight: .semibold))
                        .accessibilityAddTraits(.isHeader)
                    Text(subtitle).foregroundStyle(.secondary)
                }
                .padding(.bottom, 16)
                content
            }
            .font(.body)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(.background)
        .buttonStyle(.glass)
        .buttonBorderShape(.roundedRectangle(radius: 8))
        .toggleStyle(.switch)
    }
}

struct SettingsGroup<Content: View>: View {
    var title: String? = nil
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title {
                Text(title).font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 4)
                    .accessibilityAddTraits(.isHeader)
            }
            VStack(alignment: .leading, spacing: 6) { content }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
        }
    }
}
