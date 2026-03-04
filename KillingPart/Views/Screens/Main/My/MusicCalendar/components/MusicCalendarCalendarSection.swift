import SwiftUI

struct MusicCalendarCalendarSection: View {
    let weekdayTitles: [String]
    let dayCells: [MusicCalendarDayCell]
    let onDayTap: (Date) -> Void

    var body: some View {
        Rectangle()
            .fill(Color.black.opacity(0.28))
            .overlay {
                VStack(spacing: AppSpacing.s) {
                    weekdayHeaderRow

                    LazyVGrid(columns: calendarGridColumns, spacing: 0) {
                        ForEach(dayCells) { cell in
                            dayCell(cell)
                        }
                    }
                }
                .padding(AppSpacing.m)
            }
    }

    private var weekdayHeaderRow: some View {
        HStack(spacing: AppSpacing.xs) {
            ForEach(Array(weekdayTitles.enumerated()), id: \.offset) { index, title in
                Text(title)
                    .font(AppFont.paperlogy5Medium(size: 12))
                    .foregroundStyle(weekdayColor(for: index + 1))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 6)
            }
        }
    }

    private func dayCell(_ cell: MusicCalendarDayCell) -> some View {
        Group {
            if cell.isPlaceholder {
                Color.clear
                    .frame(height: 44)
            } else if let date = cell.date, let dayNumber = cell.dayNumber {
                Button {
                    onDayTap(date)
                } label: {
                    ZStack {
                        Rectangle()
                            .fill(cell.isSelected ? AppColors.primary600 : Color.white.opacity(0.04))
                            .overlay {
                                Rectangle()
                                    .stroke(
                                        cell.isToday ? AppColors.primary600 : Color.clear,
                                        lineWidth: 1.4
                                    )
                            }

                        Text("\(dayNumber)")
                            .font(AppFont.paperlogy5Medium(size: 13))
                            .foregroundStyle(cell.isSelected ? .black : weekdayColor(for: cell.weekday))
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .padding(.leading, 6)
                            .padding(.top, 4)
                            .zIndex(1)

                        if cell.hasDiary {
                            Group {
                                if cell.isSelected {
                                    Image("killingpart_music_icon_black")
                                        .resizable()
                                        .scaledToFit()
                                } else {
                                    Image("killingpart_music_icon")
                                        .resizable()
                                        .renderingMode(.template)
                                        .scaledToFit()
                                        .foregroundStyle(AppColors.primary600)
                                }
                            }
                            .frame(width: 14, height: 16)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                            .padding(.bottom, 4)
                            .zIndex(5)
                        }
                    }
                    .frame(height: 44)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func weekdayColor(for weekday: Int?) -> Color {
        switch weekday {
        case 1:
            return Color.red.opacity(0.95)
        case 7:
            return Color.blue.opacity(0.95)
        default:
            return .white
        }
    }

    private var calendarGridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
    }
}
