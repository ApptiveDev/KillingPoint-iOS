import Foundation

@MainActor
final class MusicCalendarViewModel: ObservableObject {
    @Published var selectedDate: Date
    @Published private(set) var displayedMonth: Date
    @Published private(set) var diariesByDate: [String: [DiaryFeedModel]] = [:]
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let calendarService: CalendarServicing
    private let calendar: Calendar
    private var hasLoadedInitially = false

    init(
        calendarService: CalendarServicing = CalendarService(),
        calendar: Calendar = .current,
        now: Date = Date()
    ) {
        self.calendarService = calendarService
        self.calendar = calendar

        let startOfCurrentMonth = calendar.date(
            from: calendar.dateComponents([.year, .month], from: now)
        ) ?? now

        self.selectedDate = now
        self.displayedMonth = startOfCurrentMonth
    }

    var yearText: String {
        let year = calendar.component(.year, from: displayedMonth)
        return "\(year)년"
    }

    var monthText: String {
        let month = calendar.component(.month, from: displayedMonth)
        return "\(month)월"
    }

    var selectedDateTitle: String {
        Self.selectedDateFormatter.string(from: selectedDate)
    }

    var weekdayTitles: [String] {
        ["일", "월", "화", "수", "목", "금", "토"]
    }

    var selectedDateDiaries: [DiaryFeedModel] {
        diariesByDate[dateKey(for: selectedDate)] ?? []
    }

    var dayCells: [MusicCalendarDayCell] {
        let firstDayOfMonth = startOfMonth(for: displayedMonth)
        let numberOfDaysInMonth = calendar.range(of: .day, in: .month, for: firstDayOfMonth)?.count ?? 0
        let firstWeekdayIndex = max(calendar.component(.weekday, from: firstDayOfMonth) - 1, 0)

        var cells: [MusicCalendarDayCell] = []
        cells.reserveCapacity(firstWeekdayIndex + numberOfDaysInMonth + 7)

        if firstWeekdayIndex > 0 {
            for _ in 0..<firstWeekdayIndex {
                cells.append(.placeholder)
            }
        }

        for day in 1...numberOfDaysInMonth {
            guard
                let date = calendar.date(
                    byAdding: .day,
                    value: day - 1,
                    to: firstDayOfMonth
                )
            else {
                continue
            }

            let diaryCount = diariesByDate[dateKey(for: date)]?.count ?? 0
            cells.append(
                MusicCalendarDayCell(
                    date: date,
                    dayNumber: day,
                    weekday: calendar.component(.weekday, from: date),
                    isToday: calendar.isDateInToday(date),
                    isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                    hasDiary: diaryCount > 0
                )
            )
        }

        let trailingPlaceholderCount = (7 - (cells.count % 7)) % 7
        if trailingPlaceholderCount > 0 {
            for _ in 0..<trailingPlaceholderCount {
                cells.append(.placeholder)
            }
        }

        // Keep a stable six-row layout to prevent vertical jumping between months.
        let minimumVisibleCellCount = 42
        if cells.count < minimumVisibleCellCount {
            for _ in 0..<(minimumVisibleCellCount - cells.count) {
                cells.append(.placeholder)
            }
        }

        return cells
    }

    func onAppear() {
        guard !hasLoadedInitially else { return }
        hasLoadedInitially = true
        Task {
            await loadDisplayedMonthDiaries()
        }
    }

    func moveMonth(by monthOffset: Int) {
        guard
            let movedMonth = calendar.date(
                byAdding: .month,
                value: monthOffset,
                to: displayedMonth
            )
        else {
            return
        }

        displayedMonth = startOfMonth(for: movedMonth)
        selectedDate = displayedMonth

        Task {
            await loadDisplayedMonthDiaries()
        }
    }

    func selectDate(_ date: Date) {
        selectedDate = date
        let selectedMonthStart = startOfMonth(for: date)

        if !calendar.isDate(selectedMonthStart, equalTo: displayedMonth, toGranularity: .month) {
            displayedMonth = selectedMonthStart
            Task {
                await loadDisplayedMonthDiaries()
            }
        }
    }

    func applyPickerDate(_ date: Date) {
        selectDate(date)
    }

    private func loadDisplayedMonthDiaries() async {
        let monthStart = startOfMonth(for: displayedMonth)
        guard
            let monthEnd = endOfMonth(for: monthStart)
        else {
            errorMessage = "날짜 범위를 계산하지 못했어요."
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let response = try await calendarService.fetchMyCalendarDiaries(
                startDate: Self.dateKeyFormatter.string(from: monthStart),
                endDate: Self.dateKeyFormatter.string(from: monthEnd)
            )

            let targetMonthKey = monthKey(for: monthStart)
            diariesByDate = diariesByDate.filter { dateKey, _ in
                monthKey(for: dateKey) != targetMonthKey
            }

            for (dateKey, diaries) in response.diariesByDate where monthKey(for: dateKey) == targetMonthKey {
                diariesByDate[dateKey] = diaries
            }
        } catch {
            if isRequestCancelled(error) {
                isLoading = false
                return
            }
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "캘린더 데이터를 불러오지 못했어요."
        }

        isLoading = false
    }

    private func startOfMonth(for date: Date) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
    }

    private func endOfMonth(for monthStart: Date) -> Date? {
        guard let nextMonthStart = calendar.date(byAdding: .month, value: 1, to: monthStart) else {
            return nil
        }
        return calendar.date(byAdding: .day, value: -1, to: nextMonthStart)
    }

    private func dateKey(for date: Date) -> String {
        Self.dateKeyFormatter.string(from: date)
    }

    private func monthKey(for date: Date) -> String {
        let components = calendar.dateComponents([.year, .month], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        return String(format: "%04d-%02d", year, month)
    }

    private func monthKey(for dateKey: String) -> String {
        let parts = dateKey.split(separator: "-")
        guard parts.count >= 2 else { return "" }
        return "\(parts[0])-\(parts[1])"
    }

    private func isRequestCancelled(_ error: Error) -> Bool {
        if error is CancellationError {
            return true
        }

        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
    }

    private static let dateKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = .current
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let selectedDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = .current
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = .current
        formatter.dateFormat = "M월 d일 EEEE"
        return formatter
    }()
}

struct MusicCalendarDayCell: Identifiable {
    let id: String
    let date: Date?
    let dayNumber: Int?
    let weekday: Int?
    let isToday: Bool
    let isSelected: Bool
    let hasDiary: Bool

    var isPlaceholder: Bool {
        date == nil
    }

    init(
        date: Date?,
        dayNumber: Int?,
        weekday: Int?,
        isToday: Bool,
        isSelected: Bool,
        hasDiary: Bool
    ) {
        self.id = date.map { String(Int($0.timeIntervalSince1970)) } ?? UUID().uuidString
        self.date = date
        self.dayNumber = dayNumber
        self.weekday = weekday
        self.isToday = isToday
        self.isSelected = isSelected
        self.hasDiary = hasDiary
    }

    static var placeholder: MusicCalendarDayCell {
        MusicCalendarDayCell(
            date: nil,
            dayNumber: nil,
            weekday: nil,
            isToday: false,
            isSelected: false,
            hasDiary: false
        )
    }
}
