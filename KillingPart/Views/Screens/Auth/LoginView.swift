import SwiftUI

struct LoginView: View {
    @ObservedObject var viewModel: LoginViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.l) {
            Spacer()

            Text("로그인")
                .font(AppFont.paperlogy7Bold(size: 28))

            Text("카카오 계정으로 간편하게 시작하세요.")
                .font(AppFont.paperlogy4Regular(size: 16))
                .foregroundStyle(.secondary)

            if let message = viewModel.loginErrorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Button {
                viewModel.loginWithKakao()
            } label: {
                HStack(spacing: AppSpacing.s) {
                    if viewModel.isLoading {
                        ProgressView()
                            .tint(.black)
                    }

                    Text("카카오로 로그인")
                        .font(AppFont.paperlogy6SemiBold(size: 16))
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.m)
                .background(Color(hex: "#FEE500"))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(viewModel.isLoading)

            Spacer()
        }
        .padding(AppSpacing.l)
        .background(AppColors.primary200.ignoresSafeArea())
    }
}

#Preview {
    LoginView(viewModel: LoginViewModel())
}
