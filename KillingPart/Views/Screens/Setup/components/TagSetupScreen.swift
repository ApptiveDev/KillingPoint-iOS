import SwiftUI

struct TagSetupScreen: View {
    @ObservedObject var viewModel: InitialSetupFlowViewModel

    var body: some View {
        GeometryReader { geometry in
            let horizontalPadding = AppSpacing.l
            let safeAreaBottomInset = geometry.safeAreaInsets.bottom
            let isKeyboardPresented = safeAreaBottomInset > 80
            let bottomPadding = isKeyboardPresented
                ? AppSpacing.s
                : safeAreaBottomInset + AppSpacing.l
            let contentTopOffset = max(
                geometry.safeAreaInsets.top + AppSpacing.xl,
                geometry.size.height * 0.22
            )

            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: AppSpacing.s) {
                    Text("개성을 나타내는 태그를 정해주세요")
                        .font(AppFont.paperlogy7Bold(size: 24))
                        .foregroundStyle(.white)

                    Text("언제든지 바꿀 수 있습니다")
                        .font(AppFont.paperlogy4Regular(size: 14))
                        .foregroundStyle(.white)

                    Text("*영문 소문자 4이상, 30자 이내, 특수문자 일부[.][_]")
                        .font(AppFont.paperlogy4Regular(size: 12))
                        .foregroundStyle(.white.opacity(0.55))
                        

                    HStack(spacing: AppSpacing.xs) {
                        Text("@")
                            .font(AppFont.paperlogy5Medium(size: 18))
                            .foregroundStyle(.white.opacity(0.7))
                        TextField("태그 입력", text: $viewModel.tagDraft)
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
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, horizontalPadding)
                .padding(.top, contentTopOffset)

                Spacer(minLength: 0)

                PrimaryButton(title: "다음", isLoading: viewModel.isLoading) {
                    Task {
                        await viewModel.submitTag()
                    }
                }
                .disabled(!viewModel.canSubmitTag || viewModel.isLoading)
                .opacity((viewModel.canSubmitTag && !viewModel.isLoading) ? 1 : 0.45)
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
    }
}
