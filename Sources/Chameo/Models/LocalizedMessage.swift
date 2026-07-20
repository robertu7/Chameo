import Foundation

struct LocalizedMessage {
    private let resolver: () -> String

    var text: String {
        resolver()
    }

    static func localized(_ key: String) -> LocalizedMessage {
        LocalizedMessage {
            L10n.string(key)
        }
    }

    static func formatted(_ key: String, _ argument: String) -> LocalizedMessage {
        LocalizedMessage {
            L10n.format(key, argument)
        }
    }

    static func error(_ error: any Error) -> LocalizedMessage {
        LocalizedMessage {
            error.localizedDescription
        }
    }
}
