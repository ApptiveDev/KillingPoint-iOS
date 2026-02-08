import SwiftUI

struct LoginView: View {
    @ObservedObject var viewModel: AppFlowViewModel

    @State private var email = ""
    @State private var password = ""

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.l) {
            Spacer()

            Text("로그인")
                .font(AppFont.paperlogy7Bold(size: 28))

            VStack(spacing: AppSpacing.m) {
                TextField("Email", text: $email)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.emailAddress)
                    .padding(AppSpacing.m)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                SecureField("Password", text: $password)
                    .padding(AppSpacing.m)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            if let message = viewModel.loginErrorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            PrimaryButton(title: "로그인", isLoading: viewModel.isLoading) {
                viewModel.login(email: email, password: password)
            }

            Spacer()
        }
        .padding(AppSpacing.l)
        .background(AppColors.primary200.ignoresSafeArea())
    }
}
