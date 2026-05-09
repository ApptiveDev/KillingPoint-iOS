import SwiftUI

struct PolicyAgreementScreen: View {
    @ObservedObject var viewModel: InitialSetupFlowViewModel
    @State private var activeDocument: PolicyDocumentType?

    var body: some View {
        GeometryReader { geometry in
            let horizontalPadding = max(AppSpacing.m, geometry.size.width * 0.08)
            let topPadding = geometry.safeAreaInsets.top + AppSpacing.l
            let bottomPadding = geometry.safeAreaInsets.bottom + AppSpacing.l
            let titleTopOffset = max(topPadding + AppSpacing.xl, geometry.size.height * 0.18)

            ZStack {
                LoginBackgroundVideoView()
                    .ignoresSafeArea()

                LinearGradient(
                    colors: [Color.black.opacity(0.36), Color.black.opacity(0.9)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    Image("loginTitle")
                        .resizable()
                        .scaledToFit()
                        .frame(width: min(geometry.size.width * 0.62, 280))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, horizontalPadding)
                        .padding(.top, titleTopOffset)

                    Spacer(minLength: 0)

                    VStack(alignment: .leading, spacing: AppSpacing.m) {
                        policyRow(
                            title: "서비스 이용약관",
                            isChecked: viewModel.isServiceTermsAgreed,
                            onTap: {
                                viewModel.isServiceTermsAgreed.toggle()
                            },
                            onSeeFullTextTap: {
                                activeDocument = .serviceTerms
                            }
                        )

                        policyRow(
                            title: "개인정보 처리방침",
                            isChecked: viewModel.isPrivacyAgreed,
                            onTap: {
                                viewModel.isPrivacyAgreed.toggle()
                            },
                            onSeeFullTextTap: {
                                activeDocument = .privacy
                            }
                        )

                        if let errorMessage = viewModel.errorMessage {
                            Text(errorMessage)
                                .font(AppFont.paperlogy4Regular(size: 13))
                                .foregroundStyle(.red.opacity(0.95))
                        }
                    }
                    .padding(.horizontal, horizontalPadding)
                    .padding(.bottom, AppSpacing.xl)

                    PrimaryButton(
                        title: "전체 동의 후 시작하기",
                        isLoading: viewModel.isLoading
                    ) {
                        Task {
                            await viewModel.submitPolicyAgreement()
                        }
                    }
                    .disabled(!viewModel.canSubmitPolicyAgreement || viewModel.isLoading)
                    .opacity((viewModel.canSubmitPolicyAgreement && !viewModel.isLoading) ? 1 : 0.45)
                    .padding(.horizontal, horizontalPadding)
                    .padding(.bottom, bottomPadding)
                }
            }
        }
        .sheet(item: $activeDocument) { documentType in
            PolicyDocumentView(
                documentType: documentType,
                showsCloseButton: true,
                embedsInNavigationStack: true
            )
                .preferredColorScheme(.dark)
        }
    }

    private func policyRow(
        title: String,
        isChecked: Bool,
        onTap: @escaping () -> Void,
        onSeeFullTextTap: @escaping () -> Void
    ) -> some View {
        HStack(spacing: AppSpacing.s) {
            Button(action: onTap) {
                Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isChecked ? AppColors.primary600 : .white.opacity(0.75))
            }
            .buttonStyle(.plain)

            Text(title)
                .font(AppFont.paperlogy4Regular(size: 15))
                .foregroundStyle(.white.opacity(0.9))

            Spacer(minLength: AppSpacing.s)

            Button(action: onSeeFullTextTap) {
                Text("전문확인")
                    .font(AppFont.paperlogy4Regular(size: 14))
                    .underline(true, color: AppColors.primary600.opacity(0.92))
                    .foregroundStyle(AppColors.primary600.opacity(0.92))
            }
            .buttonStyle(.plain)
        }
    }
}
