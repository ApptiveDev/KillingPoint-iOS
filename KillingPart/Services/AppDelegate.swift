import UIKit
import FirebaseCore
import FirebaseMessaging
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate {
    private var hasBecomeActive = false

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        print("[FCM][1] didFinishLaunching — Firebase 초기화 시작")
        FirebaseApp.configure()
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
        let amplitudeApiKey = (Bundle.main.object(forInfoDictionaryKey: "AMPLITUDE_API_KEY") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        AmplitudeClient.shared.configure(apiKey: amplitudeApiKey)
        AmplitudeClient.shared.track(eventType: "app_opened")
        if let remotePayload = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
            FCMManager.shared.handleLaunchRemoteNotification(remotePayload)
        }
        print("[FCM][1] Firebase 초기화 완료")
        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        hasBecomeActive = true
    }

    // APNs 토큰 수신 — swizzling 비활성화 시 필수, 활성화 시에도 명시적으로 처리
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let tokenString = deviceToken.map { String(format: "%02x", $0) }.joined()
        print("[FCM][3] ✅ APNs 토큰 수신: \(tokenString.prefix(20))...")
        Messaging.messaging().apnsToken = deviceToken
        print("[FCM][3] APNs 토큰 → Firebase 전달 완료")
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("[FCM][3] ❌ APNs 등록 실패: \(error.localizedDescription)")
    }

    // 백그라운드/포그라운드 데이터 메시지 수신 — 이 메서드가 없으면 data-only 메시지가 전달되지 않음
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        print("[FCM][Background] 원격 알림 수신 — payload: \(userInfo)")
        completionHandler(.newData)
    }

}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo
        print("[FCM][Foreground] 알림 수신 — payload: \(userInfo)")
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        guard response.actionIdentifier == UNNotificationDefaultActionIdentifier else {
            completionHandler()
            return
        }
        print("[FCM][Tap] 알림 탭 감지")
        FCMManager.shared.handleNotificationResponse(
            response,
            isColdStart: !hasBecomeActive
        )
        completionHandler()
    }
}

extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else {
            print("[FCM][4] ❌ FCM 토큰 nil")
            return
        }

        if let apnsToken = messaging.apnsToken {
            let apnsHex = apnsToken.map { String(format: "%02x", $0) }.joined()
            print("[FCM][4] ✅ APNs 연결됨: \(apnsHex.prefix(20))...")
        } else {
            print("[FCM][4] ⚠️ APNs 토큰 nil")
        }

        print("[FCM][4] FCM 토큰: \(token)")
        FCMManager.shared.didReceiveToken(token)
    }
}
