import SwiftUI

struct SocialFeedProfileView: View {
    let feed: DiaryFeedModel

    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            SocialFriendProfileImageView(profileImageURL: profileImageURL)

            VStack(alignment: .leading, spacing: 2) {
                Text(feed.username?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? (feed.username ?? "") : "알 수 없음")
                    .font(AppFont.paperlogy5Medium(size: 13))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(feed.tag?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? "@\(feed.tag ?? "")" : "")
                    .font(AppFont.paperlogy4Regular(size: 11))
                    .foregroundStyle(Color.kpPrimary)
                    .lineLimit(1)
            }
        }
    }

    private var profileImageURL: URL? {
        guard let raw = feed.profileImageUrl?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        if let url = URL(string: raw), url.scheme != nil {
            return url
        }
        return URL(string: "https://\(raw)")
    }
}
