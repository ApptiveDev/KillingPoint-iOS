import SwiftUI

struct AddSearchDetailTrimSection: View {
    @ObservedObject var viewModel: AddSearchDetailViewModel
    let onTrimInteracted: () -> Void
    let onTrimInteractionEnded: (_ control: AddSearchDetailTrimInteractionControl) -> Void

    private var startDisplayTimeText: String {
        TimeFormatter.minuteSecondText(from: viewModel.startSeconds)
    }

    private var endDisplayTimeText: String {
        TimeFormatter.minuteSecondText(from: viewModel.endSeconds)
    }

    var body: some View {
        VStack(alignment: .center, spacing: AppSpacing.s) {
            Text("킬링파트 자르기")
                .font(AppFont.paperlogy4Regular(size: 16))
                .foregroundStyle(.white.opacity(0.9))

            if viewModel.hasPlayableVideo {
                if viewModel.shouldShowBoundaryLoopHint {
                    boundaryLoopHint
                }

                AddSearchDetailWaveformTrimView(
                    startSeconds: Binding(
                        get: { viewModel.startSeconds },
                        set: { viewModel.updateStart($0) }
                    ),
                    endSeconds: Binding(
                        get: { viewModel.endSeconds },
                        set: { viewModel.updateEnd($0) }
                    ),
                    duration: viewModel.maxDuration,
                    playbackSeconds: viewModel.playbackSeconds,
                    startTimeText: startDisplayTimeText,
                    endTimeText: endDisplayTimeText,
                    onTrimInteracted: {
                        viewModel.dismissBoundaryLoopHint()
                        onTrimInteracted()
                    },
                    onInteractionEnded: onTrimInteractionEnded,
                    onUpdateRange: { start, end in
                        viewModel.updateRange(start: start, end: end)
                    },
                    onSeekRequested: { seconds in
                        viewModel.requestPlayback(from: seconds)
                    },
                    onHandleLoopActivated: { control in
                        viewModel.activateBoundaryLoop(for: control)
                    },
                    onHandleLoopDeactivated: {
                        viewModel.deactivateBoundaryLoop()
                    },
                    onHandleDragMovementChanged: { isDragging in
                        viewModel.setHandleDragging(isDragging)
                    }
                )
                .frame(height: 176)

                HStack {
                    Text("선택 구간 \(startDisplayTimeText) ~ \(endDisplayTimeText)")
                        .font(AppFont.paperlogy5Medium(size: 13))
                        .foregroundStyle(AppColors.primary600)

                    Spacer()

                    Text("10초 이상 · 최대 30초")
                        .font(AppFont.paperlogy4Regular(size: 12))
                        .foregroundStyle(.white.opacity(0.7))
                }

            } else {
                if viewModel.isLoading {
                    Text("음악을 가져오고 있어요...")
                        .font(AppFont.paperlogy4Regular(size: 13))
                        .foregroundStyle(.white.opacity(0.72))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                } else {
                    Text("음악을 가져오지 못했어요")
                        .font(AppFont.paperlogy4Regular(size: 13))
                        .foregroundStyle(.white.opacity(0.72))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(AppSpacing.m)
        .animation(.easeInOut(duration: 0.25), value: viewModel.shouldShowBoundaryLoopHint)
    }

    private var boundaryLoopHint: some View {
        HStack(spacing: 6) {
            Image(systemName: "hand.tap.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppColors.primary600)

            Text("꾹 눌러서 시작과 끝 구간 반복이 가능해요!")
                .font(AppFont.paperlogy4Regular(size: 12))
                .foregroundStyle(.white.opacity(0.88))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.07))
        )
        .overlay {
            Capsule()
                .stroke(AppColors.primary600.opacity(0.5), lineWidth: 1)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
}
