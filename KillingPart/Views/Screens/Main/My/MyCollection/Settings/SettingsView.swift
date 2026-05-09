import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: ProfileSettingViewModel
    let onUserUpdated: (UserModel) -> Void
    let onLogoutTap: () -> Void
    let onWithdrawalTap: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var isWithdrawalDialogPresented = false
    @State private var isWebsiteDialogPresented = false
    @State private var isFeedbackSheetPresented = false
    @StateObject private var blocklistViewModel = BlocklistViewModel()
    @StateObject private var settingsViewModel = SettingsViewModel()
    
    private let withdrawalDialogAnimation: Animation = .spring(response: 0.32, dampingFraction: 0.9)
    private let websiteURLString = "https://sites.google.com/view/killingpart/"

    private var isAnyDialogPresented: Bool {
        isWithdrawalDialogPresented || isWebsiteDialogPresented
    }

    private var appVersionText: String {
        let shortVersion = (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let buildVersion = (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedVersion: String
        if let shortVersion, !shortVersion.isEmpty {
            resolvedVersion = shortVersion
        } else if let buildVersion, !buildVersion.isEmpty {
            resolvedVersion = buildVersion
        } else {
            resolvedVersion = "0.0.0"
        }
        return "v\(resolvedVersion)"
    }

    private var loginProviderText: String {
        let socialType = viewModel.user?.socialType.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        switch socialType.uppercased() {
        case "KAKAO":
            return "Kakao"
        case "GOOGLE":
            return "Google"
        case "APPLE":
            return "Apple"
        default:
            return socialType.isEmpty ? "-" : socialType.capitalized
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.m) {
                    header
                    profileSettingsCard
                    blockManagementSection
                    appInfoSection
                    accountSection
                    feedbackSection

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
                .padding(.horizontal, AppSpacing.m)
                .padding(.bottom, max(geometry.safeAreaInsets.bottom + AppSpacing.l, AppSpacing.l))
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .scrollIndicators(.hidden)
            .navigationBarBackButtonHidden()
            .overlay {
                ZStack {
                    if isAnyDialogPresented {
                        Color.black.opacity(0.58)
                            .ignoresSafeArea()
                            .onTapGesture {
                                withAnimation(withdrawalDialogAnimation) {
                                    isWithdrawalDialogPresented = false
                                    isWebsiteDialogPresented = false
                                }
                            }
                            .transition(.opacity)
                    }
                    
                    if isWithdrawalDialogPresented {
                        SettingsWithdrawalDialog(
                            onCancel: {
                                withAnimation(withdrawalDialogAnimation) {
                                    isWithdrawalDialogPresented = false
                                }
                            },
                            onConfirm: {
                                withAnimation(withdrawalDialogAnimation) {
                                    isWithdrawalDialogPresented = false
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    onWithdrawalTap()
                                }
                            }
                        )
                        .transition(.offset(y: 18).combined(with: .opacity))
                    }

                    if isWebsiteDialogPresented {
                        SettingsWebsiteRedirectDialog(
                            onCancel: {
                                withAnimation(withdrawalDialogAnimation) {
                                    isWebsiteDialogPresented = false
                                }
                            },
                            onConfirm: {
                                withAnimation(withdrawalDialogAnimation) {
                                    isWebsiteDialogPresented = false
                                }
                                guard let url = URL(string: websiteURLString) else { return }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    openURL(url)
                                }
                            }
                        )
                        .transition(.offset(y: 18).combined(with: .opacity))
                    }
                }
            }
            .animation(withdrawalDialogAnimation, value: isWithdrawalDialogPresented)
            .animation(withdrawalDialogAnimation, value: isWebsiteDialogPresented)
            .sheet(isPresented: $isFeedbackSheetPresented) {
                SettingsFeedbackSheet(
                    viewModel: settingsViewModel,
                    onCancel: {
                        isFeedbackSheetPresented = false
                    },
                    onSubmit: {
                        Task {
                            let isSuccess = await settingsViewModel.submitFeedback()
                            if isSuccess {
                                isFeedbackSheetPresented = false
                            }
                        }
                    }
                )
            }
        }
        .onAppear {
            viewModel.errorMessage = nil
            viewModel.successMessage = nil
            Task {
                await blocklistViewModel.loadInitialDataIfNeeded()
            }
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
                withAnimation(withdrawalDialogAnimation) {
                    isWithdrawalDialogPresented = true
                }
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
    
    private var blockManagementSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("차단 관리")
                .font(AppFont.paperlogy4Regular(size: 12))
                .foregroundStyle(Color.white.opacity(0.62))
            
            NavigationLink {
                BlocklistView(viewModel: blocklistViewModel)
            } label: {
                HStack(spacing: AppSpacing.s) {
                    Text("차단 목록")
                        .font(AppFont.paperlogy4Regular(size: 14))
                        .foregroundStyle(.white)
                    
                    Spacer(minLength: 0)
                    
                    if blocklistViewModel.isLoadingInitial && blocklistViewModel.totalBlockedUsers == 0 {
                        ProgressView()
                            .tint(Color.white.opacity(0.6))
                            .scaleEffect(0.8)
                    } else {
                        Text(blocklistViewModel.blockedUsersCountText)
                            .font(AppFont.paperlogy4Regular(size: 13))
                            .foregroundStyle(Color.white.opacity(0.28))
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.28))
                }
                .padding(.horizontal, AppSpacing.m)
                .padding(.vertical, 18)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            }
        }
    }

    private var appInfoSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("앱 정보")
                .font(AppFont.paperlogy4Regular(size: 12))
                .foregroundStyle(Color.white.opacity(0.62))

            VStack(spacing: 0) {
                SettingsValueRowLabel(
                    title: "앱 버전",
                    value: appVersionText
                )

                Divider()
                    .background(Color.white.opacity(0.08))

                NavigationLink {
                    ServiceTermView()
                } label: {
                    SettingsNavigationRowLabel(title: "이용약관")
                }
                .buttonStyle(.plain)

                Divider()
                    .background(Color.white.opacity(0.08))

                NavigationLink {
                    PrivacyPolicyView()
                } label: {
                    SettingsNavigationRowLabel(title: "개인정보처리방침")
                }
                .buttonStyle(.plain)

                Divider()
                    .background(Color.white.opacity(0.08))

                Button(action: {
                    withAnimation(withdrawalDialogAnimation) {
                        isWebsiteDialogPresented = true
                    }
                }) {
                    SettingsExternalLinkRowLabel(title: "웹사이트")
                }
                .buttonStyle(.plain)
            }
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            }
        }
    }

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("계정")
                .font(AppFont.paperlogy4Regular(size: 12))
                .foregroundStyle(Color.white.opacity(0.62))

            SettingsValueRowLabel(
                title: "로그인 정보",
                value: loginProviderText
            )
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            }
        }
    }

    private var feedbackSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Button {
                settingsViewModel.prepareFeedbackSheet()
                isFeedbackSheetPresented = true
            } label: {
                SettingsFeedbackRowLabel()
            }
            .buttonStyle(.plain)

            if let successMessage = settingsViewModel.feedbackSuccessMessage {
                Text(successMessage)
                    .font(AppFont.paperlogy4Regular(size: 12))
                    .foregroundStyle(AppColors.primary600.opacity(0.95))
            }
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

private struct SettingsValueRowLabel: View {
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: AppSpacing.s) {
            Text(title)
                .font(AppFont.paperlogy4Regular(size: 14))
                .foregroundStyle(Color.white)

            Spacer(minLength: AppSpacing.s)

            Text(value)
                .font(AppFont.paperlogy4Regular(size: 13))
                .foregroundStyle(Color.white.opacity(0.3))
                .lineLimit(1)
        }
        .padding(.horizontal, AppSpacing.m)
        .padding(.vertical, 18)
        .contentShape(Rectangle())
    }
}

private struct SettingsExternalLinkRowLabel: View {
    let title: String

    var body: some View {
        HStack(spacing: AppSpacing.s) {
            Text(title)
                .font(AppFont.paperlogy4Regular(size: 14))
                .foregroundStyle(Color.white)

            Spacer(minLength: AppSpacing.s)

            Image(systemName: "arrow.up.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.35))
        }
        .padding(.horizontal, AppSpacing.m)
        .padding(.vertical, 18)
        .contentShape(Rectangle())
    }
}

private struct SettingsFeedbackRowLabel: View {
    var body: some View {
        HStack(spacing: AppSpacing.s) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color.kpPrimary.opacity(0.9), lineWidth: 1)
                    .frame(width: 24, height: 24)

                Image(systemName: "envelope")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.kpPrimary.opacity(0.95))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("문의 및 피드백!")
                    .font(AppFont.paperlogy5Medium(size: 14))
                    .foregroundStyle(.white)

                Text("의견을 보내주세요!")
                    .font(AppFont.paperlogy4Regular(size: 12))
                    .foregroundStyle(.white.opacity(0.45))
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppSpacing.m)
        .padding(.vertical, AppSpacing.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Color.kpPrimary)
                .frame(width: 3, height: 46)
                .padding(.leading, 1)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
    }
}

private struct SettingsFeedbackSheet: View {
    @ObservedObject var viewModel: SettingsViewModel
    let onCancel: () -> Void
    let onSubmit: () -> Void

    @FocusState private var isEditorFocused: Bool

    var body: some View {
        VStack(spacing: AppSpacing.m) {
            Text("킬링파트 팀에게 문의사항이나\n개선할 점을 알려주세요!")
                .font(AppFont.paperlogy5Medium(size: 14))
                .foregroundStyle(.white.opacity(0.95))
                .multilineTextAlignment(.center)

            ZStack(alignment: .topLeading) {
                TextEditor(
                    text: Binding(
                        get: { viewModel.feedbackContent },
                        set: { viewModel.updateFeedbackContent($0) }
                    )
                )
                .focused($isEditorFocused)
                .font(AppFont.paperlogy4Regular(size: 14))
                .foregroundStyle(.white)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.clear)

                if viewModel.feedbackContent.isEmpty {
                    Text("문의사항 및 피드백...")
                        .font(AppFont.paperlogy4Regular(size: 14))
                        .foregroundStyle(.white.opacity(0.4))
                        .padding(.top, 15)
                        .padding(.leading, 15)
                }
            }
            .frame(height: 170)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            }

            if let errorMessage = viewModel.feedbackErrorMessage {
                Text(errorMessage)
                    .font(AppFont.paperlogy4Regular(size: 12))
                    .foregroundStyle(Color(hex: "#FF676F"))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: AppSpacing.s) {
                Button(action: onCancel) {
                    Text("돌아가기")
                        .font(AppFont.paperlogy6SemiBold(size: 14))
                        .foregroundStyle(.black.opacity(0.9))
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isSubmittingFeedback)

                Button(action: onSubmit) {
                    Group {
                        if viewModel.isSubmittingFeedback {
                            ProgressView()
                                .tint(.black.opacity(0.8))
                        } else {
                            Text("보내기")
                                .font(AppFont.paperlogy6SemiBold(size: 14))
                        }
                    }
                    .foregroundStyle(.black.opacity(0.9))
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        viewModel.canSubmitFeedback ? Color.kpPrimary : Color.kpPrimary.opacity(0.45),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.canSubmitFeedback)
            }
        }
        .padding(.horizontal, AppSpacing.m)
        .padding(.top, AppSpacing.m)
        .padding(.bottom, AppSpacing.m)
        .presentationDetents([.height(420)])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(viewModel.isSubmittingFeedback)
        .presentationBackground(Color(hex: "#242527"))
        .preferredColorScheme(.dark)
        .onAppear {
            isEditorFocused = true
        }
    }
}

private struct SettingsWithdrawalDialog: View {
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        VStack(spacing: AppSpacing.s) {
            Text("!")
                .font(.system(size: 22, weight: .heavy))
                .foregroundStyle(Color(hex: "#FF676F"))

            Text("정말 탈퇴하시겠어요?")
                .font(AppFont.paperlogy6SemiBold(size: 18))
                .foregroundStyle(.white)

            Text("기존 데이터는 즉시 삭제되며 복구할 수 없습니다.")
                .font(AppFont.paperlogy4Regular(size: 12))
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)

            HStack(spacing: AppSpacing.s) {
                Button(action: onCancel) {
                    Label("돌아가기", systemImage: "arrow.left")
                        .font(AppFont.paperlogy6SemiBold(size: 14))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)

                Button(action: onConfirm) {
                    Text("탈퇴하기")
                        .font(AppFont.paperlogy6SemiBold(size: 14))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color(hex: "#FF676F"), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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

private struct SettingsWebsiteRedirectDialog: View {
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        VStack(spacing: AppSpacing.m) {
            Image(systemName: "arrow.up.right")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Color.kpPrimary)

            Text("외부 웹사이트로 이동합니다.")
                .font(AppFont.paperlogy5Medium(size: 14))
                .foregroundStyle(.white.opacity(0.95))

            HStack(spacing: AppSpacing.s) {
                Button(action: onCancel) {
                    Text("취소")
                        .font(AppFont.paperlogy6SemiBold(size: 14))
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)

                Button(action: onConfirm) {
                    Text("이동하기")
                        .font(AppFont.paperlogy6SemiBold(size: 14))
                        .foregroundStyle(.black.opacity(0.9))
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.kpPrimary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
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
