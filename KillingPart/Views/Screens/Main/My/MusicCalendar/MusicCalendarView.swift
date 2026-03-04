import SwiftUI

struct MusicCalendarView: View {
    @StateObject private var viewModel: MusicCalendarViewModel
    @State private var isDatePickerPresented = false
    @State private var pickerYear = Calendar.current.component(.year, from: Date())
    @State private var pickerMonth = Calendar.current.component(.month, from: Date())

    init(calendarService: CalendarServicing = CalendarService()) {
        _viewModel = StateObject(
            wrappedValue: MusicCalendarViewModel(calendarService: calendarService)
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            headerSection

            calendarSection

            selectedDateDiarySection
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(AppFont.paperlogy4Regular(size: 13))
                    .foregroundStyle(.red.opacity(0.95))
            }
        }
        .padding(.top, AppSpacing.xs)
        .padding(.bottom, AppSpacing.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            viewModel.onAppear()
        }
        .navigationDestination(for: MusicCalendarDiaryRoute.self) { route in
            MyCollectionDiary(
                diaryId: route.diaryId,
                displayTag: route.displayTag,
                diary: route.initialDiary
            )
        }
        .sheet(isPresented: $isDatePickerPresented) {
            datePickerSheet
        }
    }

    private var headerSection: some View {
        HStack(alignment: .top) {
            Button {
                let displayedMonth = viewModel.displayedMonth
                pickerYear = Calendar.current.component(.year, from: displayedMonth)
                pickerMonth = Calendar.current.component(.month, from: displayedMonth)
                isDatePickerPresented = true
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.yearText)
                        .font(AppFont.paperlogy5Medium(size: 14))
                        .foregroundStyle(.white.opacity(0.8))

                    HStack(spacing: 8) {
                        Text(viewModel.monthText)
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
                Button {
                    viewModel.moveMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Button {
                    viewModel.moveMonth(by: 1)
                } label: {
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

    private var calendarSection: some View {
        Rectangle()
            .fill(Color.black.opacity(0.28))
            .overlay {
                VStack(spacing: AppSpacing.s) {
                    weekdayHeaderRow

                    LazyVGrid(columns: calendarGridColumns, spacing: 0) {
                        ForEach(viewModel.dayCells) { cell in
                            dayCell(cell)
                        }
                    }
                }
                .padding(AppSpacing.m)
            }
            .animation(nil, value: viewModel.displayedMonth)
    }

    private var selectedDateDiarySection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            Text(viewModel.selectedDateTitle)
                .font(AppFont.paperlogy6SemiBold(size: 16))
                .foregroundStyle(.white)

            if viewModel.isLoading {
                HStack {
                    Spacer(minLength: 0)
                    ProgressView()
                        .tint(AppColors.primary600)
                    Spacer(minLength: 0)
                }
                .padding(.vertical, AppSpacing.s)
            } else if viewModel.selectedDateDiaries.isEmpty {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.06))
                    .frame(maxWidth: .infinity)
                    .frame(height: 74)
                    .overlay {
                        Text("선택한 날짜의 킬링파트가 없어요.")
                            .font(AppFont.paperlogy4Regular(size: 13))
                            .foregroundStyle(.white.opacity(0.72))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    }
            } else {
                ScrollView {
                    LazyVStack(spacing: AppSpacing.xs) {
                        ForEach(viewModel.selectedDateDiaries) { diary in
                            NavigationLink(
                                value: MusicCalendarDiaryRoute(
                                    diaryId: diary.diaryId,
                                    initialDiary: diary,
                                    displayTag: diary.tag ?? ""
                                )
                            ) {
                                diaryRow(diary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.bottom, AppSpacing.s)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .scrollIndicators(.hidden)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var weekdayHeaderRow: some View {
        HStack(spacing: AppSpacing.xs) {
            ForEach(Array(viewModel.weekdayTitles.enumerated()), id: \.offset) { index, title in
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
                    viewModel.selectDate(date)
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

    private func diaryRow(_ diary: DiaryFeedModel) -> some View {
        HStack(spacing: AppSpacing.m) {
            albumArtwork(for: diary)

            VStack(alignment: .leading, spacing: 5) {
                Text(diary.musicTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "제목 없음" : diary.musicTitle)
                    .font(AppFont.paperlogy6SemiBold(size: 14))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)

                Text(diary.artist.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "아티스트 정보 없음" : diary.artist)
                    .font(AppFont.paperlogy5Medium(size: 12))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            VStack(spacing: 4) {
                      Text("코멘트읽기")
                          .font(AppFont.paperlogy5Medium(size: 14))
                          .foregroundStyle(Color.kpPrimary)

                      Image(systemName: "arrow.right")
                          .font(.system(size: 12, weight: .semibold))
                          .foregroundStyle(Color.kpPrimary)
                  }
        }
        .padding(.horizontal, AppSpacing.m)
        .padding(.vertical, AppSpacing.m)
        .frame(minHeight: 82)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func albumArtwork(for diary: DiaryFeedModel) -> some View {
        Group {
            if let albumURL = diary.albumImageURL {
                AsyncImage(url: albumURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .empty, .failure:
                        placeholderArtwork
                    @unknown default:
                        placeholderArtwork
                    }
                }
            } else {
                placeholderArtwork
            }
        }
        .frame(width: 58, height: 58)
    }

    private var placeholderArtwork: some View {
        Rectangle()
            .fill(Color.white.opacity(0.12))
            .overlay {
                Image(systemName: "music.note")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.82))
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

    private var yearOptions: [Int] {
        let currentYear = Calendar.current.component(.year, from: Date())
        return Array((currentYear - 30)...(currentYear + 10))
    }

    private var datePickerSheet: some View {
        VStack(spacing: 0) {
            HStack {
                Button("취소") {
                    isDatePickerPresented = false
                }
                .font(AppFont.paperlogy5Medium(size: 14))
                .foregroundStyle(.white.opacity(0.78))

                Spacer(minLength: 0)

                Button("완료") {
                    viewModel.applyPickerYearMonth(year: pickerYear, month: pickerMonth)
                    isDatePickerPresented = false
                }
                .font(AppFont.paperlogy6SemiBold(size: 14))
                .foregroundStyle(AppColors.primary600)
            }
            .padding(.horizontal, AppSpacing.l)
            .padding(.top, AppSpacing.m)

            HStack(spacing: 0) {
                Picker("년도", selection: $pickerYear) {
                    ForEach(yearOptions, id: \.self) { year in
                        Text(verbatim: "\(year)년")
                            .tag(year)
                    }
                }
                .pickerStyle(.wheel)
                .labelsHidden()

                Picker("월", selection: $pickerMonth) {
                    ForEach(1...12, id: \.self) { month in
                        Text(verbatim: "\(month)월")
                            .tag(month)
                    }
                }
                .pickerStyle(.wheel)
                .labelsHidden()
            }
            .frame(height: 220)
            .padding(.horizontal, AppSpacing.m)
            .padding(.bottom, AppSpacing.m)
        }
        .presentationDetents([.height(320)])
        .presentationDragIndicator(.visible)
    }
}

private struct MusicCalendarDiaryRoute: Hashable {
    let diaryId: Int
    let initialDiary: DiaryFeedModel
    let displayTag: String

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.diaryId == rhs.diaryId
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(diaryId)
    }
}
