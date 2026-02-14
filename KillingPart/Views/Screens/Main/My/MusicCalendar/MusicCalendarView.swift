import SwiftUI

struct MusicCalendarView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            Text("뮤직캘린더")
                .font(AppFont.paperlogy7Bold(size: 24))

            Text("날짜별로 기록한 킬링파트를 캘린더로 확인하세요.")
                .font(AppFont.paperlogy4Regular(size: 15))
                .foregroundStyle(.secondary)

            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.secondarySystemBackground))
                .frame(height: 320)
                .overlay {
                    VStack(spacing: AppSpacing.s) {
                        Text("February")
                            .font(AppFont.paperlogy6SemiBold(size: 18))

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: AppSpacing.xs), count: 7), spacing: AppSpacing.xs) {
                            ForEach(1...35, id: \.self) { day in
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(day % 5 == 0 ? AppColors.primary300 : Color(.systemBackground))
                                    .frame(height: 28)
                                    .overlay {
                                        if day <= 29 {
                                            Text("\(day)")
                                                .font(AppFont.paperlogy4Regular(size: 11))
                                        }
                                    }
                            }
                        }
                        .padding(.horizontal, AppSpacing.s)
                    }
                    .padding(AppSpacing.m)
                }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
