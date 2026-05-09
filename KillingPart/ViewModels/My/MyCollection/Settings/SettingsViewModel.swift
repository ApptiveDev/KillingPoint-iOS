import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var feedbackContent: String = ""
    @Published private(set) var isSubmittingFeedback = false
    @Published var feedbackErrorMessage: String?
    @Published var feedbackSuccessMessage: String?
    @Published private(set) var isNotificationEnabled = false
    @Published private(set) var isLoadingNotificationSetting = false
    @Published private(set) var isUpdatingNotificationSetting = false
    @Published var notificationSettingErrorMessage: String?

    private let surveyService: SurveyServicing
    private let notificationService: NotificationServicing
    private let maxFeedbackLength = 1000
    private var hasLoadedNotificationSetting = false

    init(
        surveyService: SurveyServicing = SurveyService(),
        notificationService: NotificationServicing = NotificationService()
    ) {
        self.surveyService = surveyService
        self.notificationService = notificationService
    }

    var canSubmitFeedback: Bool {
        guard !isSubmittingFeedback else { return false }
        let trimmed = feedbackContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return trimmed.count <= maxFeedbackLength
    }

    func prepareFeedbackSheet() {
        feedbackErrorMessage = nil
        feedbackSuccessMessage = nil
    }

    func loadNotificationSettingIfNeeded() async {
        guard !hasLoadedNotificationSetting else { return }
        await loadNotificationSetting()
    }

    func updateNotificationSetting(_ isEnabled: Bool) async {
        guard !isUpdatingNotificationSetting else { return }

        let previousValue = isNotificationEnabled
        isNotificationEnabled = isEnabled
        isUpdatingNotificationSetting = true
        notificationSettingErrorMessage = nil
        defer { isUpdatingNotificationSetting = false }

        do {
            let response = try await notificationService.updateMyNotificationSetting(alarmEnabled: isEnabled)
            isNotificationEnabled = response.alarmEnabled
            hasLoadedNotificationSetting = true
        } catch {
            if isRequestCancelled(error) {
                isNotificationEnabled = previousValue
                return
            }
            isNotificationEnabled = previousValue
            notificationSettingErrorMessage = resolveErrorMessage(from: error, defaultMessage: "알림 설정 변경에 실패했어요.")
        }
    }

    func updateFeedbackContent(_ content: String) {
        if content.count > maxFeedbackLength {
            feedbackContent = String(content.prefix(maxFeedbackLength))
        } else {
            feedbackContent = content
        }
        feedbackErrorMessage = nil
        feedbackSuccessMessage = nil
    }

    func submitFeedback() async -> Bool {
        guard !isSubmittingFeedback else { return false }

        let trimmedContent = feedbackContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else {
            feedbackErrorMessage = "빈 값은 입력이 불가능합니다."
            feedbackSuccessMessage = nil
            return false
        }

        guard trimmedContent.count <= maxFeedbackLength else {
            feedbackErrorMessage = "1자 이상 1000자 이하로 작성 가능합니다."
            feedbackSuccessMessage = nil
            return false
        }

        isSubmittingFeedback = true
        feedbackErrorMessage = nil
        feedbackSuccessMessage = nil
        defer { isSubmittingFeedback = false }

        do {
            try await surveyService.submitSurvey(content: trimmedContent)
            feedbackContent = ""
            feedbackSuccessMessage = "문의가 정상적으로 접수되었어요."
            return true
        } catch {
            if isRequestCancelled(error) { return false }
            feedbackErrorMessage = resolveErrorMessage(from: error, defaultMessage: "문의 전송에 실패했어요.")
            feedbackSuccessMessage = nil
            return false
        }
    }

    private func loadNotificationSetting() async {
        guard !isLoadingNotificationSetting else { return }

        isLoadingNotificationSetting = true
        notificationSettingErrorMessage = nil
        defer { isLoadingNotificationSetting = false }

        do {
            let response = try await notificationService.fetchMyNotificationSetting()
            isNotificationEnabled = response.alarmEnabled
            hasLoadedNotificationSetting = true
        } catch {
            if isRequestCancelled(error) { return }
            notificationSettingErrorMessage = resolveErrorMessage(from: error, defaultMessage: "알림 설정을 불러오지 못했어요.")
        }
    }

    private func resolveErrorMessage(from error: Error, defaultMessage: String) -> String {
        if let surveyError = error as? SurveyServiceError {
            return surveyError.errorDescription ?? defaultMessage
        }

        if let notificationError = error as? NotificationServiceError {
            return notificationError.errorDescription ?? defaultMessage
        }

        if let apiError = error as? APIClientError {
            return apiError.errorDescription ?? defaultMessage
        }

        if let localizedError = error as? LocalizedError {
            return localizedError.errorDescription ?? defaultMessage
        }

        return defaultMessage
    }

    private func isRequestCancelled(_ error: Error) -> Bool {
        if error is CancellationError {
            return true
        }

        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
    }
}
