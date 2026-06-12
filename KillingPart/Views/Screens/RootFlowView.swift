import SwiftUI

struct RootFlowView: View {
    @Environment(\.openURL) private var openURL
    @StateObject private var viewModel = AppViewModel()

    var body: some View {
        Group {
            switch viewModel.currentStep {
            case .splash:
                SplashView(
                    isReadyToFinish: viewModel.isSplashReadyToFinish,
                    onFinished: viewModel.completeSplash
                )
            case .login:
                LoginView(viewModel: viewModel.loginViewModel)
            case .setup:
                if let setupFlowViewModel = viewModel.setupFlowViewModel {
                    InitialSetupFlowView(viewModel: setupFlowViewModel)
                } else {
                    LoginView(viewModel: viewModel.loginViewModel)
                }
            case .main:
                MainTabView(
                    onLogout: viewModel.logout,
                    startupPayload: viewModel.mainStartupPayload
                )
            }
        }
        .overlay {
            if viewModel.isResolvingPostLoginFlow && viewModel.currentStep != .splash {
                ZStack {
                    Color.black.opacity(0.35).ignoresSafeArea()
                    ProgressView()
                        .tint(AppColors.primary600)
                }
            }
        }
        .alert(
            viewModel.updatePrompt?.title ?? "",
            isPresented: updatePromptBinding,
            presenting: viewModel.updatePrompt
        ) { prompt in
            switch prompt {
            case .force:
                Button("업데이트") {
                    if let appStoreURL = viewModel.openAppStoreURLForUpdate() {
                        openURL(appStoreURL)
                    }
                }
            case .optional:
                Button("나중에") {
                    viewModel.dismissOptionalUpdatePrompt()
                }
                Button("업데이트") {
                    if let appStoreURL = viewModel.openAppStoreURLForUpdate() {
                        openURL(appStoreURL)
                    }
                    viewModel.dismissOptionalUpdatePrompt()
                }
            }
        } message: { prompt in
            Text(prompt.message)
        }
        .task {
            viewModel.prepareSplashIfNeeded()
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.currentStep)
    }

    private var updatePromptBinding: Binding<Bool> {
        Binding(
            get: { viewModel.updatePrompt != nil },
            set: { isPresented in
                guard !isPresented else { return }
                if viewModel.updatePrompt == .optional {
                    viewModel.dismissOptionalUpdatePrompt()
                }
            }
        )
    }
}
