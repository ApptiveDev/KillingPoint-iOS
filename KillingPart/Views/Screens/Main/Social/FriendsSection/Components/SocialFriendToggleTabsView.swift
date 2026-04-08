import SwiftUI

struct SocialFriendToggleTabsView: View {
    @Binding var selectedFriendSection: SocialFriendSection
    let myPickCount: Int
    let myFandomCount: Int

    var body: some View {
        HStack(spacing: AppSpacing.s) {
            ForEach(SocialFriendSection.allCases, id: \.self) { section in
                Button {
                    selectedFriendSection = section
                } label: {
                    HStack(spacing: 6) {
                        Text(section.title)
                            .font(AppFont.paperlogy5Medium(size: 13))
                            .foregroundStyle(.white)

                        Text(totalCountText(for: section))
                            .font(AppFont.paperlogy4Regular(size: 12))
                            .foregroundStyle(Color.kpPrimary.opacity(0.8))
                    }
                    .padding(.vertical, AppSpacing.xs)
                }
                .buttonStyle(.plain)
                .opacity(selectedFriendSection == section ? 1 : 0.45)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func totalCountText(for section: SocialFriendSection) -> String {
        switch section {
        case .myPick:
            return myPickCount.formatted()
        case .myFandom:
            return myFandomCount.formatted()
        }
    }
}
