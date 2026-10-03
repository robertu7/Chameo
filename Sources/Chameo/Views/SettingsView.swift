import SwiftUI

struct SettingsView: View {
    @ObservedObject var state: SettingsState
    @EnvironmentObject private var localizationController: LocalizationController
    @AppStorage(AppPreferenceKey.hasCompletedPermissionOnboarding)
    private var hasCompletedPermissionOnboarding = false

    var body: some View {
        Group {
            if hasCompletedPermissionOnboarding {
                VStack(spacing: 0) {
                    ChameoSegmentedControl(options: SettingsCategory.allCases, selection: $state.category,
                        title: { $0.title }, cornerRadius: 16,
                        accessibilityTitle: L10n.string("Settings"))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                    RetainedSettingsPages(selection: $state.category) { category in
                        switch category {
                        case .general: GeneralSettingsView()
                        case .capture: CaptureSettingsView()
                        case .reminders: ReminderSettingsView()
                        case .photos: PhotosSettingsView()
                        }
                    }
                }
            } else {
                ContentUnavailableView {
                    Label(L10n.string("Finish Chameo Setup"), systemImage: "lock.fill")
                } description: {
                    Text(L10n.string("Allow Camera and Photos access in the Chameo welcome window before opening Settings."))
                }
            }
        }
        .environment(\.locale, localizationController.displayLocale)
    }

}

/// Mount pages on first visit, then keep their local form state while excluding hidden pages from input.
struct RetainedSettingsPages<Content: View>: View {
    @Binding var selection: SettingsCategory
    @State private var visited: Set<SettingsCategory>
    let content: (SettingsCategory) -> Content

    init(selection: Binding<SettingsCategory>, @ViewBuilder content: @escaping (SettingsCategory) -> Content) {
        self._selection = selection
        self._visited = State(initialValue: [selection.wrappedValue])
        self.content = content
    }

    var body: some View {
        ZStack {
            ForEach(SettingsCategory.allCases.filter { visited.contains($0) || $0 == selection }) { category in
                content(category)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .opacity(category == selection ? 1 : 0)
                    .disabled(category != selection)
                    .allowsHitTesting(category == selection)
                    .accessibilityHidden(category != selection)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .onChange(of: selection) { _, category in visited.insert(category) }
    }
}
