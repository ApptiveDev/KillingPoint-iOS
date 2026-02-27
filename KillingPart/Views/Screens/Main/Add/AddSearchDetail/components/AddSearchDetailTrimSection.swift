import SwiftUI

struct AddSearchDetailTrimSection: View {
    @ObservedObject var viewModel: AddSearchDetailViewModel

    private var startDisplayTimeText: String {
        displayTimeText(seconds: viewModel.startSeconds)
    }

    private var endDisplayTimeText: String {
        displayTimeText(seconds: viewModel.endSeconds)
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
                Text("영상을 찾지 못해 구간 자르기를 사용할 수 없어요.")
                    .font(AppFont.paperlogy4Regular(size: 13))
                    .foregroundStyle(.white.opacity(0.72))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)   // 👈 핵심
            }
        }
        .padding(AppSpacing.m)
    }

    private func displayTimeText(seconds: Double) -> String {
        let safeSeconds = max(Int(seconds.rounded(.down)), 0)
        let minutes = safeSeconds / 60
        let remainingSeconds = safeSeconds % 60
        let secondText = remainingSeconds < 10 ? "0\(remainingSeconds)" : "\(remainingSeconds)"
        return "\(minutes):\(secondText)초"
    }
}
