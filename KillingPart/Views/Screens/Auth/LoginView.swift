import SwiftUI

struct LoginView: View {
    @ObservedObject var viewModel: LoginViewModel

    var body: some View {
        GeometryReader { geometry in
            let logoWidth = min(max(geometry.size.width * 0.75, 220), 560)
            let horizontalPadding = max(AppSpacing.m, geometry.size.width * 0.06)
            let topPadding = geometry.safeAreaInsets.top + AppSpacing.l
            let bottomPadding = geometry.safeAreaInsets.bottom + AppSpacing.l

            ZStack {
                LoginBackgroundVideoView()
                    .ignoresSafeArea()

                LinearGradient(
                    colors: [Color.black.opacity(0.15), Color.black.opacity(0.72)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    Image("loginTitle")
                        .resizable()
                        .scaledToFit()
                        .frame(width: logoWidth)
                        .frame(maxWidth: .infinity, alignment: .top)
                        .padding(.top, topPadding)
                        .padding(.horizontal, horizontalPadding)

                    Spacer(minLength: AppSpacing.l)

                    VStack(spacing: AppSpacing.m) {
                        Text("SNS로 간편로그인")
                            .font(AppFont.paperlogy5Medium(size: 15))
                            .foregroundStyle(Color.kpGray300)

                        if let message = viewModel.loginErrorMessage {
                            Text(message)
                                .font(.footnote)
                                .foregroundStyle(Color.red.opacity(0.95))
                                .multilineTextAlignment(.center)
                        }

                        HStack(spacing: AppSpacing.m) {
                            KakaoLoginButton(
                                isLoading: viewModel.isLoading
                                    && viewModel.activeSocialLoginProvider == .kakao,
                                isDisabled: viewModel.isLoading,
                                action: viewModel.loginWithKakao
                            )

                            AppleLoginButton(
                                isLoading: viewModel.isLoading
                                    && viewModel.activeSocialLoginProvider == .apple,
                                isDisabled: viewModel.isLoading,
                                action: viewModel.loginWithApple
                            )
                        }

//                        Button(action: viewModel.loginWithTester) {
//                            ZStack {
//                                Text("체험하기(Demo)")
//                                    .font(AppFont.paperlogy5Medium(size: 14))
//                                    .opacity(
//                                        viewModel.isLoading
//                                            && viewModel.activeSocialLoginProvider == .tester ? 0 : 1
//                                    )
//
//                                if viewModel.isLoading
//                                    && viewModel.activeSocialLoginProvider == .tester {
//                                    ProgressView()
//                                        .tint(.white)
//                                }
//                            }
//                            .foregroundStyle(.white)
//                            .padding(.horizontal, AppSpacing.l)
//                            .padding(.vertical, AppSpacing.s)
//                            .background(Color.white.opacity(0.16))
//                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
//                            .overlay {
//                                RoundedRectangle(cornerRadius: 14, style: .continuous)
//                                    .stroke(Color.white.opacity(0.28), lineWidth: 1)
//                            }
//                        }
//                        .buttonStyle(.plain)
//                        .disabled(viewModel.isLoading)
//                        .accessibilityLabel("체험하기")
                    }
                    .padding(.horizontal, horizontalPadding)
                    .padding(.bottom, bottomPadding)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
    }
}

#Preview {
    LoginView(viewModel: LoginViewModel())
}
