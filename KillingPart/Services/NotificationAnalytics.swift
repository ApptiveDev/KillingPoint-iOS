import Foundation

enum NotificationAnalyticsEntryPoint: String {
    case push
    case notificationList = "notification_list"
    case pickList = "pick_list"
}

extension AlarmType {
    var analyticsNotificationType: String {
        switch self {
        case .like:
            return "like"
        case .subscribe:
            return "pick"
        case .diary:
            return "new_killingpart"
        default:
            return "unknown"
        }
    }
}

enum NotificationAnalytics {
    static func trackPushOpened(
        type: AlarmType,
        notificationID: String?,
        isColdStart: Bool
    ) {
        var properties: [String: Any] = [
            "notification_type": type.analyticsNotificationType,
            "is_cold_start": isColdStart
        ]
        addNonempty(notificationID, key: "notification_id", to: &properties)
        track("push_notification_opened", properties: properties)
    }

    static func trackNotificationListViewed(unreadCount: Int?) {
        var properties: [String: Any] = [:]
        if let unreadCount {
            properties["unread_count"] = max(unreadCount, 0)
        }
        track("notification_list_viewed", properties: properties)
    }

    static func trackNotificationSelected(
        type: AlarmType,
        notificationID: String?,
        listPosition: Int?
    ) {
        var properties: [String: Any] = [
            "notification_type": type.analyticsNotificationType
        ]
        addNonempty(notificationID, key: "notification_id", to: &properties)
        if let listPosition {
            properties["list_position"] = max(listPosition, 0)
        }
        track("notification_selected", properties: properties)
    }

    static func trackKillingPartDetailViewed(
        entryPoint: NotificationAnalyticsEntryPoint?,
        diaryID: Int
    ) {
        var properties: [String: Any] = ["diary_id": String(diaryID)]
        if let entryPoint {
            properties["entry_point"] = entryPoint.rawValue
        }
        track("killingpart_detail_viewed", properties: properties)
    }

    static func trackPickListViewed(
        entryPoint: NotificationAnalyticsEntryPoint,
        pickCount: Int? = nil
    ) {
        var properties: [String: Any] = ["entry_point": entryPoint.rawValue]
        if let pickCount {
            properties["pick_count"] = max(pickCount, 0)
        }
        track("pick_list_viewed", properties: properties)
    }

    static func trackProfileViewed(
        entryPoint: NotificationAnalyticsEntryPoint?,
        profileUserID: Int
    ) {
        var properties: [String: Any] = ["profile_user_id": String(profileUserID)]
        if let entryPoint {
            properties["entry_point"] = entryPoint.rawValue
        }
        track("profile_viewed", properties: properties)
    }

    private static func track(_ eventType: String, properties: [String: Any]) {
        AmplitudeClient.shared.track(
            eventType: eventType,
            properties: properties.isEmpty ? nil : properties
        )
    }

    private static func addNonempty(
        _ value: String?,
        key: String,
        to properties: inout [String: Any]
    ) {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else { return }
        properties[key] = trimmed
    }
}
