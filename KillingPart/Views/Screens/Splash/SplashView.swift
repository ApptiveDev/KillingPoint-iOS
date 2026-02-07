import SwiftUI

struct SplashView: View {
    let onFinished: () -> Void

    @State private var isReadyToNavigate = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, AppColors.primary300.opacity(0.65)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: AppSpacing.l) {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black.opacity(0.4))
                    .overlay {
                        Text("Splash Video Placeholder")
                            .font(AppFont.body())
                            .foregroundStyle(.white)
                    }
                    .frame(height: 220)

                Text("KillingPart")
                    .font(AppFont.title())
                    .foregroundStyle(.white)
            }
            .padding(AppSpacing.l)
        }
        .onAppear {
            guard !isReadyToNavigate else { return }
            isReadyToNavigate = true

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                onFinished()
            }
        }
    }
}
