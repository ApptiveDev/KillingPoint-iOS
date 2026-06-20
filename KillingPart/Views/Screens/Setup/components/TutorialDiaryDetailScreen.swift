import SwiftUI

struct TutorialDiaryDetailScreen: View {
    @ObservedObject var viewModel: InitialSetupFlowViewModel

    private let mockDiaryContent = "오늘 하루는 유난히 공허하게 흘러간 것 같다. 해야 할 일은 분명 있었지만 마음은 잘 따라주지 않았고, 생각들은 제자리를 맴돌았다. 그러다 문득, 특별한 이유 없이 음악을 들어야겠다는 충동이 찾아왔다. 그래서 큰 고민도 없이 ‘아무 노래’를 골랐다..."

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.m) {
                Text("피드에서 친구의 킬링파트를,\n탐색에서 다양한 킬링파트를 감상해보세요")
                    .font(AppFont.paperlogy7Bold(size: 20))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .padding(.top, AppSpacing.s)

                VStack(spacing: AppSpacing.m) {
                    HStack(alignment: .center, spacing: AppSpacing.m) {
                        tutorialProfileImage
                        VStack(alignment: .leading, spacing: 4) {
                            Text("킬링파트")
                                .font(AppFont.paperlogy7Bold(size: 15))
                                .foregroundStyle(AppColors.primary600)
                            Text("@KILLINGPART")
                                .font(AppFont.paperlogy4Regular(size: 13))
                                .foregroundStyle(AppColors.primary600)
                        }
                        Spacer(minLength: 0)
                        Text("프로필 방문")
                            .font(AppFont.paperlogy5Medium(size: 13))
                            .foregroundStyle(AppColors.primary600)
                            .padding(.horizontal, AppSpacing.s)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.14))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    VStack(spacing: AppSpacing.s) {
                        tutorialVideoPreview

                        Text("Death Sonnet von Dat")
                            .font(AppFont.paperlogy7Bold(size: 18))
                            .foregroundStyle(.white.opacity(0.88))
                            .frame(maxWidth: .infinity, alignment: .center)

                        Text("Davinci Leo")
                            .font(AppFont.paperlogy4Regular(size: 15))
                            .foregroundStyle(.white.opacity(0.56))
                            .frame(maxWidth: .infinity, alignment: .center)

                        HStack {
                            Text("킬링파트 일기")
                                .font(AppFont.paperlogy7Bold(size: 14))
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.white.opacity(0.45))
                                
                            Spacer(minLength: 0)
                            HStack(spacing: 5) {
                                Image(systemName: "heart.fill")
                                Text("26")
                            }
                            .font(AppFont.paperlogy6SemiBold(size: 14))
                            .foregroundStyle(.black)
                            .padding(.horizontal, AppSpacing.s)
                            .padding(.vertical, 6)
                            .background(AppColors.primary600.opacity(0.85))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }

                        Text(mockDiaryContent)
                            .font(AppFont.paperlogy4Regular(size: 14))
                            .foregroundStyle(.white.opacity(0.5))
                            .lineSpacing(5)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            Text("킬링파트")
                                .font(AppFont.paperlogy5Medium(size: 13))
                                .foregroundStyle(.white.opacity(0.36))
                            // 전체 곡: 2:00 (120s), 킬링파트: 1:40 (100s) ~ 2:00 (120s)
                            // 시작 오프셋 = 100/120 ≈ 83.3%, 구간 폭 = 20/120 ≈ 16.7%
                            GeometryReader { geo in
                                let totalWidth = geo.size.width
                                let startFrac: CGFloat = 100.0 / 120.0
                                let segmentFrac: CGFloat = 20.0 / 120.0
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.white.opacity(0.18))
                                        .frame(height: 3)
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [AppColors.primary600.opacity(0.7), AppColors.primary600],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: totalWidth * segmentFrac, height: 8)
                                        .offset(x: totalWidth * startFrac)
                                }
                            }
                            .frame(height: 8)
                            HStack(spacing: 2) {
                                Text("0:00")
                                    .foregroundStyle(.white.opacity(0.26))
                                Spacer(minLength: 0)
                                Text("1:40")
                                    .foregroundStyle(AppColors.primary600.opacity(0.9))
                                Text("~")
                                    .foregroundStyle(AppColors.primary600.opacity(0.6))
                                Text("2:00")
                                    .foregroundStyle(AppColors.primary600.opacity(0.9))
                            }
                            .font(AppFont.paperlogy4Regular(size: 12))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(AppSpacing.m)
                        .background(Color.black.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        }
                    }
                }
                .padding(AppSpacing.m)
                .background(Color.black.opacity(0.78))
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, AppSpacing.l)
            .padding(.bottom, AppSpacing.xl)
        }
        .scrollIndicators(.hidden)
        .background(
            KillingPartBackgroundView()
        )
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack {
                Image(systemName: "chevron.left")
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(.white)
                Spacer(minLength: 0)
                Button("건너뛰기") {
                    viewModel.skipAllTutorialAndFinish()
                }
                .font(AppFont.paperlogy5Medium(size: 14))
                .foregroundStyle(.white.opacity(0.92))
            }
            .padding(.horizontal, AppSpacing.l)
            .padding(.top, AppSpacing.s)
            .padding(.bottom, AppSpacing.xs)
            .background(Color.clear)
        }
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(title: "다음으로") {
                viewModel.goToNotificationTutorial()
            }
            .padding(.horizontal, AppSpacing.l)
            .padding(.top, AppSpacing.s)
            .padding(.bottom, AppSpacing.s)
            .background(Color.black.opacity(0.92))
        }
    }

    private var tutorialProfileImage: some View {
        Circle()
            .fill(Color.white.opacity(0.2))
            .overlay {
                Image(systemName: "person.fill")
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .frame(width: 52, height: 52)
            .overlay {
                Circle()
                    .stroke(AppColors.primary600, lineWidth: 3)
            }
    }

    private var tutorialVideoPreview: some View {
        Color.clear
            .aspectRatio(16 / 9, contentMode: .fit)
            .overlay {
                ZStack {
                    AsyncImage(url: URL(string: "https://picsum.photos/seed/mountain/800/450")) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .empty, .failure:
                            Rectangle()
                                .fill(Color.white.opacity(0.1))
                        @unknown default:
                            Rectangle()
                                .fill(Color.white.opacity(0.1))
                        }
                    }

                    Color.black.opacity(0.3)

                    VStack {
                        HStack(alignment: .top) {
                            Text("Death Sonnet von\nDat - Davinci")
                                .font(AppFont.paperlogy4Regular(size: 16))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 28, weight: .regular))
                                .foregroundStyle(.white.opacity(0.92))
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "play.rectangle.fill")
                            .font(.system(size: 52, weight: .regular))
                            .foregroundStyle(.red.opacity(0.92))
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, AppSpacing.m)
                    .padding(.vertical, AppSpacing.m)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
