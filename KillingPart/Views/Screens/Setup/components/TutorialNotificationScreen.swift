import SwiftUI

struct TutorialNotificationScreen: View {
    @ObservedObject var viewModel: InitialSetupFlowViewModel

    private let noticeText = "[공지] 신규 업데이트 3.1 예정입니다!"
    private let mockNotifications: [(String, String)] = [
        ("OOO님이 회원님을 픽했어요", "04.15"),
        ("OOO의 새로운 업데이트가 배포되었어요", "04.16"),
        ("OOO님이 최근 활동을 공유했어요", "04.16"),
        ("OOO의 이벤트에 초대받았어요", "04.17"),
        ("OOO님과의 대화가 시작되었어요", "04.17"),
        ("OOO의 추천을 받았어요", "04.18"),
        ("OOO님이 나를 태그했어요", "04.18"),
        ("OOO의 팬이 되었어요", "04.19"),
        ("OOO의 킬링파트가 좋아요를 받았어요", "04.15"),
        ("OOO님이 회원님을 픽했어요", "04.15"),
        ("OOO의 새로운 업데이트가 배포되었어요", "04.16"),
        ("OOO의 이벤트에 초대받았어요", "04.17")
    ]

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: AppSpacing.m) {
                Text("알림을 통해\n내 픽과 팬덤의 활동을 확인하세요!")
                    .font(AppFont.paperlogy7Bold(size: 24))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: AppSpacing.m) {
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: "bell")
                            .font(.system(size: 16, weight: .semibold))
                        Text("알림 목록")
                            .font(AppFont.paperlogy7Bold(size: 18))
                    }
                    .foregroundStyle(AppColors.primary600)
                    .frame(maxWidth: .infinity, alignment: .center)

                    Text(noticeText)
                        .font(AppFont.paperlogy6SemiBold(size: 16))
                        .foregroundStyle(.black)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.m)
                        .padding(.vertical, AppSpacing.m)
                        .frame(maxWidth: .infinity)
                        .background(AppColors.primary600)
                        .clipShape(RoundedRectangle(cornerRadius: 14))

                    ZStack(alignment: .bottom) {
                        ScrollView {
                            LazyVStack(spacing: AppSpacing.xs) {
                                ForEach(Array(mockNotifications.enumerated()), id: \.offset) { _, row in
                                    HStack {
                                        Text(row.0)
                                            .font(AppFont.paperlogy4Regular(size: 15))
                                            .foregroundStyle(.white.opacity(0.85))
                                        Spacer(minLength: AppSpacing.s)
                                        Text(row.1)
                                            .font(AppFont.paperlogy4Regular(size: 14))
                                            .foregroundStyle(.white.opacity(0.7))
                                    }
                                    .padding(.vertical, AppSpacing.xs)
                                }
                            }
                            .padding(.bottom, AppSpacing.xl * 2)
                        }
                        .scrollIndicators(.hidden)

                        LinearGradient(
                            colors: [Color.clear, Color.black.opacity(0.95)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 110)
                        .allowsHitTesting(false)
                    }
                    .frame(maxHeight: .infinity)
                }
                .padding(AppSpacing.m)
                .frame(maxHeight: max(geometry.size.height * 0.58, 460))
                .background(Color.black.opacity(0.72))
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay {
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                }

                PrimaryButton(title: "다음으로") {
                    viewModel.goToFinalTutorial()
                }
            }
            .padding(.horizontal, AppSpacing.l)
            .padding(.top, AppSpacing.l)
            .padding(.bottom, AppSpacing.l)
        }
        .background(
            LinearGradient(
                colors: [Color.black, Color(hex: "#171A24")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .safeAreaInset(edge: .top, spacing: 0) {
            InitialSetupSkipButtonRow(onSkip: viewModel.skipAllTutorialAndFinish)
        }
    }
}
