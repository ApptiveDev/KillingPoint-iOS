import Foundation

@MainActor
final class AppViewModel: ObservableObject {
    @Published var currentStep: AppFlowStep = .splash

    let loginViewModel: LoginViewModel

    init(
        authenticationService: AuthenticationServicing = AuthenticationService(),
        kakaoLoginService: KakaoLoginServicing = KakaoLoginService()
    ) {
        let loginViewModel = LoginViewModel(
            authenticationService: authenticationService,
            kakaoLoginService: kakaoLoginService
        )

        self.loginViewModel = loginViewModel
        self.loginViewModel.onLoginSuccess = { [weak self] _ in
            self?.currentStep = .main
        }
    }

    func completeSplash() {
        currentStep = .onboarding
    }

    func completeOnboarding() {
        currentStep = .login
    }

    func logout() {
        loginViewModel.resetState()
        currentStep = .login
    }
}
