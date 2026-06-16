import Foundation
import Testing
@testable import KillingPart

@MainActor
struct NotificationListDeepLinkTests {
    @Test
    func universalLinkDiaryRouteCreatesSocialDestinationWhenUserIDIsMissing() async throws {
        let diary = DiaryFeedModel.make(diaryId: 1665, userId: 0)
        let diaryService = MockDiaryService(fetchDiaryResult: diary)
        let viewModel = NotificationListViewModel(diaryService: diaryService)

        await viewModel.handleUniversalLinkDiaryRoute(diaryId: 1665)

        let destination = try #require(viewModel.activeSocialDiaryDestination)
        #expect(destination.diary.diaryId == 1665)
        #expect(destination.diary.userId == 0)
        #expect(destination.displayTag == "@killingpart_user")
        #expect(viewModel.routingErrorMessage == nil)
    }
}

private final class MockDiaryService: DiaryServicing {
    let fetchDiaryResult: DiaryFeedModel

    init(fetchDiaryResult: DiaryFeedModel) {
        self.fetchDiaryResult = fetchDiaryResult
    }

    func fetchMyDiaries(page: Int, size: Int) async throws -> MyDiaryFeedsResponse {
        throw MockDiaryServiceError.unexpectedCall
    }

    func fetchStoredDiaries(page: Int, size: Int) async throws -> StoredDiaryFeedsResponse {
        throw MockDiaryServiceError.unexpectedCall
    }

    func fetchMyFeeds(page: Int, size: Int) async throws -> MyDiaryFeedsResponse {
        throw MockDiaryServiceError.unexpectedCall
    }

    func fetchRandomDiaries() async throws -> RandomDiaryFeedsResponse {
        throw MockDiaryServiceError.unexpectedCall
    }

    func fetchDiary(diaryId: Int) async throws -> DiaryFeedModel {
        fetchDiaryResult
    }

    func fetchUserFeeds(userId: Int, page: Int, size: Int) async throws -> UserDiaryFeedsResponse {
        throw MockDiaryServiceError.unexpectedCall
    }

    func fetchDiaryLikeUsers(diaryId: Int, searchCond: String?, page: Int, size: Int) async throws -> UserSearchResponse {
        throw MockDiaryServiceError.unexpectedCall
    }

    func createDiary(request: DiaryCreateRequest) async throws -> DiaryCreateResult {
        throw MockDiaryServiceError.unexpectedCall
    }

    func updateDiary(diaryId: Int, request: DiaryUpdateRequest) async throws {}

    func deleteDiary(diaryId: Int) async throws {}

    func updateMyDiaryOrder(request: DiaryOrderUpdateRequest) async throws {}

    func toggleDiaryLike(diaryId: Int) async throws -> DiaryLikeToggleResponse {
        throw MockDiaryServiceError.unexpectedCall
    }

    func toggleDiaryStore(diaryId: Int) async throws -> DiaryStoreToggleResponse {
        throw MockDiaryServiceError.unexpectedCall
    }

    func reportDiary(diaryId: Int, content: String) async throws {}
}

private enum MockDiaryServiceError: Error {
    case unexpectedCall
}

private extension DiaryFeedModel {
    static func make(diaryId: Int, userId: Int) -> DiaryFeedModel {
        DiaryFeedModel(
            diaryId: diaryId,
            artist: "Artist",
            musicTitle: "Title",
            albumImageUrl: "",
            content: "Content",
            videoUrl: "",
            scope: .public,
            duration: "00:10",
            totalDuration: "03:00",
            start: "00:01",
            end: "00:10",
            createDate: "2026-06-16T00:00:00",
            updateDate: "2026-06-16T00:00:00",
            isLiked: false,
            isStored: false,
            likeCount: 0,
            userId: userId,
            username: nil,
            tag: nil,
            profileImageUrl: nil,
            isMyPick: nil
        )
    }
}
