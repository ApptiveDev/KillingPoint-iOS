import SwiftUI

struct SocialFriendRowView: View {
    let user: SocialListUser

    var body: some View {
        HStack(spacing: AppSpacing.s) {
            SocialFriendProfileImageView(profileImageURL: user.profileImageURL)

            VStack(alignment: .leading, spacing: 4) {
                Text(user.displayName)
                    .font(AppFont.paperlogy5Medium(size: 14))
                    .foregroundStyle(.white)

                Text(user.displayTag)
                    .font(AppFont.paperlogy4Regular(size: 12))
                    .foregroundStyle(Color.white.opacity(0.7))
            }

            Spacer()
        }
        .padding(.horizontal, AppSpacing.m)
        .padding(.vertical, AppSpacing.s)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        }
    }
}
