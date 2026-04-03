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
