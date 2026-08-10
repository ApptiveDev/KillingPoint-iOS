//
//  KillingPartTests.swift
//  KillingPartTests
//
//  Created by 이병찬 on 2/7/26.
//

import Foundation
import Testing
@testable import KillingPart

struct KillingPartTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }

    @Test func cutHandleAdjustedControlValuesMatchAnalyticsContract() {
        #expect(AddSearchDetailTrimInteractionControl.left.rawValue == "left")
        #expect(AddSearchDetailTrimInteractionControl.right.rawValue == "right")
        #expect(AddSearchDetailTrimInteractionControl.spectrum.rawValue == "spectrum")
        #expect(AddSearchDetailTrimInteractionControl.minimap.rawValue == "minimap")
        #expect(
            AddSearchDetailTrimInteractionControl.nudgeMinusOneSecond.rawValue
                == "nudge_minus_1s"
        )
        #expect(
            AddSearchDetailTrimInteractionControl.nudgePlusOneSecond.rawValue
                == "nudge_plus_1s"
        )
        #expect(AddSearchDetailTrimInteractionControl.unknown.rawValue == "unknown")
    }

    @Test func notificationAnalyticsValuesMatchContract() {
        #expect(AlarmType.like.analyticsNotificationType == "like")
        #expect(AlarmType.subscribe.analyticsNotificationType == "pick")
        #expect(AlarmType.diary.analyticsNotificationType == "new_killingpart")
        #expect(AlarmType(rawValue: "OTHER").analyticsNotificationType == "unknown")
        #expect(NotificationAnalyticsEntryPoint.push.rawValue == "push")
        #expect(
            NotificationAnalyticsEntryPoint.notificationList.rawValue
                == "notification_list"
        )
        #expect(NotificationAnalyticsEntryPoint.pickList.rawValue == "pick_list")
        #expect(NotificationListAnalyticsEntryPoint.push.rawValue == "push")
        #expect(NotificationListAnalyticsEntryPoint.socialTab.rawValue == "social_tab")
        #expect(NotificationListAnalyticsEntryPoint.unknown.rawValue == "unknown")
    }

    @Test func subTabAnalyticsValuesMatchContract() {
        #expect(SubTabAnalyticsParent.my.rawValue == "my")
        #expect(SubTabAnalyticsParent.social.rawValue == "social")

        #expect(SubTabAnalyticsName.collection.rawValue == "collection")
        #expect(SubTabAnalyticsName.killingPartPlay.rawValue == "killingpart_play")
        #expect(SubTabAnalyticsName.musicCalendar.rawValue == "music_calendar")
        #expect(SubTabAnalyticsName.feed.rawValue == "feed")
        #expect(SubTabAnalyticsName.friends.rawValue == "friends")
        #expect(SubTabAnalyticsName.notification.rawValue == "notification")
        #expect(SubTabAnalyticsName.unknown.rawValue == "unknown")

        #expect(SubTabAnalyticsEntryType.appLaunch.rawValue == "app_launch")
        #expect(SubTabAnalyticsEntryType.appForeground.rawValue == "app_foreground")
        #expect(SubTabAnalyticsEntryType.tabEnter.rawValue == "tab_enter")
        #expect(SubTabAnalyticsEntryType.userSelect.rawValue == "user_select")
        #expect(SubTabAnalyticsEntryType.unknown.rawValue == "unknown")

        #expect(SubTabAnalyticsEndReason.subTabChange.rawValue == "sub_tab_change")
        #expect(SubTabAnalyticsEndReason.tabChange.rawValue == "tab_change")
        #expect(SubTabAnalyticsEndReason.appBackground.rawValue == "app_background")
        #expect(SubTabAnalyticsEndReason.viewDisappear.rawValue == "view_disappear")
    }

    @Test func subTabAnalyticsSessionPairsSelectionAndStayWithoutDuplicateReselection() {
        var events: [(type: String, properties: [String: Any])] = []
        let session = SubTabAnalyticsSession(parent: .my) { type, properties in
            events.append((type, properties))
        }
        let startedAt = Date(timeIntervalSince1970: 1_000)

        session.begin(.killingPartPlay, entryType: .appLaunch, at: startedAt)
        session.transition(
            to: .killingPartPlay,
            entryType: .userSelect,
            at: startedAt.addingTimeInterval(0.5)
        )
        session.transition(
            to: .collection,
            entryType: .userSelect,
            at: startedAt.addingTimeInterval(1.234)
        )
        session.end(
            reason: .tabChange,
            at: startedAt.addingTimeInterval(3.734)
        )

        #expect(events.count == 4)
        #expect(events.map(\.type) == [
            "sub_tab_selected",
            "sub_tab_stayed",
            "sub_tab_selected",
            "sub_tab_stayed"
        ])
        #expect(events[0].properties["entry_type"] as? String == "app_launch")
        #expect(events[0].properties["previous_sub_tab"] as? String == "none")
        #expect(events[1].properties["end_reason"] as? String == "sub_tab_change")
        #expect(events[1].properties["stay_duration_sec"] as? Double == 1.23)
        #expect(events[2].properties["entry_type"] as? String == "user_select")
        #expect(events[2].properties["previous_sub_tab"] as? String == "killingpart_play")
        #expect(events[3].properties["end_reason"] as? String == "tab_change")
        #expect(events[3].properties["stay_duration_sec"] as? Double == 2.5)
    }

    @Test func diaryCreateRequestEncodesMusicCategory() throws {
        let request = DiaryCreateRequest(
            artist: "NewJeans",
            musicTitle: "Ditto",
            albumImageUrl: "https://example.com/album.jpg",
            videoUrl: "video-id",
            scope: .public,
            content: "좋아하는 구간",
            duration: "00:30",
            totalDuration: "03:05",
            start: "00:10",
            end: "00:40",
            musicMetadata: MusicMetadata(
                sourceType: "ITUNES",
                trackId: "1659513441",
                artistId: "1591118672",
                primaryGenreName: "K-Pop"
            )
        )

        let json = try #require(encodedJSONObject(request))
        let metadata = try #require(json["musicMetadata"] as? [String: Any])

        #expect(metadata["primaryGenreName"] as? String == "K-Pop")
    }

    @Test func diaryUpdateRequestEncodesMusicCategory() throws {
        let request = DiaryUpdateRequest(
            content: "수정한 코멘트",
            musicMetadata: MusicMetadata(
                sourceType: "ITUNES",
                trackId: "1659513441",
                artistId: "1591118672",
                primaryGenreName: "K-Pop"
            )
        )

        let json = try #require(encodedJSONObject(request))
        let metadata = try #require(json["musicMetadata"] as? [String: Any])

        #expect(metadata["primaryGenreName"] as? String == "K-Pop")
    }

    private func encodedJSONObject<T: Encodable>(_ value: T) -> [String: Any]? {
        let data = try? JSONEncoder().encode(value)
        guard let data else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

}
