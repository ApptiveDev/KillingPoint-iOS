import SwiftUI

struct NameEdit: View {
    @ObservedObject var viewModel: ProfileSettingViewModel
    let onUserUpdated: (UserModel) -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var isNameFieldFocused: Bool

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
                SettingsSubpageHeader(title: "이름 변경") {
                    dismiss()
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.top, AppSpacing.s)

                VStack(alignment: .leading, spacing: AppSpacing.s) {
                    Text("사용하실 이름이 무엇인가요?")
                        .font(AppFont.paperlogy7Bold(size: 24))
                        .foregroundStyle(.white)

                    Text("이름은 언제든지 바꿀 수 있습니다")
                        .font(AppFont.paperlogy4Regular(size: 14))
                        .foregroundStyle(.white)

                    Text("*한글 8자 이내, 영어 16자 이내(숫자 포함)")
                        .font(AppFont.paperlogy4Regular(size: 12))
                        .foregroundStyle(.white.opacity(0.55))

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
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        }

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
                .padding(.top, contentTopOffset)

                Spacer(minLength: 0)

                PrimaryButton(title: "저장", isLoading: viewModel.isProcessing) {
                    Task {
                        if let updatedUser = await viewModel.updateName() {
                            onUserUpdated(updatedUser)
                            dismiss()
                        }
                    }
                }
                .disabled(!viewModel.canSubmitNameUpdate || viewModel.isProcessing)
                .opacity((viewModel.canSubmitNameUpdate && !viewModel.isProcessing) ? 1 : 0.45)
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
        .onChange(of: viewModel.nameDraft) { _ in
            viewModel.errorMessage = nil
            viewModel.successMessage = nil
        }
        .navigationBarBackButtonHidden()
    }
}

struct SettingsSubpageHeader: View {
    let title: String
    let onBackTap: () -> Void

    var body: some View {
        ZStack {
            Text(title)
                .font(AppFont.paperlogy6SemiBold(size: 24))
                .foregroundStyle(Color.kpPrimary)

            HStack {
                Button(action: onBackTap) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.kpPrimary)
                }
                .buttonStyle(.plain)

                Spacer()
            }
        }
        .frame(height: 44)
    }
}
