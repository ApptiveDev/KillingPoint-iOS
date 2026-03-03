import SwiftUI

struct PlayKillingPartProfileSummaryCard: View {
    let profileImageURL: URL?
    let displayName: String
    let displayTag: String

    var body: some View {
        HStack(spacing: AppSpacing.s) {
            MyCollectionProfileImageView(
                profileImageURL: profileImageURL,
                size: 56,
                iconSize: 22
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(displayName)
                    .font(AppFont.paperlogy6SemiBold(size: 16))
                    .foregroundStyle(Color.kpPrimary)
                    .lineLimit(1)

                Text(displayTag)
                    .font(AppFont.paperlogy4Regular(size: 13))
                    .foregroundStyle(Color.kpPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: 0)
        }
        .padding(AppSpacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
