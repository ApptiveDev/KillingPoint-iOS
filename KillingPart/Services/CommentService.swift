import Foundation

protocol CommentServicing {
    func fetchComments(diaryId: Int, page: Int, size: Int) async throws -> CommentListResponse
    func fetchReplies(commentId: Int, page: Int, size: Int) async throws -> CommentPageResponse
    func createComment(diaryId: Int, request: CommentWriteRequest) async throws -> CommentResponse?
    func updateComment(commentId: Int, request: CommentWriteRequest) async throws -> CommentResponse
    func deleteComment(commentId: Int) async throws
    func toggleLike(commentId: Int) async throws -> CommentLikeToggleResponse
    func reportComment(commentId: Int, content: String) async throws
}

struct CommentService: CommentServicing {
    private let apiClient: APIClienting

    init(apiClient: APIClienting = APIClient.shared) {
        self.apiClient = apiClient
    }

    func fetchComments(diaryId: Int, page: Int, size: Int) async throws -> CommentListResponse {
        try await apiClient.request(
            APIRequest(path: "/diaries/\(diaryId)/comments", method: .get, queryItems: pageQuery(page, size), requiresAuthorization: true),
            responseType: CommentListResponse.self
        )
    }

    func fetchReplies(commentId: Int, page: Int, size: Int) async throws -> CommentPageResponse {
        try await apiClient.request(
            APIRequest(path: "/comments/\(commentId)/replies", method: .get, queryItems: pageQuery(page, size), requiresAuthorization: true),
            responseType: CommentPageResponse.self
        )
    }

    /// 등록은 성공(2xx)했는데 바디를 못 읽으면 nil → 호출부에서 목록을 다시 불러온다
    func createComment(diaryId: Int, request: CommentWriteRequest) async throws -> CommentResponse? {
        do {
            return try await apiClient.request(
                jsonRequest(path: "/diaries/\(diaryId)/comments", method: .post, body: request),
                responseType: CommentResponse.self
            )
        } catch APIClientError.decodingFailed {
            return nil
        }
    }

    func updateComment(commentId: Int, request: CommentWriteRequest) async throws -> CommentResponse {
        try await apiClient.request(
            jsonRequest(path: "/comments/\(commentId)", method: .put, body: request),
            responseType: CommentResponse.self
        )
    }

    func deleteComment(commentId: Int) async throws {
        try await apiClient.request(
            APIRequest(path: "/comments/\(commentId)", method: .delete, requiresAuthorization: true)
        )
    }

    func toggleLike(commentId: Int) async throws -> CommentLikeToggleResponse {
        try await apiClient.request(
            APIRequest(path: "/comments/\(commentId)/like", method: .post, requiresAuthorization: true),
            responseType: CommentLikeToggleResponse.self
        )
    }

    func reportComment(commentId: Int, content: String) async throws {
        try await apiClient.request(
            jsonRequest(
                path: "/comments/\(commentId)/reports",
                method: .post,
                body: CommentReportRequest(content: content.trimmingCharacters(in: .whitespacesAndNewlines))
            )
        )
    }

    private func pageQuery(_ page: Int, _ size: Int) -> [URLQueryItem] {
        [URLQueryItem(name: "page", value: String(page)), URLQueryItem(name: "size", value: String(size))]
    }

    private func jsonRequest(path: String, method: HTTPMethod, body: some Encodable) throws -> APIRequest {
        var request = APIRequest(path: path, method: method, requiresAuthorization: true, body: try JSONEncoder().encode(body))
        request.headers["Accept"] = "application/json"
        request.headers["Content-Type"] = "application/json"
        return request
    }
}
