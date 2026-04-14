import SwiftUI

enum SocialInteractionFeedbackKind: Equatable {
    case likeAdded
    case likeRemoved
    case storeAdded
    case storeRemoved
    case alreadyLiked

    var iconName: String {
        switch self {
        case .likeAdded:
            return "heart.fill"
        case .likeRemoved:
            return "heart"
        case .storeAdded:
            return "bookmark.fill"
        case .storeRemoved:
            return "bookmark"
        case .alreadyLiked:
            return "heart.slash"
        }
    }

    var iconColor: Color {
        switch self {
        case .likeAdded:
            return Color.kpPrimary
        case .storeAdded:
            return AppColors.primary600
        case .likeRemoved, .storeRemoved, .alreadyLiked:
            return Color.white.opacity(0.8)
        }
    }

    var message: String {
        switch self {
        case .likeAdded:
            return "좋아요 했어요"
        case .likeRemoved:
            return "좋아요를 취소했어요"
        case .storeAdded:
            return "보관함에 저장했어요"
        case .storeRemoved:
            return "보관함을 해제했어요"
        case .alreadyLiked:
            return "이미 좋아요한 다이어리입니다"
        }
    }
}

struct SocialInteractionFeedbackOverlay: View {
    let feedback: SocialInteractionFeedbackKind?

    var body: some View {
        if let feedback {
            VStack(spacing: AppSpacing.s) {
                Image(systemName: feedback.iconName)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(feedback.iconColor)

                Text(feedback.message)
                    .font(AppFont.paperlogy5Medium(size: 13))
                    .foregroundStyle(.white.opacity(0.95))
            }
            .padding(.horizontal, AppSpacing.l)
            .padding(.vertical, AppSpacing.m)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.black.opacity(0.78))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.32), radius: 14, y: 8)
            .transition(
                .asymmetric(
                    insertion: .scale(scale: 0.84).combined(with: .opacity),
                    removal: .offset(y: -18).combined(with: .opacity)
                )
            )
            .allowsHitTesting(false)
        }
    }
}

@MainActor
final class SocialInteractionFeedbackPresenter: ObservableObject {
    @Published private(set) var activeFeedback: SocialInteractionFeedbackKind?

    private var dismissTask: Task<Void, Never>?

    deinit {
        dismissTask?.cancel()
    }

    func show(_ feedback: SocialInteractionFeedbackKind) {
        dismissTask?.cancel()
        withAnimation(.spring(response: 0.32, dampingFraction: 0.76)) {
            activeFeedback = feedback
        }

        dismissTask = Task {
            try? await Task.sleep(nanoseconds: 900_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeIn(duration: 0.22)) {
                    activeFeedback = nil
                }
            }
        }
    }

    func clear() {
        dismissTask?.cancel()
        dismissTask = nil
        activeFeedback = nil
    }
}
