import Foundation

@MainActor
final class LoginViewModel: ObservableObject {
    enum SocialLoginProvider {
        case kakao
        case google
        case apple
        case tester
    }

    @Published var isLoading = false
    @Published var loginErrorMessage: String?
    @Published private(set) var isNewUser = false
    @Published private(set) var activeSocialLoginProvider: SocialLoginProvider?
    @Published private(set) var lastSuccessfulLoginProvider: SocialLoginProvider?

    var onLoginSuccess: ((Bool) -> Void)?

    private let authenticationService: AuthenticationServicing
    private let authService: AuthServicing

    init(
        authenticationService: AuthenticationServicing = AuthenticationService(),
        authService: AuthServicing = AuthService(),
        onLoginSuccess: ((Bool) -> Void)? = nil
    ) {
        self.authenticationService = authenticationService
        self.authService = authService
        self.onLoginSuccess = onLoginSuccess
    }

    func login(email: String, password: String) {
        guard !isLoading else { return }

        isLoading = true
        loginErrorMessage = nil
        activeSocialLoginProvider = nil
        lastSuccessfulLoginProvider = nil

        Task {
            let isSuccess = await authenticationService.login(email: email, password: password)
            isLoading = false

            if isSuccess {
                isNewUser = false
                lastSuccessfulLoginProvider = nil
                trackLoginSuccess(provider: "email", isNewUser: false)
                onLoginSuccess?(false)
            } else {
                loginErrorMessage = "이메일과 비밀번호를 입력해주세요."
            }
        }
    }

    func loginWithKakao() {
        guard startSocialLogin(for: .kakao) else { return }

        Task {
            defer { finishSocialLogin() }

            do {
                let kakaoAccessToken = try await authService.loginWithKakao()
                let response = try await authenticationService.loginWithKakao(accessToken: kakaoAccessToken)
                isNewUser = response.isNew
                lastSuccessfulLoginProvider = .kakao
                trackLoginSuccess(provider: "kakao", isNewUser: response.isNew)
                onLoginSuccess?(response.isNew)
            } catch let authError as AuthenticationServiceError {
                loginErrorMessage = authError.errorDescription
            } catch let socialError as AuthServiceError {
                loginErrorMessage = socialError.errorDescription
            } catch {
                loginErrorMessage = "로그인 중 오류가 발생했어요. 다시 시도해 주세요."
            }
        }
    }

    func loginWithApple() {
        guard startSocialLogin(for: .apple) else { return }

        Task {
            defer { finishSocialLogin() }

            do {
                let applePayload = try await authService.loginWithApple()
                let response = try await authenticationService.loginWithApple(
                    identityToken: applePayload.identityToken,
                    authorizationCode: applePayload.authorizationCode,
                    email: applePayload.email,
                    name: applePayload.name
                )
                isNewUser = response.isNew
                lastSuccessfulLoginProvider = .apple
                trackLoginSuccess(provider: "apple", isNewUser: response.isNew)
                onLoginSuccess?(response.isNew)
            } catch let authError as AuthenticationServiceError {
                loginErrorMessage = authError.errorDescription
            } catch let socialError as AuthServiceError {
                loginErrorMessage = socialError.errorDescription
            } catch {
                loginErrorMessage = "로그인 중 오류가 발생했어요. 다시 시도해 주세요."
            }
        }
    }

    func loginWithGoogle() {
        guard startSocialLogin(for: .google) else { return }

        Task {
            defer { finishSocialLogin() }

            do {
                let googleIDToken = try await authService.loginWithGoogle()
                let response = try await authenticationService.loginWithGoogle(idToken: googleIDToken)
                isNewUser = response.isNew
                lastSuccessfulLoginProvider = .google
                trackLoginSuccess(provider: "google", isNewUser: response.isNew)
                onLoginSuccess?(response.isNew)
            } catch let authError as AuthenticationServiceError {
                loginErrorMessage = authError.errorDescription
            } catch let socialError as AuthServiceError {
                loginErrorMessage = socialError.errorDescription
            } catch {
                loginErrorMessage = "로그인 중 오류가 발생했어요. 다시 시도해 주세요."
            }
        }
    }

    func loginWithTester() {
        guard startSocialLogin(for: .tester) else { return }

        Task {
            defer { finishSocialLogin() }

            do {
                _ = try await authService.loginWithTester()
                isNewUser = true
                lastSuccessfulLoginProvider = .tester
                trackLoginSuccess(provider: "tester", isNewUser: true)
                onLoginSuccess?(true)
            } catch let socialError as AuthServiceError {
                loginErrorMessage = socialError.errorDescription
            } catch {
                loginErrorMessage = "로그인 중 오류가 발생했어요. 다시 시도해 주세요."
            }
        }
    }

    func resetState() {
        isLoading = false
        loginErrorMessage = nil
        isNewUser = false
        activeSocialLoginProvider = nil
        lastSuccessfulLoginProvider = nil
    }

    private func startSocialLogin(for provider: SocialLoginProvider) -> Bool {
        guard !isLoading else { return false }

        isLoading = true
        loginErrorMessage = nil
        activeSocialLoginProvider = provider
        return true
    }

    private func finishSocialLogin() {
        isLoading = false
        activeSocialLoginProvider = nil
    }

    private func trackLoginSuccess(provider: String, isNewUser: Bool) {
        AmplitudeClient.shared.track(
            eventType: "auth_login_success",
            properties: [
                "provider": provider,
                "is_new_user": isNewUser
            ]
        )
    }
}
