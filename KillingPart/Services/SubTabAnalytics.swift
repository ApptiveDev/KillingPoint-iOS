import Foundation

enum SubTabAnalyticsParent: String {
    case my
    case social
}

enum SubTabAnalyticsName: String {
    case collection
    case killingPartPlay = "killingpart_play"
    case musicCalendar = "music_calendar"
    case feed
    case friends
    case notification
    case unknown
}

enum SubTabAnalyticsEntryType: String {
    case appLaunch = "app_launch"
    case appForeground = "app_foreground"
    case tabEnter = "tab_enter"
    case userSelect = "user_select"
    case unknown
}

enum SubTabAnalyticsEndReason: String {
    case subTabChange = "sub_tab_change"
    case tabChange = "tab_change"
    case appBackground = "app_background"
    case viewDisappear = "view_disappear"
}

final class SubTabAnalyticsSession {
    let parent: SubTabAnalyticsParent

    private(set) var activeSubTab: SubTabAnalyticsName?
    private var enteredAt: Date?
    private let trackEvent: (_ eventType: String, _ properties: [String: Any]) -> Void

    init(
        parent: SubTabAnalyticsParent,
        trackEvent: @escaping (_ eventType: String, _ properties: [String: Any]) -> Void = {
            eventType,
            properties in
            AmplitudeClient.shared.track(eventType: eventType, properties: properties)
        }
    ) {
        self.parent = parent
        self.trackEvent = trackEvent
    }

    func begin(
        _ subTab: SubTabAnalyticsName,
        entryType: SubTabAnalyticsEntryType,
        previousSubTab: SubTabAnalyticsName? = nil,
        at date: Date = Date()
    ) {
        guard activeSubTab == nil else { return }

        activeSubTab = subTab
        enteredAt = date
        trackEvent(
            "sub_tab_selected",
            [
                "tab": parent.rawValue,
                "sub_tab": subTab.rawValue,
                "entry_type": entryType.rawValue,
                "previous_sub_tab": entryType == .userSelect
                    ? (previousSubTab?.rawValue ?? "none")
                    : "none"
            ]
        )
    }

    func transition(
        to subTab: SubTabAnalyticsName,
        entryType: SubTabAnalyticsEntryType,
        at date: Date = Date()
    ) {
        guard activeSubTab != subTab else { return }

        let previousSubTab = activeSubTab
        if previousSubTab != nil {
            end(reason: .subTabChange, at: date)
        }
        begin(
            subTab,
            entryType: entryType,
            previousSubTab: previousSubTab,
            at: date
        )
    }

    func end(
        reason: SubTabAnalyticsEndReason,
        at date: Date = Date()
    ) {
        guard let activeSubTab, let enteredAt else { return }

        let duration = max(date.timeIntervalSince(enteredAt), 0)
        let roundedDuration = (duration * 100).rounded() / 100
        trackEvent(
            "sub_tab_stayed",
            [
                "tab": parent.rawValue,
                "sub_tab": activeSubTab.rawValue,
                "stay_duration_sec": roundedDuration,
                "end_reason": reason.rawValue
            ]
        )

        self.activeSubTab = nil
        self.enteredAt = nil
    }
}
