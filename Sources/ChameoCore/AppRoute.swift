public enum AppRoute: String, CaseIterable, Hashable, Identifiable, Sendable {
    case camera
    case library
    case settings

    public var id: String { rawValue }
}
