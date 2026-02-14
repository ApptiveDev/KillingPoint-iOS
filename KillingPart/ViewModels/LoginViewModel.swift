import Foundation

@MainActor
final class LoginViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var loginErrorMessage: String?
    @Published private(set) var isNewUser = false

    var onLoginSuccess: ((Bool) -> Void)?

    private let authenticationService: AuthenticationServicing
    private let kakaoLoginService: KakaoLoginServicing

    init(
        authenticationService: AuthenticationServicing = AuthenticationService(),
        kakaoLoginService: KakaoLoginServicing = KakaoLoginService(),
        onLoginSuccess: ((Bool) -> Void)? = nil
    ) {
        self.authenticationService = authenticationService
        self.kakaoLoginService = kakaoLoginService
        self.onLoginSuccess = onLoginSuccess
    }

    func login(email: String, password: String) {
        guard !isLoading else { return }

        isLoading = true
        loginErrorMessage = nil

        Task {
            let isSuccess = await authenticationService.login(email: email, password: password)
            isLoading = false

            if isSuccess {
                isNewUser = false
                onLoginSuccess?(false)
            } else {
                loginErrorMessage = "이메일과 비밀번호를 입력해주세요."
            }
        }
    }

    func loginWithKakao() {
        guard !isLoading else { return }

        isLoading = true
        loginErrorMessage = nil

        Task {
            defer { isLoading = false }

            do {
                let kakaoAccessToken = try await kakaoLoginService.login()
                let response = try await authenticationService.loginWithKakao(accessToken: kakaoAccessToken)
                isNewUser = response.isNew
                onLoginSuccess?(response.isNew)
            } catch let authError as AuthenticationServiceError {
                loginErrorMessage = authError.errorDescription
            } catch let kakaoError as KakaoLoginError {
                loginErrorMessage = kakaoError.errorDescription
            } catch {
                loginErrorMessage = "로그인 중 오류가 발생했어요. 다시 시도해 주세요."
            }
        }
    }

    func resetState() {
        isLoading = false
        loginErrorMessage = nil
        isNewUser = false
    }
}
