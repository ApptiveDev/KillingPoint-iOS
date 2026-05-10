import UIKit
import UserNotifications

enum PushNotificationPermissionManager {
    static func handleAuthorizationAfterEnteringMain() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let status = settings.authorizationStatus
            print("[FCM][2] 현재 알림 권한 상태: \(status.debugDescription)")

            switch status {
            case .notDetermined:
                requestAuthorization()
            case .authorized, .provisional, .ephemeral:
                registerForRemoteNotifications()
            case .denied:
                print("[FCM][2] ⚠️ 권한 거부 — 설정 앱에서 알림을 허용해야 합니다")
            @unknown default:
                break
            }
        }
    }

    private static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error {
                print("[FCM][2] ❌ 알림 권한 요청 오류: \(error.localizedDescription)")
                return
            }

            print("[FCM][2] 알림 권한 \(granted ? "✅ 허용" : "❌ 거부")")
            guard granted else {
                print("[FCM][2] ⚠️ 권한 거부 — 설정 앱에서 알림을 허용해야 합니다")
                return
            }

            registerForRemoteNotifications()
        }
    }

    private static func registerForRemoteNotifications() {
        DispatchQueue.main.async {
            print("[FCM][2] APNs 등록 요청 시작")
            UIApplication.shared.registerForRemoteNotifications()
        }
    }
}

private extension UNAuthorizationStatus {
    var debugDescription: String {
        switch self {
        case .notDetermined:
            return "notDetermined"
        case .denied:
            return "denied ❌"
        case .authorized:
            return "authorized ✅"
        case .provisional:
            return "provisional"
        case .ephemeral:
            return "ephemeral"
        @unknown default:
            return "unknown"
        }
    }
}
