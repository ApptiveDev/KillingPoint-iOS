import Foundation

@MainActor
final class InitialSetupFlowViewModel: ObservableObject {
    enum Step: Hashable {
        case policyAgreement
        case nameSetup
        case tagSetup
        case tutorialChoice
        case tutorialTrackSearch
        case tutorialTrim
        case tutorialHome
        case tutorialDiaryDetail
        case tutorialNotification
        case tutorialFinal
    }

    @Published private(set) var step: Step
    @Published private(set) var initSettings: UserInitSettingsResponse
    @Published var isLoading = false
    @Published var errorMessage: String?

    @Published var isServiceTermsAgreed: Bool = false
    @Published var isPrivacyAgreed: Bool = false

    @Published var nameDraft = ""
    @Published var tagDraft = ""

    @Published var selectedTrack: SpotifySimpleTrack?
    @Published private(set) var tutorialDiaries: [DiaryFeedModel] = []
    @Published private(set) var calendarDiaryCountByDate: [(String, Int)] = []
    @Published private(set) var calendarDiariesByDate: [String: [DiaryFeedModel]] = [:]
    @Published private(set) var displayName: String = "홍길동"
    @Published private(set) var displayTag: String = "@killingpart_user"

    private let userService: UserServicing
    private let diaryService: DiaryServicing
    private let calendarService: CalendarServicing
    private let shouldSkipNameSetupForAppleLogin: Bool

    var onComplete: (() -> Void)?

    init(
        settings: UserInitSettingsResponse,
        shouldSkipNameSetupForAppleLogin: Bool = false,
        userService: UserServicing = UserService(),
        diaryService: DiaryServicing = DiaryService(),
        calendarService: CalendarServicing = CalendarService()
    ) {
        self.initSettings = settings
        self.shouldSkipNameSetupForAppleLogin = shouldSkipNameSetupForAppleLogin
        self.userService = userService
        self.diaryService = diaryService
        self.calendarService = calendarService
        if settings.needsPolicyAgreement {
            self.step = .policyAgreement
        } else if settings.needsTagSetup {
            self.step = shouldSkipNameSetupForAppleLogin ? .tagSetup : .nameSetup
        } else {
            self.step = .tutorialChoice
        }
        syncPolicyAgreementState(with: settings)
    }

    var canSubmitPolicyAgreement: Bool {
        isServiceTermsAgreed && isPrivacyAgreed
    }

    var canSubmitName: Bool {
        validateName(nameDraft) == nil
    }

    var canSubmitTag: Bool {
        validateTag(tagDraft) == nil
    }

    func openTutorialChoice() {
        step = .tutorialChoice
    }

    func submitPolicyAgreement() async {
        guard !isLoading else { return }
        guard canSubmitPolicyAgreement else {
            errorMessage = "필수 약관에 모두 동의해 주세요."
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let agreements = initSettings.policies.map { policy in
                PolicyAgreementItem(
                    policyType: policy.policyType,
                    agreed: agreementValue(for: policy.policyType)
                )
            }
            try await userService.submitPolicyAgreement(agreements: agreements)
            let refreshedSettings = try await userService.fetchInitSettings()
            applyRefreshedSettingsAfterPolicyAgreement(refreshedSettings)
        } catch {
            if isRequestCancelled(error) { return }
            errorMessage = resolveErrorMessage(from: error)
        }
    }

    func submitName() async {
        guard !isLoading else { return }
        guard let validationError = validateName(nameDraft) else {
            isLoading = true
            errorMessage = nil
            defer { isLoading = false }

            do {
                _ = try await userService.updateMyUsername(username: normalizedName(nameDraft))
                step = .tagSetup
            } catch {
                if isRequestCancelled(error) { return }
                errorMessage = resolveErrorMessage(from: error)
            }
            return
        }

        errorMessage = validationError
    }

    func submitTag() async {
        guard !isLoading else { return }
        guard let validationError = validateTag(tagDraft) else {
            isLoading = true
            errorMessage = nil
            defer { isLoading = false }

            do {
                let updatedUser = try await userService.updateMyTag(tag: normalizedTag(tagDraft))
                let trimmedTag = updatedUser.tag.trimmingCharacters(in: .whitespacesAndNewlines)
                displayTag = trimmedTag.hasPrefix("@") ? trimmedTag : "@\(trimmedTag)"
                step = .tutorialChoice
            } catch {
                if isRequestCancelled(error) { return }
                errorMessage = resolveErrorMessage(from: error)
            }
            return
        }

        errorMessage = validationError
    }

    func startTutorialTrackSelection() {
        errorMessage = nil
        step = .tutorialTrackSearch
    }

    func skipAllTutorialAndFinish() {
        onComplete?()
    }

    func selectTutorialTrack(_ track: SpotifySimpleTrack) {
        selectedTrack = track
        errorMessage = nil
        step = .tutorialTrim
    }

    func moveToTutorialHomeAfterDiarySaved() async {
        await loadTutorialHomeData()
        guard !tutorialDiaries.isEmpty else {
            errorMessage = "튜토리얼 데이터를 불러오지 못했어요. 다시 시도해 주세요."
            return
        }
        step = .tutorialHome
    }

    func loadTutorialHomeData() async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let user = try await userService.fetchMyUser()
            let trimmedName = user.username.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedTag = user.tag.trimmingCharacters(in: .whitespacesAndNewlines)
            displayName = trimmedName.isEmpty ? "홍길동" : trimmedName
            displayTag = trimmedTag.isEmpty ? "@killingpart_user" : (trimmedTag.hasPrefix("@") ? trimmedTag : "@\(trimmedTag)")
        } catch {
            if !isRequestCancelled(error) {
                displayName = "홍길동"
                displayTag = "@killingpart_user"
            }
        }

        do {
            async let diariesTask = diaryService.fetchMyDiaries(page: 0, size: 20)
            async let calendarTask = calendarService.fetchMyCalendarDiaries(
                startDate: Self.currentMonthStartDate,
                endDate: Self.currentMonthEndDate
            )

            let (diaryResponse, calendarResponse) = try await (diariesTask, calendarTask)
            tutorialDiaries = diaryResponse.content
            calendarDiariesByDate = calendarResponse.diariesByDate

            let sorted = calendarResponse.diariesByDate
                .map { ($0.key, $0.value.count) }
                .sorted { $0.0 < $1.0 }
            calendarDiaryCountByDate = sorted
        } catch {
            if isRequestCancelled(error) { return }
            errorMessage = resolveErrorMessage(from: error)
        }
    }

    func goToDiaryDetailTutorial() {
        guard !tutorialDiaries.isEmpty else {
            errorMessage = "다이어리 데이터가 없어요."
            return
        }
        step = .tutorialDiaryDetail
    }

    func goToNotificationTutorial() {
        step = .tutorialNotification
    }

    func goToFinalTutorial() {
        step = .tutorialFinal
    }

    func finishTutorial() {
        onComplete?()
    }

    var firstDiary: DiaryFeedModel? {
        tutorialDiaries.first
    }

    var policyStatusByType: [UserPolicyType: UserPolicyStatus] {
        Dictionary(uniqueKeysWithValues: initSettings.policies.map { ($0.policyType, $0) })
    }

    func validateName(_ rawName: String) -> String? {
        let name = normalizedName(rawName)
        guard !name.isEmpty else {
            return "이름을 입력해 주세요."
        }

        guard (1...20).contains(name.count) else {
            return "이름은 1자 이상 20자 이하로 입력해 주세요."
        }

        let pattern = "^[A-Za-z0-9가-힣\\s]+$"
        if name.range(of: pattern, options: .regularExpression) == nil {
            return "이름은 영어, 한글, 숫자, 공백만 사용할 수 있어요."
        }

        return nil
    }

    func validateTag(_ rawTag: String) -> String? {
        let tag = normalizedTag(rawTag)
        guard (4...30).contains(tag.count) else {
            return "tag는 4자 이상 30자 이하이어야 합니다."
        }

        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789_.")
        if tag.rangeOfCharacter(from: allowed.inverted) != nil {
            return "영문 소문자, 숫자, '_', '.'만 사용 가능해요."
        }

        if tag.hasPrefix(".") || tag.hasSuffix(".") || tag.contains("..") {
            return "'.'으로 시작/끝낼 수 없고 연속 사용은 불가합니다."
        }

        return nil
    }

    func normalizedName(_ rawName: String) -> String {
        rawName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func normalizedTag(_ rawTag: String) -> String {
        let trimmed = rawTag.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("@") {
            return String(trimmed.dropFirst())
        }
        return trimmed
    }

    private func syncPolicyAgreementState(with settings: UserInitSettingsResponse) {
        let statusByType = Dictionary(uniqueKeysWithValues: settings.policies.map { ($0.policyType, $0.agreed) })
        isServiceTermsAgreed = statusByType[.serviceTerms] ?? false
        isPrivacyAgreed = statusByType[.privacy] ?? false
    }

    private func applyRefreshedSettingsAfterPolicyAgreement(_ settings: UserInitSettingsResponse) {
        initSettings = settings
        syncPolicyAgreementState(with: settings)

        if settings.needsPolicyAgreement {
            step = .policyAgreement
            errorMessage = "필수 약관 동의가 완료되지 않았어요."
            return
        }

        if settings.needsTagSetup {
            step = shouldSkipNameSetupForAppleLogin ? .tagSetup : .nameSetup
            return
        }

        onComplete?()
    }

    private func agreementValue(for type: UserPolicyType) -> Bool {
        switch type {
        case .serviceTerms:
            return isServiceTermsAgreed
        case .privacy:
            return isPrivacyAgreed
        }
    }

    private func resolveErrorMessage(from error: Error) -> String {
        if let userError = error as? UserServiceError {
            return userError.errorDescription ?? "요청 처리에 실패했어요."
        }

        if let apiError = error as? APIClientError {
            return apiError.errorDescription ?? "요청 처리에 실패했어요."
        }

        if let localizedError = error as? LocalizedError {
            return localizedError.errorDescription ?? "요청 처리에 실패했어요."
        }

        return "요청 처리에 실패했어요."
    }

    private func isRequestCancelled(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
    }

    private static let currentMonthStartDate: String = {
        let calendar = Calendar.current
        let now = Date()
        let start = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        return dateFormatter.string(from: start)
    }()

    private static let currentMonthEndDate: String = {
        let calendar = Calendar.current
        let now = Date()
        let start = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: start) ?? now
        let end = calendar.date(byAdding: .day, value: -1, to: nextMonth) ?? now
        return dateFormatter.string(from: end)
    }()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = .current
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
