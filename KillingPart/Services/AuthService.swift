import Foundation
import AuthenticationServices
import KakaoSDKUser
import UIKit

protocol AuthServicing {
    @MainActor
    func loginWithKakao() async throws -> String

    @MainActor
    func loginWithApple() async throws -> AppleAuthPayload
}

struct AppleAuthPayload {
    let identityToken: String
    let authorizationCode: String
}

enum AuthServiceError: LocalizedError {
    case missingNativeAppKey
    case kakaoLoginFailed(underlying: Error)
    case missingKakaoAccessToken
    case applePresentationAnchorUnavailable
    case appleAuthorizationFailed(underlying: Error)
    case invalidAppleCredential
    case missingAppleIdentityToken
    case missingAppleAuthorizationCode
    case invalidAppleIdentityTokenEncoding
    case invalidAppleAuthorizationCodeEncoding

    var errorDescription: String? {
        switch self {
        case .missingNativeAppKey:
            return "KAKAO_NATIVE_APP_KEY 설정이 필요해요."
        case .kakaoLoginFailed:
            return "카카오 로그인에 실패했어요. 다시 시도해 주세요."
        case .missingKakaoAccessToken:
            return "카카오 액세스 토큰을 가져오지 못했어요."
        case .applePresentationAnchorUnavailable:
            return "애플 로그인 화면을 표시할 수 없어요. 다시 시도해 주세요."
        case .appleAuthorizationFailed:
            return "애플 로그인에 실패했어요. 다시 시도해 주세요."
        case .invalidAppleCredential:
            return "애플 로그인 정보를 확인할 수 없어요."
        case .missingAppleIdentityToken:
            return "애플 identity token을 가져오지 못했어요."
        case .missingAppleAuthorizationCode:
            return "애플 authorization code를 가져오지 못했어요."
        case .invalidAppleIdentityTokenEncoding, .invalidAppleAuthorizationCodeEncoding:
            return "애플 로그인 인증값 인코딩에 실패했어요."
        }
    }
}

final class AuthService: NSObject, AuthServicing {
    private var appleLoginContinuation: CheckedContinuation<AppleAuthPayload, Error>?
    private var applePresentationAnchor: ASPresentationAnchor?
    private var appleAuthorizationController: ASAuthorizationController?

    func loginWithKakao() async throws -> String {
        let appKey = (Bundle.main.object(forInfoDictionaryKey: "KAKAO_NATIVE_APP_KEY") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !appKey.isEmpty, appKey != "YOUR_KAKAO_NATIVE_APP_KEY" else {
            throw AuthServiceError.missingNativeAppKey
        }

        if UserApi.isKakaoTalkLoginAvailable() {
            return try await loginWithKakaoTalk()
        }

        return try await loginWithKakaoAccount()
    }

    func loginWithApple() async throws -> AppleAuthPayload {
        guard let anchor = resolvePresentationAnchor() else {
            throw AuthServiceError.applePresentationAnchorUnavailable
        }

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = []

        return try await withCheckedThrowingContinuation { continuation in
            appleLoginContinuation = continuation
            applePresentationAnchor = anchor

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            appleAuthorizationController = controller
            controller.performRequests()
        }
    }

    private func loginWithKakaoTalk() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            UserApi.shared.loginWithKakaoTalk { oauthToken, error in
                if let error {
                    continuation.resume(throwing: AuthServiceError.kakaoLoginFailed(underlying: error))
                    return
                }

                guard let accessToken = oauthToken?.accessToken, !accessToken.isEmpty else {
                    continuation.resume(throwing: AuthServiceError.missingKakaoAccessToken)
                    return
                }

                continuation.resume(returning: accessToken)
            }
        }
    }

    private func loginWithKakaoAccount() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            UserApi.shared.loginWithKakaoAccount { oauthToken, error in
                if let error {
                    continuation.resume(throwing: AuthServiceError.kakaoLoginFailed(underlying: error))
                    return
                }

                guard let accessToken = oauthToken?.accessToken, !accessToken.isEmpty else {
                    continuation.resume(throwing: AuthServiceError.missingKakaoAccessToken)
                    return
                }

                continuation.resume(returning: accessToken)
            }
        }
    }

    private func resolvePresentationAnchor() -> ASPresentationAnchor? {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }

        if let keyWindow = scenes
            .flatMap(\.windows)
            .first(where: \.isKeyWindow) {
            return keyWindow
        }

        return scenes
            .flatMap(\.windows)
            .first
    }

    private func completeAppleLogin(_ result: Result<AppleAuthPayload, Error>) {
        appleAuthorizationController = nil
        applePresentationAnchor = nil

        guard let continuation = appleLoginContinuation else { return }
        appleLoginContinuation = nil

        switch result {
        case .success(let payload):
            continuation.resume(returning: payload)
        case .failure(let error):
            continuation.resume(throwing: error)
        }
    }
}

extension AuthService: ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        applePresentationAnchor ?? ASPresentationAnchor(frame: .zero)
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            completeAppleLogin(.failure(AuthServiceError.invalidAppleCredential))
            return
        }

        guard let identityTokenData = credential.identityToken else {
            completeAppleLogin(.failure(AuthServiceError.missingAppleIdentityToken))
            return
        }

        guard let authorizationCodeData = credential.authorizationCode else {
            completeAppleLogin(.failure(AuthServiceError.missingAppleAuthorizationCode))
            return
        }

        guard let identityToken = String(data: identityTokenData, encoding: .utf8), !identityToken.isEmpty else {
            completeAppleLogin(.failure(AuthServiceError.invalidAppleIdentityTokenEncoding))
            return
        }

        guard let authorizationCode = String(data: authorizationCodeData, encoding: .utf8), !authorizationCode.isEmpty else {
            completeAppleLogin(.failure(AuthServiceError.invalidAppleAuthorizationCodeEncoding))
            return
        }

        completeAppleLogin(
            .success(
                AppleAuthPayload(
                    identityToken: identityToken,
                    authorizationCode: authorizationCode
                )
            )
        )
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        completeAppleLogin(.failure(AuthServiceError.appleAuthorizationFailed(underlying: error)))
    }
}
