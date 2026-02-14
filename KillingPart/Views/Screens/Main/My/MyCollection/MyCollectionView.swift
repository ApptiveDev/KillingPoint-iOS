import SwiftUI

struct MyCollectionView: View {
    let onSessionEnded: () -> Void

    @StateObject private var viewModel: MyCollectionViewModel
    @State private var screenMode: MyCollectionScreenMode = .collectionList
    @State private var isAccountActionDialogPresented = false

    init(
        onSessionEnded: @escaping () -> Void,
        authenticationService: AuthenticationServicing = AuthenticationService()
    ) {
        self.onSessionEnded = onSessionEnded
        _viewModel = StateObject(
            wrappedValue: MyCollectionViewModel(authenticationService: authenticationService)
        )
    }

    var body: some View {
        Group {
            switch screenMode {
            case .collectionList:
                collectionListSection
            case .profileSettings:
                profileSettingsSection
            }
        }
        .confirmationDialog("계정", isPresented: $isAccountActionDialogPresented, titleVisibility: .visible) {
            Button("로그아웃", role: .destructive) {
                viewModel.logout(onSuccess: onSessionEnded)
            }
            Button("회원탈퇴", role: .destructive) {
                viewModel.deleteMyAccount(onSuccess: onSessionEnded)
            }
            Button("취소", role: .cancel) {}
        }
    }

    private var collectionListSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.m) {
                profileCard

                Text("내 컬렉션")
                    .font(AppFont.paperlogy7Bold(size: 24))
                    .foregroundStyle(.white)

                Text("저장한 킬링파트를 모아보는 공간입니다.")
                    .font(AppFont.paperlogy4Regular(size: 15))
                    .foregroundStyle(.white.opacity(0.75))

                ForEach(1...4, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 110)
                        .overlay(alignment: .leading) {
                            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                Text("Collection \(index)")
                                    .font(AppFont.paperlogy6SemiBold(size: 16))
                                    .foregroundStyle(.white)

                                Text("아티스트와 코멘트가 표시될 카드 영역")
                                    .font(AppFont.paperlogy4Regular(size: 13))
                                    .foregroundStyle(.white.opacity(0.68))
                            }
                            .padding(AppSpacing.m)
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        }
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(AppFont.paperlogy4Regular(size: 13))
                        .foregroundStyle(.red.opacity(0.95))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, AppSpacing.l)
        }
    }

    private var profileCard: some View {
        HStack(spacing: AppSpacing.m) {
            Circle()
                .fill(Color.white.opacity(0.12))
                .frame(width: 56, height: 56)
                .overlay {
                    Image(systemName: "person.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.white.opacity(0.9))
                }

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("킬링파트 사용자")
                    .font(AppFont.paperlogy6SemiBold(size: 16))
                    .foregroundStyle(.white)

                Text("@killingpart_user")
                    .font(AppFont.paperlogy4Regular(size: 13))
                    .foregroundStyle(.white.opacity(0.7))
            }

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    screenMode = .profileSettings
                }
            } label: {
                Text("프로필 설정")
                    .font(AppFont.paperlogy5Medium(size: 13))
                    .foregroundStyle(.white)
                    .padding(.vertical, AppSpacing.xs)
                    .padding(.horizontal, AppSpacing.s)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(AppSpacing.m)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        }
    }

    private var profileSettingsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            HStack {
                Text("프로필 설정")
                    .font(AppFont.paperlogy7Bold(size: 24))
                    .foregroundStyle(.white)

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        screenMode = .collectionList
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .semibold))
                        Text("뒤로가기")
                            .font(AppFont.paperlogy5Medium(size: 13))
                    }
                    .foregroundStyle(.white)
                    .padding(.vertical, AppSpacing.xs)
                    .padding(.horizontal, AppSpacing.s)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: AppSpacing.m) {
                Circle()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 92, height: 92)
                    .overlay {
                        Image(systemName: "person.fill")
                            .font(.system(size: 34))
                            .foregroundStyle(.white.opacity(0.9))
                    }

                VStack(alignment: .leading, spacing: AppSpacing.s) {
                    profileInfoRow(title: "이름", value: "킬링파트 사용자")
                    profileInfoRow(title: "아이디", value: "@killingpart_user")
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

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(AppFont.paperlogy4Regular(size: 13))
                    .foregroundStyle(.red.opacity(0.95))
            }

            Button {
                guard !viewModel.isProcessing else { return }
                isAccountActionDialogPresented = true
            } label: {
                Text("로그아웃/회원탈퇴")
                    .font(AppFont.paperlogy5Medium(size: 15))
                    .underline()
                    .foregroundStyle(.white.opacity(0.9))
                .frame(maxWidth: .infinity)
            }
            .disabled(viewModel.isProcessing)
            .padding(.top, AppSpacing.s)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.bottom, AppSpacing.l)
    }

    @ViewBuilder
    private func profileInfoRow(title: String, value: String) -> some View {
        HStack(spacing: AppSpacing.s) {
            Text(title)
                .font(AppFont.paperlogy5Medium(size: 14))
                .foregroundStyle(.white.opacity(0.72))
                .frame(width: 48, alignment: .leading)

            Text(value)
                .font(AppFont.paperlogy5Medium(size: 14))
                .foregroundStyle(.white)
        }
        .padding(.vertical, AppSpacing.xs)
    }
}

private enum MyCollectionScreenMode {
    case collectionList
    case profileSettings
}

@MainActor
private final class MyCollectionViewModel: ObservableObject {
    @Published private(set) var isProcessing = false
    @Published var errorMessage: String?

    private let authenticationService: AuthenticationServicing

    init(authenticationService: AuthenticationServicing) {
        self.authenticationService = authenticationService
    }

    func logout(onSuccess: @escaping () -> Void) {
        guard !isProcessing else { return }

        isProcessing = true
        errorMessage = nil

        Task {
            defer { isProcessing = false }

            do {
                try await authenticationService.logout()
                onSuccess()
            } catch {
                errorMessage = resolveErrorMessage(from: error)
            }
        }
    }

    func deleteMyAccount(onSuccess: @escaping () -> Void) {
        guard !isProcessing else { return }

        isProcessing = true
        errorMessage = nil

        Task {
            defer { isProcessing = false }

            do {
                try await authenticationService.deleteMyAccount()
                onSuccess()
            } catch {
                errorMessage = resolveErrorMessage(from: error)
            }
        }
    }

    private func resolveErrorMessage(from error: Error) -> String {
        if let authError = error as? AuthenticationServiceError {
            return authError.errorDescription ?? "요청 처리에 실패했어요."
        }

        if let apiError = error as? APIClientError {
            return apiError.errorDescription ?? "요청 처리에 실패했어요."
        }

        if let localizedError = error as? LocalizedError {
            return localizedError.errorDescription ?? "요청 처리에 실패했어요."
        }

        return "요청 처리에 실패했어요."
    }
}
