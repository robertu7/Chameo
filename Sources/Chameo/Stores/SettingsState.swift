import Combine

@MainActor
final class SettingsState: ObservableObject {
    @Published var category: SettingsCategory = .general
}
