import SwiftUI

struct OnboardingContainerView: View {
    let onContinue: () -> Void

    @State private var currentPage = 0
    private let lastPageIndex = 5
    private var shouldShowSwipeHint: Bool { currentPage < lastPageIndex }

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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay {
                if shouldShowSwipeHint {
                    HStack {
                        swipeHintArrow(systemName: "chevron.left")
                        Spacer()
                        swipeHintArrow(systemName: "chevron.right")
                    }
                    .padding(.horizontal, AppSpacing.s)
                    .allowsHitTesting(false)
                }
            }

            if currentPage == lastPageIndex {
                PrimaryButton(title: "지금 시작하기") {
                    onContinue()
                }
                .padding(.horizontal, AppSpacing.l)
                .padding(.bottom, AppSpacing.l)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.3), value: currentPage)
        .background(Color.black.ignoresSafeArea())
    }

    @ViewBuilder
    private func swipeHintArrow(systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(.white.opacity(0.95))
            .padding(10)
            .background(Color.black.opacity(0.38), in: Circle())
    }
}

#Preview {
    OnboardingContainerView {
    }
}
