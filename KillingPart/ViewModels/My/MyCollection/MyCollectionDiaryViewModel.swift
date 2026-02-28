import Foundation

@MainActor
final class MyCollectionDiaryViewModel: ObservableObject {
    @Published private(set) var diary: DiaryFeedModel
    @Published var displayedStart: String
    @Published var displayedEnd: String
    @Published var displayedContent: String
    @Published var editContentDraft: String
    @Published var isEditMode = false
    @Published private(set) var isProcessing = false
    @Published private(set) var isDeleted = false
    @Published var errorMessage: String?

    private let diaryService: DiaryServicing

    init(
        diary: DiaryFeedModel,
        diaryService: DiaryServicing = DiaryService()
    ) {
        self.diary = diary
        self.diaryService = diaryService
        self.displayedStart = diary.start
        self.displayedEnd = diary.end
        self.displayedContent = diary.content
        self.editContentDraft = diary.content
    }

    var startSeconds: Double {
        parsedSeconds(from: displayedStart) ?? 0
    }

    var endSeconds: Double {
        let parsedEnd = parsedSeconds(from: displayedEnd) ?? startSeconds
        return max(parsedEnd, startSeconds + 0.1)
    }

    var totalSeconds: Double {
        let parsedTotal = parsedSeconds(from: diary.totalDuration) ?? 0
        return max(parsedTotal, endSeconds, 1)
    }

    var startMinuteSecondText: String {
        TimeFormatter.minuteSecondText(from: startSeconds)
    }

    var endMinuteSecondText: String {
        TimeFormatter.minuteSecondText(from: endSeconds)
    }

    var canSubmitEdit: Bool {
        !isProcessing
            && !trimmedEditContent.isEmpty
            && trimmedEditContent != trimmedDisplayedContent
    }

    func beginEdit() {
        guard !isProcessing else { return }
        editContentDraft = displayedContent
        errorMessage = nil
        isEditMode = true
    }

    func cancelEdit() {
        guard !isProcessing else { return }
        editContentDraft = displayedContent
        errorMessage = nil
        isEditMode = false
    }

    func submitEdit() async -> Bool {
        guard !isProcessing else { return false }
        guard canSubmitEdit else {
            errorMessage = "코멘트를 입력해 주세요."
            return false
        }

        let payload = trimmedEditContent
        let request = DiaryUpdateRequest(
            content: payload
        )

        isProcessing = true
        errorMessage = nil
        defer { isProcessing = false }

        do {
            try await diaryService.updateDiary(diaryId: diary.diaryId, request: request)
            displayedContent = payload
            isEditMode = false
            NotificationCenter.default.post(name: .diaryCreated, object: nil)
            return true
        } catch {
            if isRequestCancelled(error) { return false }
            errorMessage = resolveErrorMessage(from: error)
            return false
        }
    }

    func deleteDiary() async -> Bool {
        guard !isProcessing else { return false }

        isProcessing = true
        errorMessage = nil
        defer { isProcessing = false }

        do {
            try await diaryService.deleteDiary(diaryId: diary.diaryId)
            isDeleted = true
            NotificationCenter.default.post(name: .diaryCreated, object: nil)
            return true
        } catch {
            if isRequestCancelled(error) { return false }
            errorMessage = resolveErrorMessage(from: error)
            return false
        }
    }

    private var trimmedEditContent: String {
        editContentDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedDisplayedContent: String {
        displayedContent.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func parsedSeconds(from value: String) -> Double? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let raw = Double(trimmed) {
            return max(raw, 0)
        }

        let sanitized = trimmed.replacingOccurrences(of: "초", with: "")
        if sanitized.contains(":") {
            let parts = sanitized.split(separator: ":").map(String.init)
            guard
                parts.count == 2,
                let minutes = Double(parts[0]),
                let seconds = Double(parts[1])
            else {
                return nil
            }
            return max((minutes * 60) + seconds, 0)
        }

        if let raw = Double(sanitized) {
            return max(raw, 0)
        }

        return nil
    }

    private func resolveErrorMessage(from error: Error) -> String {
        if let diaryError = error as? DiaryServiceError {
            return diaryError.errorDescription ?? "요청 처리에 실패했어요."
        }

        if let localizedError = error as? LocalizedError {
            return localizedError.errorDescription ?? "요청 처리에 실패했어요."
        }

        return "요청 처리에 실패했어요."
    }

    private func isRequestCancelled(_ error: Error) -> Bool {
        if error is CancellationError {
            return true
        }

        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
    }
}
