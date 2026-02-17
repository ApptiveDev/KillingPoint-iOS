import SwiftUI

struct MyCollectionProfileSettingsSection: View {
    let displayName: String
    let displayTag: String
    let profileImageURL: URL?
    let errorMessage: String?
    let isProcessing: Bool
    let onBackTap: () -> Void
    let onAccountActionTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            MyCollectionProfileSettingsHeaderView(onBackTap: onBackTap)

            MyCollectionProfileSettingsInfoCardView(
                displayName: displayName,
                displayTag: displayTag,
                profileImageURL: profileImageURL
            )

            if let errorMessage {
                Text(errorMessage)
                    .font(AppFont.paperlogy4Regular(size: 13))
                    .foregroundStyle(.red.opacity(0.95))
            }

            MyCollectionAccountActionButton(
                isProcessing: isProcessing,
                action: onAccountActionTap
            )
            .padding(.top, AppSpacing.s)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.bottom, AppSpacing.l)
    }
}
