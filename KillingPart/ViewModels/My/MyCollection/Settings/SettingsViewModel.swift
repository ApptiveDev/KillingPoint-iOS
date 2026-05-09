import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var feedbackContent: String = ""
    @Published private(set) var isSubmittingFeedback = false
    @Published var feedbackErrorMessage: String?
    @Published var feedbackSuccessMessage: String?

    private let surveyService: SurveyServicing
    private let maxFeedbackLength = 1000

    init(surveyService: SurveyServicing = SurveyService()) {
        self.surveyService = surveyService
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
            feedbackErrorMessage = resolveErrorMessage(from: error)
            feedbackSuccessMessage = nil
            return false
        }
    }

    private func resolveErrorMessage(from error: Error) -> String {
        if let surveyError = error as? SurveyServiceError {
            return surveyError.errorDescription ?? "문의 전송에 실패했어요."
        }

        if let apiError = error as? APIClientError {
            return apiError.errorDescription ?? "문의 전송에 실패했어요."
        }

        if let localizedError = error as? LocalizedError {
            return localizedError.errorDescription ?? "문의 전송에 실패했어요."
        }

        return "문의 전송에 실패했어요."
    }

    private func isRequestCancelled(_ error: Error) -> Bool {
        if error is CancellationError {
            return true
        }

        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
    }
}
