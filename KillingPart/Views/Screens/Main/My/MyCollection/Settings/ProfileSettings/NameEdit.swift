import SwiftUI

struct NameEdit: View {
    @ObservedObject var viewModel: ProfileSettingViewModel
    let onUserUpdated: (UserModel) -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var isNameFieldFocused: Bool
    
    private var hasNameChanges: Bool {
        guard let user = viewModel.user else { return false }
        return viewModel.normalizedName(viewModel.nameDraft) != viewModel.normalizedName(user.username)
    }
    
    private var isCompleteEnabled: Bool {
        hasNameChanges && !viewModel.isProcessing
    }

    var body: some View {
        let horizontalPadding = AppSpacing.l

        VStack(spacing: 0) {
            SettingsSubpageHeader(
                title: "이름 변경",
                titleColor: .white,
                titleFontSize: 20,
                backButtonColor: .white,
                trailingTitle: "완료",
                trailingColor: isCompleteEnabled ? .kpPrimary : .white.opacity(0.45),
                trailingDisabled: !isCompleteEnabled,
                onTrailingTap: submitNameUpdate
            ) {
                dismiss()
            }
            .padding(.horizontal, horizontalPadding)

            VStack(alignment: .leading, spacing: AppSpacing.s) {
                Text("이름")
                    .font(AppFont.paperlogy4Regular(size: 18))
                    .foregroundStyle(.white.opacity(0.85))

                TextField("이름 입력", text: $viewModel.nameDraft)
                    .focused($isNameFieldFocused)
                    .font(AppFont.paperlogy5Medium(size: 16))
                    .foregroundStyle(.white)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(.horizontal, AppSpacing.m)
                    .padding(.vertical, AppSpacing.m)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.kpPrimary, lineWidth: 1)
                    }
                
                Text("2~16자, 한글/영문/숫자 사용 가능")
                    .font(AppFont.paperlogy4Regular(size: 13))
                    .foregroundStyle(.white.opacity(0.55))

                if let validation = viewModel.validateName(viewModel.nameDraft), !viewModel.nameDraft.isEmpty {
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
            isNameFieldFocused = true
        }
        .onChange(of: viewModel.nameDraft) { _ in
            viewModel.errorMessage = nil
            viewModel.successMessage = nil
        }
        .navigationBarBackButtonHidden()
    }
    
    private func submitNameUpdate() {
        Task {
            if let updatedUser = await viewModel.updateName() {
                onUserUpdated(updatedUser)
            }
        }
    }
}

struct SettingsSubpageHeader: View {
    let title: String
    let titleColor: Color
    let titleFontSize: CGFloat
    let backButtonColor: Color
    let trailingTitle: String?
    let trailingColor: Color
    let trailingDisabled: Bool
    let onTrailingTap: (() -> Void)?
    let onBackTap: () -> Void
    
    init(
        title: String,
        titleColor: Color = Color.kpPrimary,
        titleFontSize: CGFloat = 24,
        backButtonColor: Color = Color.kpPrimary,
        trailingTitle: String? = nil,
        trailingColor: Color = .white,
        trailingDisabled: Bool = true,
        onTrailingTap: (() -> Void)? = nil,
        onBackTap: @escaping () -> Void
    ) {
        self.title = title
        self.titleColor = titleColor
        self.titleFontSize = titleFontSize
        self.backButtonColor = backButtonColor
        self.trailingTitle = trailingTitle
        self.trailingColor = trailingColor
        self.trailingDisabled = trailingDisabled
        self.onTrailingTap = onTrailingTap
        self.onBackTap = onBackTap
    }

    var body: some View {
        ZStack {
            Text(title)
                .font(AppFont.paperlogy6SemiBold(size: titleFontSize))
                .foregroundStyle(titleColor)

            HStack {
                Button(action: onBackTap) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(backButtonColor)
                }
                .buttonStyle(.plain)

                Spacer()
                
                if let trailingTitle, let onTrailingTap {
                    Button(action: onTrailingTap) {
                        Text(trailingTitle)
                            .font(AppFont.paperlogy6SemiBold(size: 20))
                            .foregroundStyle(trailingColor)
                    }
                    .buttonStyle(.plain)
                    .disabled(trailingDisabled)
                }
            }
        }
        .frame(height: 44)
    }
}
