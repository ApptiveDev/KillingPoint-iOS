import UserNotifications
import FirebaseMessaging

struct PushAlarmRoute: Equatable {
    let type: AlarmType
    let deepLink: String
    let alarmId: Int?
}

final class FCMManager {
    static let shared = FCMManager()

    private let fcmService: FCMServicing
    private let tokenStore: TokenStoring
    private let pendingTokenKey = "fcm.pendingToken"
    private var pendingAlarmRoute: PushAlarmRoute?

    init(
        fcmService: FCMServicing = FCMService(),
        tokenStore: TokenStoring = TokenStore.shared
    ) {
        self.fcmService = fcmService
        self.tokenStore = tokenStore
    }

    func didReceiveToken(_ token: String) {
        guard Messaging.messaging().apnsToken != nil else {
            print("[FCM] APNs 미연결 — 토큰 무시 (APNs 연결 후 재발급됨)")
            return
        }

        print("[FCM] APNs 연결 확인 — 토큰 처리 시작")

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

    func handleNotificationResponse(
        _ response: UNNotificationResponse,
        isColdStart: Bool
    ) {
        let userInfo = response.notification.request.content.userInfo
        print("[FCM] 알림 클릭 payload: \(userInfo)")
        trackPushOpened(
            userInfo,
            fallbackNotificationID: response.notification.request.identifier,
            isColdStart: isColdStart
        )
        parsePayload(userInfo)
    }

    func handleLaunchRemoteNotification(_ userInfo: [AnyHashable: Any]) {
        print("[FCM] 앱 시작 remote payload: \(userInfo)")
        trackPushOpened(userInfo, fallbackNotificationID: nil, isColdStart: true)
        parsePayload(userInfo)
    }

    func consumePendingAlarmRoute() -> PushAlarmRoute? {
        defer { pendingAlarmRoute = nil }
        return pendingAlarmRoute
    }

    func clearPendingAlarmRoute() {
        pendingAlarmRoute = nil
    }

    private func parsePayload(_ userInfo: [AnyHashable: Any]) {
        let parsed = normalizedPayload(from: userInfo)

        guard let rawType = parsed.string(for: ["type", "alarmType", "notificationType"]) else {
            print("[FCM][Route] type 누락으로 라우팅 스킵")
            return
        }

        let routeType = AlarmType(rawValue: rawType)
        guard routeType == .like || routeType == .subscribe || routeType == .diary else {
            print("[FCM][Route] 지원하지 않는 type: \(routeType.rawValue)")
            return
        }

        let deepLink: String
        if let resolvedDeepLink = parsed.string(for: ["deepLink", "deeplink", "link", "path"]),
           !resolvedDeepLink.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            deepLink = resolvedDeepLink
        } else if routeType == .subscribe,
                  let subscribedId = parsed.int(for: ["subscribedId", "subscribedID", "userId", "userid"]) {
            deepLink = "/api/subscribes/\(subscribedId)/fans"
        } else if (routeType == .like || routeType == .diary),
                  let diaryId = parsed.int(for: ["diaryId", "diaryID", "id"]) {
            deepLink = "/api/diaries/\(diaryId)"
        } else {
            print("[FCM][Route] deepLink/ID 누락으로 라우팅 스킵")
            return
        }

        let alarmId = parsed.int(for: ["alarmId", "alarmID"])
        let route = PushAlarmRoute(type: routeType, deepLink: deepLink, alarmId: alarmId)
        pendingAlarmRoute = route
        print(
            "[FCM][Route] emit type=\(route.type.rawValue) deepLink=\(route.deepLink) alarmId=\(route.alarmId?.description ?? "nil")"
        )
        NotificationCenter.default.post(name: .didTapPushAlarm, object: route)
    }

    private func trackPushOpened(
        _ userInfo: [AnyHashable: Any],
        fallbackNotificationID: String?,
        isColdStart: Bool
    ) {
        let parsed = normalizedPayload(from: userInfo)
        let rawType = parsed.string(for: ["type", "alarmType", "notificationType"]) ?? ""
        let type = AlarmType(rawValue: rawType)
        let notificationID = parsed.string(for: ["alarmId", "alarmID", "notificationId", "notificationID"])
            ?? fallbackNotificationID
        NotificationAnalytics.trackPushOpened(
            type: type,
            notificationID: notificationID,
            isColdStart: isColdStart
        )
    }
}

private struct NormalizedPayload {
    let values: [String: Any]

    func string(for keys: [String]) -> String? {
        for key in keys {
            guard let value = values[key.lowercased()] else { continue }

            if let string = value as? String {
                let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    return trimmed
                }
            } else if let number = value as? NSNumber {
                return number.stringValue
            }
        }
        return nil
    }

    func int(for keys: [String]) -> Int? {
        for key in keys {
            guard let value = values[key.lowercased()] else { continue }
            if let intValue = value as? Int, intValue > 0 {
                return intValue
            }

            if let number = value as? NSNumber {
                let intValue = number.intValue
                if intValue > 0 {
                    return intValue
                }
            }

            if let string = value as? String,
               let intValue = Int(string.trimmingCharacters(in: .whitespacesAndNewlines)),
               intValue > 0 {
                return intValue
            }
        }
        return nil
    }
}

private func normalizedPayload(from userInfo: [AnyHashable: Any]) -> NormalizedPayload {
    var normalized: [String: Any] = [:]

    for (key, value) in userInfo {
        guard let stringKey = key as? String else { continue }
        normalized[stringKey.lowercased()] = value
    }

    if let data = normalized["data"] as? [String: Any] {
        for (key, value) in data {
            normalized[key.lowercased()] = value
        }
    } else if let dataString = normalized["data"] as? String,
              let rawData = dataString.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: rawData) as? [String: Any] {
        for (key, value) in jsonObject {
            normalized[key.lowercased()] = value
        }
    }

    return NormalizedPayload(values: normalized)
}
