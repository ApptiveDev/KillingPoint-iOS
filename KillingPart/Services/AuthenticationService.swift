import Foundation

protocol AuthenticationServicing {
    func login(email: String, password: String) async -> Bool
}

struct AuthenticationService: AuthenticationServicing {
    func login(email: String, password: String) async -> Bool {
        try? await Task.sleep(for: .milliseconds(600))
        return !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
