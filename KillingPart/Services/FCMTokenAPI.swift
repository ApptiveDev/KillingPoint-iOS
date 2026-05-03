import Foundation

enum FCMTokenAPI {
    static func registerToken(_ token: String) async throws {
        let body = try JSONEncoder().encode(FCMTokenRequest(token: token))
        let request = APIRequest(
            path: "/fcm/tokens",
            method: .post,
            requiresAuthorization: true,
            body: body
        )
        try await APIClient.shared.request(request)
        print("[FCM] 서버에 토큰 등록 완료")
    }

    static func deleteToken() async throws {
        let request = APIRequest(
            path: "/fcm/tokens",
            method: .delete,
            requiresAuthorization: true
        )
        try await APIClient.shared.request(request)
        print("[FCM] 서버에서 토큰 삭제 완료")
    }
}

private struct FCMTokenRequest: Encodable {
    let token: String
}
