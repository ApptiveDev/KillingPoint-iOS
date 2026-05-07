import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: ProfileSettingViewModel
    let onUserUpdated: (UserModel) -> Void
    let onLogoutTap: () -> Void
    let onWithdrawalTap: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isWithdrawalDialogPresented = false

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.m) {
                    header
                    profileSettingsCard

                    if let successMessage = viewModel.successMessage {
                        Text(successMessage)
                            .font(AppFont.paperlogy4Regular(size: 13))
                            .foregroundStyle(AppColors.primary600.opacity(0.95))
                    }

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(AppFont.paperlogy4Regular(size: 13))
                            .foregroundStyle(.red.opacity(0.95))
                    }

                    accountActionCard
                }
                .padding(.bottom, max(geometry.safeAreaInsets.bottom + AppSpacing.l, AppSpacing.l))
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .scrollIndicators(.hidden)
            .navigationBarBackButtonHidden()
            .overlay {
                if isWithdrawalDialogPresented {
                    SettingsWithdrawalDialog(
                        onCancel: {
                            isWithdrawalDialogPresented = false
                        },
                        onConfirm: {
                            isWithdrawalDialogPresented = false
                            onWithdrawalTap()
                        }
                    )
                }
            }
        }
        .onAppear {
            viewModel.errorMessage = nil
            viewModel.successMessage = nil
        }
    }

    private var header: some View {
        ZStack {
            Text("설정")
                .font(AppFont.paperlogy6SemiBold(size: 18))
                .foregroundStyle(Color.white)

            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)

                Spacer()
            }
        }
        .frame(height: 44)
    }

    private var profileSettingsCard: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: AppSpacing.m) {
                MyCollectionProfileImageView(
                    profileImageURL: viewModel.profileImageURL,
                    size: 68,
                    iconSize: 28
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.displayName)
                        .font(AppFont.paperlogy6SemiBold(size: 18))
                        .foregroundStyle(Color.white)
                        .lineLimit(1)

                    Text(viewModel.displayTag)
                        .font(AppFont.paperlogy4Regular(size: 15))
                        .foregroundStyle(Color.white.opacity(0.85))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .padding(AppSpacing.m)

            Divider()
                .background(Color.white.opacity(0.08))

            NavigationLink {
                NameEdit(
                    viewModel: viewModel,
                    onUserUpdated: onUserUpdated
                )
            } label: {
                SettingsNavigationRowLabel(title: "이름 변경")
            }
            .buttonStyle(.plain)

            Divider()
                .background(Color.white.opacity(0.08))

            NavigationLink {
                TagEdit(
                    viewModel: viewModel,
                    onUserUpdated: onUserUpdated
                )
            } label: {
                SettingsNavigationRowLabel(title: "태그 변경")
            }
            .buttonStyle(.plain)

            Divider()
                .background(Color.white.opacity(0.08))

            NavigationLink {
                ProfileImageEdit(
                    viewModel: viewModel,
                    onUserUpdated: onUserUpdated
                )
            } label: {
                SettingsNavigationRowLabel(title: "프로필 이미지 변경")
            }
            .buttonStyle(.plain)
        }
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        }
    }

    private var accountActionCard: some View {
        VStack(spacing: 0) {
            Button(action: onLogoutTap) {
                Text("로그아웃")
                    .font(AppFont.paperlogy5Medium(size: 14))
                    .foregroundStyle(Color(red: 1, green: 0.39, blue: 0.39))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.m)
            }
            .buttonStyle(.plain)

            Divider()
                .background(Color.white.opacity(0.08))

            Button(action: {
                isWithdrawalDialogPresented = true
            }) {
                Text("회원탈퇴")
                    .font(AppFont.paperlogy5Medium(size: 14))
                    .foregroundStyle(Color.white.opacity(0.4))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.m)
            }
            .buttonStyle(.plain)
        }
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        }
    }
}

struct SettingsNavigationRowLabel: View {
    let title: String

    var body: some View {
        HStack(spacing: AppSpacing.s) {
            Text(title)
                .font(AppFont.paperlogy4Regular(size: 14))
                .foregroundStyle(Color.white)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.35))
        }
        .padding(.horizontal, AppSpacing.m)
        .padding(.vertical, 18)
        .contentShape(Rectangle())
    }
}

private struct SettingsWithdrawalDialog: View {
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.58)
                .ignoresSafeArea()
                .onTapGesture {
                    onCancel()
                }

            VStack(spacing: AppSpacing.s) {
                Text("!")
                    .font(.system(size: 32, weight: .heavy))
                    .foregroundStyle(Color(red: 1, green: 0.39, blue: 0.39))

                Text("정말 탈퇴하시겠어요?")
                    .font(AppFont.paperlogy6SemiBold(size: 26))
                    .foregroundStyle(.white)

                Text("기존 데이터는 즉시 삭제되며 복구할 수 없습니다.")
                    .font(AppFont.paperlogy5Medium(size: 16))
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)

                HStack(spacing: AppSpacing.s) {
                    Button(action: onCancel) {
                        Text("취소")
                            .font(AppFont.paperlogy6SemiBold(size: 20))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color(red: 1, green: 0.39, blue: 0.39))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)

                    Button(action: onConfirm) {
                        Text("탈퇴하기")
                            .font(AppFont.paperlogy6SemiBold(size: 20))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.white.opacity(0.45))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, AppSpacing.s)
            }
            .padding(AppSpacing.l)
            .frame(maxWidth: 560)
            .background(Color(hex: "#242527"))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            }
            .padding(.horizontal, AppSpacing.m)
        }
    }
}
