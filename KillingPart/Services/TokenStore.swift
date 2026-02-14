import Foundation

protocol TokenStoring: AnyObject {
    var accessToken: String? { get }
    var refreshToken: String? { get }
    var hasSessionTokens: Bool { get }
    func save(accessToken: String, refreshToken: String)
    func clearTokens()
}

final class TokenStore: TokenStoring {
    static let shared = TokenStore()

    private enum Keys {
        static let accessToken = "auth.accessToken"
        static let refreshToken = "auth.refreshToken"
    }

    private let defaults: UserDefaults
    private let lock = NSLock()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var accessToken: String? {
        lock.withLock {
            defaults.string(forKey: Keys.accessToken)
        }
    }

    var refreshToken: String? {
        lock.withLock {
            defaults.string(forKey: Keys.refreshToken)
        }
    }

    var hasSessionTokens: Bool {
        lock.withLock {
            guard
                let accessToken = defaults.string(forKey: Keys.accessToken),
                let refreshToken = defaults.string(forKey: Keys.refreshToken)
            else {
                return false
            }

            return !accessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !refreshToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    func save(accessToken: String, refreshToken: String) {
        lock.withLock {
            defaults.set(accessToken, forKey: Keys.accessToken)
            defaults.set(refreshToken, forKey: Keys.refreshToken)
        }
    }

    func clearTokens() {
        lock.withLock {
            defaults.removeObject(forKey: Keys.accessToken)
            defaults.removeObject(forKey: Keys.refreshToken)
        }
    }
}

private extension NSLock {
    func withLock<T>(_ work: () -> T) -> T {
        lock()
        defer { unlock() }
        return work()
    }
}
