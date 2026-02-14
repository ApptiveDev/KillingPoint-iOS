import Foundation

@MainActor
final class AppViewModel: ObservableObject {
    @Published var currentStep: AppFlowStep = .splash

    let loginViewModel: LoginViewModel

    private let tokenStore: TokenStoring
    private let notificationCenter: NotificationCenter
    private var sessionExpiredObserver: NSObjectProtocol?

    init(
        authenticationService: AuthenticationServicing = AuthenticationService(),
        kakaoLoginService: KakaoLoginServicing = KakaoLoginService(),
        tokenStore: TokenStoring = TokenStore.shared,
        notificationCenter: NotificationCenter = .default
    ) {
        self.tokenStore = tokenStore
        self.notificationCenter = notificationCenter

        let loginViewModel = LoginViewModel(
            authenticationService: authenticationService,
            kakaoLoginService: kakaoLoginService
        )

        self.loginViewModel = loginViewModel
        self.loginViewModel.onLoginSuccess = { [weak self] _ in
            self?.currentStep = .main
        }

        sessionExpiredObserver = notificationCenter.addObserver(
            forName: .authenticationSessionExpired,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.logout()
            }
        }
    }

    deinit {
        if let sessionExpiredObserver {
            notificationCenter.removeObserver(sessionExpiredObserver)
        }
    }

    func completeSplash() {
        currentStep = tokenStore.hasSessionTokens ? .main : .onboarding
    }

    func completeOnboarding() {
        currentStep = tokenStore.hasSessionTokens ? .main : .login
    }

    func logout() {
        loginViewModel.resetState()
        currentStep = .login
    }
}
