import SwiftUI

struct MyCollectionProfileCard: View {
    let displayName: String
    let displayTag: String
    let profileImageURL: URL?
    let killingPartStatText: String
    let fanStatText: String
    let pickStatText: String
    let onFanStatTap: () -> Void
    let onPickStatTap: () -> Void
    let onEditProfileTap: () -> Void
    var showEditButton: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            HStack(alignment: .top, spacing: AppSpacing.m) {
                MyCollectionProfileImageView(
                    profileImageURL: profileImageURL,
                    size: 56,
                    iconSize: 22
                )
                VStack(alignment: .leading, spacing: AppSpacing.s) {
                    HStack(alignment: .center, spacing: AppSpacing.m) {
                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            Text(displayName)
                                .font(AppFont.paperlogy6SemiBold(size: 16))
                                .foregroundStyle(Color.kpPrimary)
                                .lineLimit(1)

                            Text(displayTag)
                                .font(AppFont.paperlogy4Regular(size: 13))
                                .foregroundStyle(Color.kpPrimary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .minimumScaleFactor(0.85)
                        }

                        HStack(alignment: .center, spacing: AppSpacing.m) {
                            MyCollectionProfileStatItemView(value: killingPartStatText, title: "킬링파트")
                            Button(action: onFanStatTap) {
                                MyCollectionProfileStatItemView(value: fanStatText, title: "팬덤")
                            }
                            .buttonStyle(.plain)

                            Button(action: onPickStatTap) {
                                MyCollectionProfileStatItemView(value: pickStatText, title: "PICKS")
                            }
                            .buttonStyle(.plain)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                    if showEditButton {
                        MyCollectionEditProfileButton(action: onEditProfileTap)
                    }
                }
            }

            
        }
        .padding(AppSpacing.m)
    }
}
