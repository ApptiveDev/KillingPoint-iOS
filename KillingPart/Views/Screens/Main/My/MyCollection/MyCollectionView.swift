import SwiftUI

struct MyCollectionView: View {
    let onSessionEnded: () -> Void

    @StateObject private var viewModel: MyCollectionViewModel
    @State private var isWithdrawAlertPresented = false

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
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.m) {
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

                actionSection
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, AppSpacing.l)
        }
        .alert("회원 탈퇴", isPresented: $isWithdrawAlertPresented) {
            Button("탈퇴", role: .destructive) {
                viewModel.deleteMyAccount(onSuccess: onSessionEnded)
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("정말 회원 탈퇴하시겠어요? 이 작업은 되돌릴 수 없습니다.")
        }
    }

    private var actionSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(AppFont.paperlogy4Regular(size: 13))
                    .foregroundStyle(.red.opacity(0.95))
            }

            Button {
                viewModel.logout(onSuccess: onSessionEnded)
            } label: {
                HStack(spacing: AppSpacing.s) {
                    if viewModel.isProcessing {
                        ProgressView()
                            .tint(.white)
                    }

                    Text("로그아웃")
                        .font(AppFont.paperlogy6SemiBold(size: 16))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.m)
                .background(Color.white.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(AppColors.primary600.opacity(0.65), lineWidth: 1)
                }
            }
            .disabled(viewModel.isProcessing)

            Button(role: .destructive) {
                isWithdrawAlertPresented = true
            } label: {
                Text("회원 탈퇴")
                    .font(AppFont.paperlogy6SemiBold(size: 15))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.m)
                    .background(Color.red.opacity(0.22))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.red.opacity(0.5), lineWidth: 1)
                    }
            }
            .disabled(viewModel.isProcessing)
        }
        .padding(.top, AppSpacing.s)
    }
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
