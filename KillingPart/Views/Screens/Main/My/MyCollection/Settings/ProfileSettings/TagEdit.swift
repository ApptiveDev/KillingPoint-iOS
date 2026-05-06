import SwiftUI

struct TagEdit: View {
    @ObservedObject var viewModel: ProfileSettingViewModel
    let onUserUpdated: (UserModel) -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var isTagFieldFocused: Bool

    var body: some View {
        GeometryReader { geometry in
            let horizontalPadding = AppSpacing.l
            let safeAreaBottomInset = geometry.safeAreaInsets.bottom
            let bottomPadding = max(safeAreaBottomInset + AppSpacing.s, AppSpacing.l)
            let contentTopOffset = max(
                geometry.safeAreaInsets.top + AppSpacing.xl,
                geometry.size.height * 0.2
            )

            VStack(spacing: 0) {
                SettingsSubpageHeader(title: "태그 변경") {
                    dismiss()
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.top, AppSpacing.s)

                VStack(alignment: .leading, spacing: AppSpacing.s) {
                    Text("개성을 나타내는 태그를 정해주세요")
                        .font(AppFont.paperlogy7Bold(size: 24))
                        .foregroundStyle(.white)

                    Text("언제든지 바꿀 수 있습니다")
                        .font(AppFont.paperlogy4Regular(size: 14))
                        .foregroundStyle(.white)

                    Text("*영문 소문자 4자 이상, 30자 이내, 특수문자 일부[.][_]")
                        .font(AppFont.paperlogy4Regular(size: 12))
                        .foregroundStyle(.white.opacity(0.55))

                    HStack(spacing: AppSpacing.xs) {
                        Text("@")
                            .font(AppFont.paperlogy5Medium(size: 18))
                            .foregroundStyle(.white.opacity(0.7))

                        TextField("태그 입력", text: $viewModel.tagDraft)
                            .focused($isTagFieldFocused)
                            .font(AppFont.paperlogy5Medium(size: 16))
                            .foregroundStyle(.white)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    .padding(.horizontal, AppSpacing.m)
                    .padding(.vertical, AppSpacing.m)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    }

                    if let validation = viewModel.validateTag(viewModel.tagDraft), !viewModel.tagDraft.isEmpty {
                        Text(validation)
                            .font(AppFont.paperlogy4Regular(size: 13))
                            .foregroundStyle(.red.opacity(0.95))
                    } else if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(AppFont.paperlogy4Regular(size: 13))
                            .foregroundStyle(.red.opacity(0.95))
                    } else if let successMessage = viewModel.successMessage {
                        Text(successMessage)
                            .font(AppFont.paperlogy4Regular(size: 13))
                            .foregroundStyle(AppColors.primary600.opacity(0.95))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, horizontalPadding)
                .padding(.top, contentTopOffset)

                Spacer(minLength: 0)

                PrimaryButton(title: "저장", isLoading: viewModel.isProcessing) {
                    Task {
                        if let updatedUser = await viewModel.updateTag() {
                            onUserUpdated(updatedUser)
                            dismiss()
                        }
                    }
                }
                .disabled(!viewModel.canSubmitTagUpdate || viewModel.isProcessing)
                .opacity((viewModel.canSubmitTagUpdate && !viewModel.isProcessing) ? 1 : 0.45)
                .padding(.horizontal, horizontalPadding)
                .padding(.bottom, bottomPadding)
            }
        }
        .background(
            LinearGradient(
                colors: [Color.black, Color(hex: "#10131B")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .onAppear {
            viewModel.errorMessage = nil
            viewModel.successMessage = nil
        }
        .onChange(of: viewModel.tagDraft) { _ in
            viewModel.errorMessage = nil
            viewModel.successMessage = nil
        }
        .navigationBarBackButtonHidden()
    }
}
