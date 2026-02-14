import SwiftUI

struct MusicCalendarView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            Text("뮤직캘린더")
                .font(AppFont.paperlogy7Bold(size: 24))
                .foregroundStyle(.white)

            Text("날짜별로 기록한 킬링파트를 캘린더로 확인하세요.")
                .font(AppFont.paperlogy4Regular(size: 15))
                .foregroundStyle(.white.opacity(0.75))

            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.08))
                .frame(height: 320)
                .overlay {
                    VStack(spacing: AppSpacing.s) {
                        Text("February")
                            .font(AppFont.paperlogy6SemiBold(size: 18))
                            .foregroundStyle(.white)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: AppSpacing.xs), count: 7), spacing: AppSpacing.xs) {
                            ForEach(1...35, id: \.self) { day in
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(day % 5 == 0 ? AppColors.primary600.opacity(0.28) : Color.white.opacity(0.08))
                                    .frame(height: 28)
                                    .overlay {
                                        if day <= 29 {
                                            Text("\(day)")
                                                .font(AppFont.paperlogy4Regular(size: 11))
                                                .foregroundStyle(.white)
                                        }
                                    }
                            }
                        }
                        .padding(.horizontal, AppSpacing.s)
                    }
                    .padding(AppSpacing.m)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
