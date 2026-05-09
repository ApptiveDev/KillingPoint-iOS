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

    private let tagAreaMaxWidth: CGFloat = 120

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
                                .lineLimit(2)
                                .truncationMode(.tail)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: tagAreaMaxWidth, alignment: .leading)

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
                        .fixedSize(horizontal: true, vertical: false)
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
