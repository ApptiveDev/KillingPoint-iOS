import Foundation
import KakaoSDKUser

protocol KakaoLoginServicing {
    @MainActor
    func login() async throws -> String
}

enum KakaoLoginError: LocalizedError {
    case missingNativeAppKey
    case loginFailed(underlying: Error)
    case missingAccessToken

    var errorDescription: String? {
        switch self {
        case .missingNativeAppKey:
            return "KAKAO_NATIVE_APP_KEY 설정이 필요해요."
        case .loginFailed:
            return "카카오 로그인에 실패했어요. 다시 시도해 주세요."
        case .missingAccessToken:
            return "카카오 액세스 토큰을 가져오지 못했어요."
        }
    }
}

struct KakaoLoginService: KakaoLoginServicing {
    @MainActor
    func login() async throws -> String {
        let appKey = (Bundle.main.object(forInfoDictionaryKey: "KAKAO_NATIVE_APP_KEY") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !appKey.isEmpty, appKey != "YOUR_KAKAO_NATIVE_APP_KEY" else {
            throw KakaoLoginError.missingNativeAppKey
        }

        if UserApi.isKakaoTalkLoginAvailable() {
            return try await loginWithKakaoTalk()
        }

        return try await loginWithKakaoAccount()
    }

    @MainActor
    private func loginWithKakaoTalk() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            UserApi.shared.loginWithKakaoTalk { oauthToken, error in
                if let error {
                    continuation.resume(throwing: KakaoLoginError.loginFailed(underlying: error))
                    return
                }

                guard let accessToken = oauthToken?.accessToken, !accessToken.isEmpty else {
                    continuation.resume(throwing: KakaoLoginError.missingAccessToken)
                    return
                }

                continuation.resume(returning: accessToken)
            }
        }
    }

    @MainActor
    private func loginWithKakaoAccount() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            UserApi.shared.loginWithKakaoAccount { oauthToken, error in
                if let error {
                    continuation.resume(throwing: KakaoLoginError.loginFailed(underlying: error))
                    return
                }

                guard let accessToken = oauthToken?.accessToken, !accessToken.isEmpty else {
                    continuation.resume(throwing: KakaoLoginError.missingAccessToken)
                    return
                }

                continuation.resume(returning: accessToken)
            }
        }
    }
}
