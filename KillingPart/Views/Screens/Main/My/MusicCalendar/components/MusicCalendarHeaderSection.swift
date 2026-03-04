import SwiftUI

struct MusicCalendarHeaderSection: View {
    let yearText: String
    let monthText: String
    let onMonthTap: () -> Void
    let onPreviousMonthTap: () -> Void
    let onNextMonthTap: () -> Void

    var body: some View {
        HStack(alignment: .top) {
            Button(action: onMonthTap) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(yearText)
                        .font(AppFont.paperlogy5Medium(size: 14))
                        .foregroundStyle(.white.opacity(0.8))

                    HStack(spacing: 8) {
                        Text(monthText)
                            .font(AppFont.paperlogy7Bold(size: 26))
                            .foregroundStyle(.white)

                        Image(systemName: "chevron.down")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(.top, 2)
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer(minLength: AppSpacing.xl)

            HStack(spacing: AppSpacing.s) {
                Button(action: onPreviousMonthTap) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Button(action: onNextMonthTap) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.bottom, AppSpacing.m)
    }
}
