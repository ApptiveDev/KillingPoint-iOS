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
                            .foregroundStyle(Color.white.opacity(0.8))
                    }
                    .padding(.vertical, AppSpacing.xs)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(
                                selectedFriendSection == section
                                    ? AppColors.primary600.opacity(0.2)
                                    : Color.white.opacity(0.06)
                            )
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(
                                selectedFriendSection == section
                                    ? AppColors.primary600.opacity(0.8)
                                    : Color.white.opacity(0.2),
                                lineWidth: 1
                            )
                    }
                }
                .buttonStyle(.plain)
                .opacity(selectedFriendSection == section ? 1 : 0.45)
            }
        }
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
