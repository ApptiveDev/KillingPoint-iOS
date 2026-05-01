import SwiftUI
import UIKit

struct TutorialHomeScreen: View {
    @ObservedObject var viewModel: InitialSetupFlowViewModel
    @State private var selectedTab: TutorialHomeTab = .collection
    @State private var tabTransitionDirection: Edge = .trailing
    @State private var displayedMonth: Date = TutorialHomeScreen.startOfMonth(for: Date())
    @State private var selectedDate: Date = Date()

    private static var hasConfiguredSegmentedControlAppearance = false

    var body: some View {
        VStack(spacing: AppSpacing.m) {
            header

            topToggleTabs

            ZStack {
                if selectedTab == .collection {
                    collectionContent
                        .transition(tabContentTransition)
                } else {
                    calendarContent
                        .transition(tabContentTransition)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .clipped()

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(AppFont.paperlogy4Regular(size: 13))
                    .foregroundStyle(.red.opacity(0.95))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            PrimaryButton(title: "다음으로") {
                viewModel.goToDiaryDetailTutorial()
            }
        }
        .padding(.horizontal, AppSpacing.l)
        .padding(.top, AppSpacing.l)
        .padding(.bottom, AppSpacing.l)
        .background(
            Image("my_background")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
        )
        .task {
            await viewModel.loadTutorialHomeData()
            syncInitialCalendarStateIfNeeded()
        }
        .onAppear {
            configureSegmentedControlFontIfNeeded()
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            InitialSetupSkipButtonRow(onSkip: viewModel.skipAllTutorialAndFinish)
        }
    }

    private var header: some View {
        Text("추가한 킬링파트는\n여기서 다시 볼 수 있어요.")
            .font(AppFont.paperlogy7Bold(size: 24))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    private var topToggleTabs: some View {
        Picker("튜토리얼 홈 탭", selection: segmentedSelectionBinding) {
            ForEach(TutorialHomeTab.allCases, id: \.self) { tab in
                Text(tab.title)
                    .font(AppFont.paperlogy4Regular(size: 11))
                    .tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .controlSize(.large)
        .scaleEffect(x: 1, y: 1.08, anchor: .center)
        .padding(.bottom, AppSpacing.xs)
    }

    private var segmentedSelectionBinding: Binding<TutorialHomeTab> {
        Binding(
            get: { selectedTab },
            set: { newTab in
                selectTab(newTab)
            }
        )
    }

    private func selectTab(_ newTab: TutorialHomeTab) {
        let previousIndex = selectedTab.order
        let nextIndex = newTab.order
        guard previousIndex != nextIndex else { return }
        tabTransitionDirection = nextIndex > previousIndex ? .trailing : .leading

        withAnimation(.interactiveSpring(response: 0.32, dampingFraction: 0.85, blendDuration: 0.1)) {
            selectedTab = newTab
        }
    }

    private var tabContentTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: tabTransitionDirection).combined(with: .opacity),
            removal: .move(edge: tabTransitionDirection == .trailing ? .leading : .trailing).combined(with: .opacity)
        )
    }

    @ViewBuilder
    private var collectionContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.s) {
                MyCollectionProfileCard(
                    displayName: viewModel.displayName,
                    displayTag: viewModel.displayTag,
                    profileImageURL: profileImageURL,
                    killingPartStatText: "\(viewModel.tutorialDiaries.count)",
                    fanStatText: "0",
                    pickStatText: "0",
                    onFanStatTap: {},
                    onPickStatTap: {},
                    onEditProfileTap: {},
                    showEditButton: false
                )
                .background(Color.black.opacity(0.74))
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay {
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                }

                Text("내 킬링파트")
                    .font(AppFont.paperlogy6SemiBold(size: 14))
                    .foregroundStyle(.white)
                    .padding(.horizontal, AppSpacing.xs)

                if viewModel.tutorialDiaries.isEmpty {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.08))
                        .frame(maxWidth: .infinity)
                        .frame(height: 140)
                        .overlay {
                            if viewModel.isLoading {
                                ProgressView()
                                    .tint(AppColors.primary600)
                            } else {
                                Text("아직 작성한 피드가 없어요.")
                                    .font(AppFont.paperlogy5Medium(size: 14))
                                    .foregroundStyle(.white.opacity(0.72))
                            }
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        }
                } else {
                    LazyVGrid(columns: feedGridColumns, spacing: AppSpacing.s) {
                        ForEach(viewModel.tutorialDiaries.prefix(6)) { diary in
                            MyCollectionFeedCard(
                                feed: diary,
                                formattedUpdateDate: formattedUpdateDate(from: diary.updateDate)
                            )
                            .background(Color.black.opacity(0.78))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay {
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, AppSpacing.m)
        }
        .scrollIndicators(.hidden)
    }

    private var calendarContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.m) {
                MusicCalendarHeaderSection(
                    yearText: "\(year(from: displayedMonth))년",
                    monthText: "\(month(from: displayedMonth))월",
                    onMonthTap: {},
                    onPreviousMonthTap: {
                        guard let movedMonth = Calendar.current.date(byAdding: .month, value: -1, to: displayedMonth) else { return }
                        displayedMonth = Self.startOfMonth(for: movedMonth)
                        selectedDate = displayedMonth
                    },
                    onNextMonthTap: {
                        guard let movedMonth = Calendar.current.date(byAdding: .month, value: 1, to: displayedMonth) else { return }
                        displayedMonth = Self.startOfMonth(for: movedMonth)
                        selectedDate = displayedMonth
                    }
                )

                MusicCalendarCalendarSection(
                    weekdayTitles: ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"],
                    dayCells: calendarDayCells,
                    onDayTap: { date in
                        withAnimation(.easeInOut(duration: 0.24)) {
                            selectedDate = date
                        }
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                }

                VStack(alignment: .leading, spacing: AppSpacing.s) {
                    Text(selectedDateTitle)
                        .font(AppFont.paperlogy6SemiBold(size: 16))
                        .foregroundStyle(.white)

                    if diariesForSelectedDate.isEmpty {
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
                        LazyVStack(spacing: AppSpacing.xs) {
                            ForEach(diariesForSelectedDate) { diary in
                                MusicCalendarDiaryRow(diary: diary)
                                    .background(Color.black.opacity(0.62))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                    }
                            }
                        }
                    }
                }
            }
            .padding(.bottom, AppSpacing.s)
        }
        .scrollIndicators(.hidden)
    }

    private var profileImageURL: URL? {
        guard
            let raw = viewModel.tutorialDiaries.first?.profileImageUrl?.trimmingCharacters(in: .whitespacesAndNewlines),
            !raw.isEmpty
        else {
            return nil
        }
        if let parsed = URL(string: raw), parsed.scheme != nil {
            return parsed
        }
        if raw.hasPrefix("//"), let parsed = URL(string: "https:\(raw)") {
            return parsed
        }
        return URL(string: "https://\(raw)")
    }

    private var feedGridColumns: [GridItem] {
        [
            GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: AppSpacing.s),
            GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: AppSpacing.s)
        ]
    }

    private var diariesForSelectedDate: [DiaryFeedModel] {
        viewModel.calendarDiariesByDate[Self.dateKeyFormatter.string(from: selectedDate)] ?? []
    }

    private var selectedDateTitle: String {
        Self.selectedDateFormatter.string(from: selectedDate)
    }

    private var calendarDayCells: [MusicCalendarDayCell] {
        let calendar = Calendar.current
        let firstDayOfMonth = Self.startOfMonth(for: displayedMonth)
        let numberOfDaysInMonth = calendar.range(of: .day, in: .month, for: firstDayOfMonth)?.count ?? 0
        let firstWeekdayIndex = max(calendar.component(.weekday, from: firstDayOfMonth) - 1, 0)

        var cells: [MusicCalendarDayCell] = []
        cells.reserveCapacity(firstWeekdayIndex + numberOfDaysInMonth + 7)

        if firstWeekdayIndex > 0 {
            for _ in 0..<firstWeekdayIndex {
                cells.append(.placeholder)
            }
        }

        if numberOfDaysInMonth > 0 {
            for day in 1...numberOfDaysInMonth {
                guard let date = calendar.date(byAdding: .day, value: day - 1, to: firstDayOfMonth) else { continue }
                let key = Self.dateKeyFormatter.string(from: date)
                let hasDiary = (viewModel.calendarDiariesByDate[key]?.isEmpty == false)
                    || ((viewModel.calendarDiaryCountByDate.first { $0.0 == key }?.1 ?? 0) > 0)
                cells.append(
                    MusicCalendarDayCell(
                        date: date,
                        dayNumber: day,
                        weekday: calendar.component(.weekday, from: date),
                        isToday: calendar.isDateInToday(date),
                        isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                        hasDiary: hasDiary
                    )
                )
            }
        }

        let trailingPlaceholderCount = (7 - (cells.count % 7)) % 7
        if trailingPlaceholderCount > 0 {
            for _ in 0..<trailingPlaceholderCount {
                cells.append(.placeholder)
            }
        }

        if cells.count < 42 {
            for _ in 0..<(42 - cells.count) {
                cells.append(.placeholder)
            }
        }

        return cells
    }

    private func syncInitialCalendarStateIfNeeded() {
        let entries = viewModel.calendarDiaryCountByDate.compactMap { entry -> Date? in
            guard entry.1 > 0 else { return nil }
            return Self.dateKeyFormatter.date(from: entry.0)
        }
        if let firstDiaryDate = entries.sorted().first {
            displayedMonth = Self.startOfMonth(for: firstDiaryDate)
            selectedDate = firstDiaryDate
        } else {
            displayedMonth = Self.startOfMonth(for: Date())
            selectedDate = Date()
        }
    }

    private func formattedUpdateDate(from rawUpdateDate: String) -> String {
        let datePart = rawUpdateDate.split(separator: "T").first.map(String.init) ?? rawUpdateDate
        return datePart.replacingOccurrences(of: "-", with: ".")
    }

    private func year(from date: Date) -> Int {
        Calendar.current.component(.year, from: date)
    }

    private func month(from date: Date) -> Int {
        Calendar.current.component(.month, from: date)
    }

    private static func startOfMonth(for date: Date) -> Date {
        Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: date)) ?? date
    }

    private func configureSegmentedControlFontIfNeeded() {
        guard !Self.hasConfiguredSegmentedControlAppearance else { return }
        Self.hasConfiguredSegmentedControlAppearance = true

        let fallbackFont = UIFont.systemFont(ofSize: 13, weight: .regular)
        let segmentFont = UIFont(name: "Paperlogy-4Regular", size: 13) ?? fallbackFont

        UISegmentedControl.appearance().setTitleTextAttributes([.font: segmentFont], for: .normal)
        UISegmentedControl.appearance().setTitleTextAttributes([.font: segmentFont], for: .selected)
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

private enum TutorialHomeTab: CaseIterable {
    case collection
    case calendar

    var title: String {
        switch self {
        case .collection:
            return "내 컬렉션"
        case .calendar:
            return "뮤직캘린더"
        }
    }

    var order: Int {
        switch self {
        case .collection:
            return 0
        case .calendar:
            return 1
        }
    }
}
