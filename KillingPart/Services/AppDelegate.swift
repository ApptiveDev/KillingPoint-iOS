import UIKit
import FirebaseCore
import FirebaseMessaging
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        print("[FCM][1] didFinishLaunching — Firebase 초기화 시작")
        FirebaseApp.configure()
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
        print("[FCM][1] Firebase 초기화 완료, 알림 권한 요청 시작")
        requestNotificationAuthorization()
        return true
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

    private func requestNotificationAuthorization() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            print("[FCM][2] 현재 알림 권한 상태: \(settings.authorizationStatus.debugDescription)")
        }

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error {
                print("[FCM][2] ❌ 알림 권한 요청 오류: \(error.localizedDescription)")
                return
            }
            print("[FCM][2] 알림 권한 \(granted ? "✅ 허용" : "❌ 거부")")
            if granted {
                DispatchQueue.main.async {
                    print("[FCM][2] APNs 등록 요청 시작")
                    UIApplication.shared.registerForRemoteNotifications()
                }
            } else {
                print("[FCM][2] ⚠️ 권한 거부 — 설정 앱에서 알림을 허용해야 합니다")
            }
        }
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
        print("[FCM][Tap] 알림 탭 감지")
        FCMManager.shared.handleNotificationResponse(response)
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

private extension UNAuthorizationStatus {
    var debugDescription: String {
        switch self {
        case .notDetermined: return "notDetermined"
        case .denied:        return "denied ❌"
        case .authorized:    return "authorized ✅"
        case .provisional:   return "provisional"
        case .ephemeral:     return "ephemeral"
        @unknown default:    return "unknown"
        }
    }
}
