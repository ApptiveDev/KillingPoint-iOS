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
            MusicCalendarDatePickerSheet(
                pickerYear: $pickerYear,
                pickerMonth: $pickerMonth,
                yearOptions: yearOptions,
                onCancel: {
                    isDatePickerPresented = false
                },
                onDone: {
                    viewModel.applyPickerYearMonth(year: pickerYear, month: pickerMonth)
                    isDatePickerPresented = false
                }
            )
        }
        .animation(.easeInOut(duration: 0.24), value: viewModel.selectedDate)
    }

    private var headerSection: some View {
        MusicCalendarHeaderSection(
            yearText: viewModel.yearText,
            monthText: viewModel.monthText,
            onMonthTap: {
                let displayedMonth = viewModel.displayedMonth
                pickerYear = Calendar.current.component(.year, from: displayedMonth)
                pickerMonth = Calendar.current.component(.month, from: displayedMonth)
                isDatePickerPresented = true
            },
            onPreviousMonthTap: {
                viewModel.moveMonth(by: -1)
            },
            onNextMonthTap: {
                viewModel.moveMonth(by: 1)
            }
        )
    }

    private var calendarSection: some View {
        MusicCalendarCalendarSection(
            weekdayTitles: viewModel.weekdayTitles,
            dayCells: viewModel.dayCells,
            onDayTap: { date in
                withAnimation(.easeInOut(duration: 0.24)) {
                    viewModel.selectDate(date)
                }
            }
        )
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
                                    displayTag: viewModel.displayTag
                                )
                            ) {
                                MusicCalendarDiaryRow(diary: diary)
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

    private var yearOptions: [Int] {
        let currentYear = Calendar.current.component(.year, from: Date())
        return Array((currentYear - 30)...(currentYear + 10))
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
