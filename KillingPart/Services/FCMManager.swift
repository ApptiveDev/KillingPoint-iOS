import UserNotifications
import FirebaseMessaging

final class FCMManager {
    static let shared = FCMManager()

    private let fcmService: FCMServicing
    private let tokenStore: TokenStoring
    private let pendingTokenKey = "fcm.pendingToken"

    init(
        fcmService: FCMServicing = FCMService(),
        tokenStore: TokenStoring = TokenStore.shared
    ) {
        self.fcmService = fcmService
        self.tokenStore = tokenStore
    }

    func didReceiveToken(_ token: String) {
        if tokenStore.hasSessionTokens {
            Task {
                do {
                    try await fcmService.registerToken(token)
                } catch {
                    print("[FCM] 토큰 서버 등록 실패: \(error.localizedDescription)")
                    UserDefaults.standard.set(token, forKey: pendingTokenKey)
                }
            }
        } else {
            UserDefaults.standard.set(token, forKey: pendingTokenKey)
            print("[FCM] 비로그인 상태 — 토큰 로컬 저장")
        }
    }

    func registerPendingTokenIfNeeded() {
        Task {
            let token: String?
            if let pending = UserDefaults.standard.string(forKey: pendingTokenKey) {
                token = pending
            } else {
                token = try? await Messaging.messaging().token()
            }

            guard let token else {
                print("[FCM] 등록할 토큰 없음")
                return
            }

            do {
                try await fcmService.registerToken(token)
                UserDefaults.standard.removeObject(forKey: pendingTokenKey)
            } catch {
                print("[FCM] 로그인 후 토큰 서버 등록 실패: \(error.localizedDescription)")
            }
        }
    }

    func deleteToken() async throws {
        try await fcmService.deleteToken()
        UserDefaults.standard.removeObject(forKey: pendingTokenKey)
    }

    func handleNotificationResponse(_ response: UNNotificationResponse) {
        let userInfo = response.notification.request.content.userInfo
        print("[FCM] 알림 클릭 payload: \(userInfo)")
        parsePayload(userInfo)
    }

    private func parsePayload(_ userInfo: [AnyHashable: Any]) {
        // 추후 화면 이동 연결 포인트
        // 예: if let screen = userInfo["screen"] as? String { ... }
    }
}
