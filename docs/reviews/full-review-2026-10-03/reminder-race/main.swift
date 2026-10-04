import Foundation
@preconcurrency import UserNotifications

struct AppDistribution { static let current = Self(); let bundleIdentifier = "review.race" }
enum AppPreferenceKey { static let lastSelfieDate = "review.lastSelfieDate" }
enum L10n {
    static let currentLocalization = AppLocalization()
    static func string(_ value: String, localization: AppLocalization = .init()) -> String { value }
}
struct AppLocalization {}
struct StoredReminderSettings {
    let isEnabled: Bool
    let date: Date
    let repeatMode: ReminderRepeat
    let weekday: Int
    let lastSelfieDate: Date? = nil
    static func load() -> Self { ReproSettings.shared.load() }
}
final class ReproSettings: @unchecked Sendable {
    static let shared = ReproSettings()
    private let lock = NSLock()
    private var enabled = false
    private var reads = 0
    func load() -> StoredReminderSettings {
        lock.lock(); defer { lock.unlock() }
        reads += 1
        print("LOAD enabled=\(enabled)")
        return .init(isEnabled: enabled, date: Date().addingTimeInterval(86400), repeatMode: .daily, weekday: 1)
    }
    func enable() { lock.lock(); enabled = true; lock.unlock(); print("UI committed enabled=true") }
    func readCount() -> Int { lock.lock(); defer {lock.unlock()}; return reads }
}
actor ReproCenter: ReminderNotificationCenter {
    static let shared = ReproCenter()
    var pending: [String] = []
    var authorization: CheckedContinuation<Bool, Never>?
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        print("CONFIG awaiting authorization")
        return await withCheckedContinuation { authorization = $0 }
    }
    func isAuthorizationWaiting() -> Bool { authorization != nil }
    func authorize() { authorization?.resume(returning: true); authorization = nil }
    func add(_ request: UNNotificationRequest) { pending.append(request.identifier) }
    func pendingReminderNotificationIdentifiers() -> [String] { pending }
    func deliveredReminderNotificationIdentifiers() -> [String] { [] }
    func removePendingReminderNotifications(withIdentifiers identifiers: [String]) {
        print("REFRESH removing \(identifiers.count) pending requests")
        pending.removeAll { identifiers.contains($0) }
    }
    func removeDeliveredReminderNotifications(withIdentifiers identifiers: [String]) {}
}
Task { @MainActor in
    let ui = Task { @MainActor in
        do {
            try await ReminderService.configureReminder(date: Date().addingTimeInterval(86400), repeatMode: .daily)
            ReproSettings.shared.enable()
        } catch { print(error) }
    }
    while !(await ReproCenter.shared.isAuthorizationWaiting()) { await Task.yield() }
    let refresh = Task { await ReminderService.refreshRemindersFromStoredSettings(now: Date(), center: ReproCenter.shared) }
    while ReproSettings.shared.readCount() == 0 { await Task.yield() }
    await ReproCenter.shared.authorize()
    await ui.value
    await refresh.value
    let pending = await ReproCenter.shared.pendingReminderNotificationIdentifiers()
    print("FINAL storedEnabled=\(StoredReminderSettings.load().isEnabled), pending=\(pending.count)")
    exit(0)
}
dispatchMain()
