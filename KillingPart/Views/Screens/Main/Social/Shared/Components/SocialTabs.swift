import Foundation

enum SocialTopTab: CaseIterable {
    case feed
    case friend

    var title: String {
        switch self {
        case .feed:
            return "피드"
        case .friend:
            return "친구"
        }
    }

    var analyticsName: SubTabAnalyticsName {
        switch self {
        case .feed:
            return .feed
        case .friend:
            return .friends
        }
    }
}

enum SocialFriendSection: CaseIterable {
    case myPick
    case myFandom

    var title: String {
        switch self {
        case .myPick:
            return "나의 픽"
        case .myFandom:
            return "나의 팬덤"
        }
    }
}
