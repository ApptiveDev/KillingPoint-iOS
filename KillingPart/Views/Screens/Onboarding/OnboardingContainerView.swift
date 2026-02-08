import SwiftUI

struct OnboardingContainerView: View {
    let onContinue: () -> Void

    @State private var currentPage = 0
    private let lastPageIndex = 5

    var body: some View {
        VStack(spacing: 0) {
            if currentPage < lastPageIndex {
                ZStack {
                    Text("KILLING TIPS!")
                        .font(AppFont.paperlogy7Bold(size: 24))
                        .foregroundStyle(Color.kpPrimary)
                        .tracking(0.5)

                    HStack {
                        OnboardingProgressView(currentPage: currentPage + 1)
                        Spacer()
                    }
                }
                .padding(.horizontal, AppSpacing.l)
                .padding(.top, AppSpacing.l)
                .padding(.bottom, AppSpacing.s)
            }

            TabView(selection: $currentPage) {
                OnboardingPage1View()
                    .tag(0)
                OnboardingPage2View()
                    .tag(1)
                OnboardingPage3View()
                    .tag(2)
                OnboardingPage4View()
                    .tag(3)
                OnboardingPage5View()
                    .tag(4)
                OnboardingPage6View()
                    .tag(5)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            if currentPage == lastPageIndex {
                PrimaryButton(title: "지금 시작하기") {
                    onContinue()
                }
                .padding(.horizontal, AppSpacing.l)
                .padding(.bottom, AppSpacing.l)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: currentPage)
        .background(Color.black.ignoresSafeArea())
    }
}

#Preview {
    OnboardingContainerView {
    }
}
