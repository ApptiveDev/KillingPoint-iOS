import Foundation

@MainActor
final class AppFlowViewModel: ObservableObject {
    @Published var currentStep: AppFlowStep = .splash
    @Published var isLoading = false
    @Published var loginErrorMessage: String?

    private let authenticationService: AuthenticationServicing

    init(authenticationService: AuthenticationServicing = AuthenticationService()) {
        self.authenticationService = authenticationService
    }

    func completeSplash() {
        currentStep = .onboarding
    }

    func completeOnboarding() {
        currentStep = .login
    }

    func login(email: String, password: String) {
        guard !isLoading else { return }

        isLoading = true
        loginErrorMessage = nil

        Task {
            let isSuccess = await authenticationService.login(email: email, password: password)
            isLoading = false

            if isSuccess {
                currentStep = .main
            } else {
                loginErrorMessage = "이메일과 비밀번호를 입력해주세요."
            }
        }
    }

    func logout() {
        currentStep = .login
    }
}
