import SwiftUI

struct AddSearchDetailTrimSection: View {
    @ObservedObject var viewModel: AddSearchDetailViewModel

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
                    startTimeText: startDisplayTimeText,
                    endTimeText: endDisplayTimeText,
                    onUpdateRange: { start, end in
                        viewModel.updateRange(start: start, end: end)
                    }
                )
                .frame(height: 160)

                HStack {
                    Text("선택 구간 \(startDisplayTimeText) ~ \(endDisplayTimeText)")
                        .font(AppFont.paperlogy5Medium(size: 13))
                        .foregroundStyle(AppColors.primary600)

                    Spacer()

                    Text("최대 30초")
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
    }
}
