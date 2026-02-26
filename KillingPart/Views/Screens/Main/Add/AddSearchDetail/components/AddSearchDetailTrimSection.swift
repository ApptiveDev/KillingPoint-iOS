import SwiftUI

struct AddSearchDetailTrimSection: View {
    @ObservedObject var viewModel: AddSearchDetailViewModel

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
                    startTimeText: viewModel.startTimeText,
                    endTimeText: viewModel.endTimeText,
                    onUpdateRange: { start, end in
                        viewModel.updateRange(start: start, end: end)
                    }
                )
                .frame(height: 160)

                HStack {
                    Text("선택 구간 \(viewModel.startTimeText) ~ \(viewModel.endTimeText)")
                        .font(AppFont.paperlogy5Medium(size: 13))
                        .foregroundStyle(AppColors.primary600)

                    Spacer()

                    Text("최대 30초")
                        .font(AppFont.paperlogy4Regular(size: 12))
                        .foregroundStyle(.white.opacity(0.7))
                }

            } else {
                Text("영상을 찾지 못해 구간 자르기를 사용할 수 없어요.")
                    .font(AppFont.paperlogy4Regular(size: 13))
                    .foregroundStyle(.white.opacity(0.72))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)   // 👈 핵심
            }
        }
        .padding(AppSpacing.m)
    }
}
