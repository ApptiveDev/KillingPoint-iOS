import SwiftUI

struct TagEdit: View {
    @ObservedObject var viewModel: ProfileSettingViewModel
    let onUserUpdated: (UserModel) -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var isTagFieldFocused: Bool
    
    private var hasTagChanges: Bool {
        guard let user = viewModel.user else { return false }
        return viewModel.normalizedTag(viewModel.tagDraft) != viewModel.normalizedTag(user.tag)
    }
    
    private var isCompleteEnabled: Bool {
        hasTagChanges && !viewModel.isProcessing
    }

    var body: some View {
        let horizontalPadding = AppSpacing.l

        VStack(spacing: 0) {
            SettingsSubpageHeader(
                title: "태그 변경",
                titleColor: .white,
                titleFontSize: 18,
                backButtonColor: .white,
                trailingTitle: "완료",
                trailingColor: isCompleteEnabled ? .kpPrimary : .white.opacity(0.45),
                trailingDisabled: !isCompleteEnabled,
                onTrailingTap: submitTagUpdate
            ) {
                dismiss()
            }
            .padding(.horizontal, horizontalPadding)

            VStack(alignment: .leading, spacing: AppSpacing.s) {
                Text("태그")
                    .font(AppFont.paperlogy4Regular(size: 15))
                    .foregroundStyle(.white.opacity(0.85))
                
                HStack(spacing: AppSpacing.xs) {
                    Text("@")
                        .font(AppFont.paperlogy5Medium(size: 15))
                        .foregroundStyle(.white.opacity(0.7))
                    
                    TextField("태그 입력", text: $viewModel.tagDraft)
                        .focused($isTagFieldFocused)
                        .font(AppFont.paperlogy5Medium(size: 15))
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
                        .stroke(Color.kpPrimary, lineWidth: 1)
                }
                
                Text("영문 소문자 4자 이상, 30자 이내,특수문자 일부[.][_]")
                    .font(AppFont.paperlogy4Regular(size: 12))
                    .foregroundStyle(.white.opacity(0.55))

                if let validation = viewModel.validateTag(viewModel.tagDraft), !viewModel.tagDraft.isEmpty {
                    Text(validation)
                        .font(AppFont.paperlogy4Regular(size: 12))
                        .foregroundStyle(.red.opacity(0.95))
                } else if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(AppFont.paperlogy4Regular(size: 12))
                        .foregroundStyle(.red.opacity(0.95))
                } else if let successMessage = viewModel.successMessage {
                    Text(successMessage)
                        .font(AppFont.paperlogy4Regular(size: 12))
                        .foregroundStyle(AppColors.primary600.opacity(0.95))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, horizontalPadding)
            .padding(.top, AppSpacing.s)

            Spacer(minLength: 0)
        }
        .background(
            Color.black
                .ignoresSafeArea()
        )
        .onAppear {
            viewModel.errorMessage = nil
            viewModel.successMessage = nil
            isTagFieldFocused = true
        }
        .onChange(of: viewModel.tagDraft) { _ in
            viewModel.errorMessage = nil
            viewModel.successMessage = nil
        }
        .navigationBarBackButtonHidden()
    }
    
    private func submitTagUpdate() {
        Task {
            if let updatedUser = await viewModel.updateTag() {
                onUserUpdated(updatedUser)
            }
        }
    }
}
