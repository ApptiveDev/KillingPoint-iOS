import SwiftUI

struct MyCollectionProfileSettingsInfoCardView: View {
    let displayName: String
    let displayTag: String
    let profileImageURL: URL?

    var body: some View {
        VStack(spacing: AppSpacing.m) {
            MyCollectionProfileImageView(
                profileImageURL: profileImageURL,
                size: 92,
                iconSize: 34
            )

            VStack(alignment: .leading, spacing: AppSpacing.s) {
                MyCollectionProfileSettingsInfoRowView(title: "이름", value: displayName)
                MyCollectionProfileSettingsInfoRowView(title: "아이디", value: displayTag)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(AppSpacing.m)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        }
    }
}
