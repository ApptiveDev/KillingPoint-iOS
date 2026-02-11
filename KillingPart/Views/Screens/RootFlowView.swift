import SwiftUI

struct RootFlowView: View {
    @StateObject private var viewModel = AppFlowViewModel()

    var body: some View {
        Group {
            switch viewModel.currentStep {
            case .splash:
                SplashView(onFinished: viewModel.completeSplash)
            case .onboarding:
                OnboardingContainerView(onContinue: viewModel.completeOnboarding)
            case .login:
                LoginView(viewModel: viewModel)
            case .main:
                MainTabView(onLogout: viewModel.logout)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.currentStep)
    }
}
