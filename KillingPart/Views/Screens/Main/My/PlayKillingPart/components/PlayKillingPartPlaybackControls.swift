import SwiftUI

struct PlayKillingPartPlaybackControls: View {
    let isPlaying: Bool
    let isDisabled: Bool
    let onPrevious: () -> Void
    let onTogglePlay: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack(spacing: AppSpacing.xl) {
            controlButton(symbol: "backward.end", action: onPrevious)

            Button {
                onTogglePlay()
            } label: {
                Circle()
                    .fill(AppColors.primary600)
                    .frame(width: 64, height: 64)
                    .overlay {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.black)
                            .offset(x: isPlaying ? 0 : 2)
                            .animation(nil, value: isPlaying)
                    }
            }
            .buttonStyle(.plain)
            .disabled(isDisabled)
            .opacity(isDisabled ? 0.5 : 1)

            controlButton(symbol: "forward.end", action: onNext)
        }
        .frame(maxWidth: .infinity)
    }

    private func controlButton(symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Circle()
                .fill(Color.white.opacity(0.16))
                .frame(width: 50, height: 50)
                .overlay {
                    Image(systemName: symbol)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                }
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1)
    }
}
