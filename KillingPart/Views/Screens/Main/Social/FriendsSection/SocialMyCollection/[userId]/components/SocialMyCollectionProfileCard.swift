import SwiftUI

struct SocialMyCollectionProfileCard: View {
    let displayName: String
    let displayTag: String
    let profileImageURL: URL?
    let killingPartStatText: String
    let fanStatText: String
    let pickStatText: String
    let isMyPick: Bool
    let onFanStatTap: () -> Void
    let onPickStatTap: () -> Void
    let onPickToggleTap: () -> Void

    private let profileInfoMinWidth: CGFloat = 84
    private let profileInfoMaxWidth: CGFloat = 120

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            HStack(alignment: .top, spacing: AppSpacing.m) {
                MyCollectionProfileImageView(
                    profileImageURL: profileImageURL,
                    size: 56,
                    iconSize: 22
                )
                VStack(alignment: .leading, spacing: AppSpacing.s) {
                    HStack(alignment: .center, spacing: AppSpacing.s) {
                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            Text(displayName)
                                .font(AppFont.paperlogy6SemiBold(size: 16))
                                .foregroundStyle(Color.kpPrimary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)

                            Text(displayTag)
                                .font(AppFont.paperlogy4Regular(size: 13))
                                .foregroundStyle(Color.kpPrimary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .minimumScaleFactor(0.85)
                        }
                        .frame(minWidth: profileInfoMinWidth, maxWidth: profileInfoMaxWidth, alignment: .leading)
                        .layoutPriority(1)

                        HStack(alignment: .center, spacing: AppSpacing.s) {
                            MyCollectionProfileStatItemView(value: killingPartStatText, title: "킬링파트")
                                .frame(maxWidth: .infinity)

                            Button(action: onFanStatTap) {
                                MyCollectionProfileStatItemView(value: fanStatText, title: "팬덤")
                                    .frame(maxWidth: .infinity)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            Button(action: onPickStatTap) {
                                MyCollectionProfileStatItemView(value: pickStatText, title: "PICKS")
                                    .frame(maxWidth: .infinity)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .clipped()
                    }
                    SocialMyCollectionPickToggleButton(
                        isMyPick: isMyPick,
                        onTap: onPickToggleTap
                    )
                }
            }
        }
        .padding(AppSpacing.m)
    }
}
