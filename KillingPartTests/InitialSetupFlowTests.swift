import Foundation
import Testing
@testable import KillingPart

@MainActor
struct InitialSetupFlowTests {
    @Test
    func validatesNameRules() {
        let viewModel = InitialSetupFlowViewModel(settings: .make())

        #expect(viewModel.validateName("") != nil)
        #expect(viewModel.validateName("홍길동 123") == nil)
        #expect(viewModel.validateName("A B C") == nil)
        #expect(viewModel.validateName(String(repeating: "a", count: 21)) != nil)
        #expect(viewModel.validateName("name*") != nil)
    }

    @Test
    func validatesTagRules() {
        let viewModel = InitialSetupFlowViewModel(settings: .make())

        #expect(viewModel.validateTag("ab") != nil)
        #expect(viewModel.validateTag("abcd") == nil)
        #expect(viewModel.validateTag("ab..cd") != nil)
        #expect(viewModel.validateTag(".abcd") != nil)
        #expect(viewModel.validateTag("abcd.") != nil)
        #expect(viewModel.validateTag("abCD") != nil)
        #expect(viewModel.validateTag("valid_tag.01") == nil)
    }

    @Test
    func postLoginRoutePrefersUpdatePromptAndSetupFlow() async {
        let settings = UserInitSettingsResponse(
            app: UserAppUpdateStatus(needsForceUpdate: true, needsOptionalUpdate: true),
            needsPolicyAgreement: true,
            needsTagSetup: true,
            policies: [
                .init(
                    policyType: .serviceTerms,
                    required: true,
                    agreed: false,
                    currentRevision: 0,
                    latestRevision: 1
                ),
                .init(
                    policyType: .privacy,
                    required: true,
                    agreed: false,
                    currentRevision: 0,
                    latestRevision: 1
                )
            ]
        )

        let userService = MockUserService(settings: settings)
        let tokenStore = MockTokenStore(hasSessionTokens: true)
        let viewModel = AppViewModel(
            userService: userService,
            tokenStore: tokenStore
        )

        await viewModel.resolvePostLoginFlow()

        #expect(viewModel.currentStep == .setup)
        #expect(viewModel.updatePrompt == .force)
        #expect(viewModel.setupFlowViewModel?.step == .policyAgreement)
    }

    @Test
    func postLoginRouteGoesMainWhenNoSetupRequired() async {
        let settings = UserInitSettingsResponse(
            app: UserAppUpdateStatus(needsForceUpdate: false, needsOptionalUpdate: true),
            needsPolicyAgreement: false,
            needsTagSetup: false,
            policies: []
        )

        let userService = MockUserService(settings: settings)
        let tokenStore = MockTokenStore(hasSessionTokens: true)
        let viewModel = AppViewModel(
            userService: userService,
            tokenStore: tokenStore
        )

        await viewModel.resolvePostLoginFlow()

        #expect(viewModel.currentStep == .main)
        #expect(viewModel.updatePrompt == .optional)
        #expect(viewModel.setupFlowViewModel == nil)
    }
}

private final class MockUserService: UserServicing {
    private let settings: UserInitSettingsResponse

    init(settings: UserInitSettingsResponse) {
        self.settings = settings
    }

    func fetchMyUser() async throws -> UserModel {
        .init(
            userId: 1,
            username: "test",
            tag: "tester",
            identifier: "KAKAO-1",
            profileImageUrl: "",
            userRoleType: "USER",
            socialType: "KAKAO"
        )
    }

    func fetchInitSettings() async throws -> UserInitSettingsResponse { settings }

    func submitPolicyAgreement(agreements: [PolicyAgreementItem]) async throws {}

    func fetchUserStatics(userId: Int) async throws -> UserStaticsModel {
        .init(fanCount: 0, pickCount: 0, killingPartCount: 0)
    }

    func searchUsers(searchCond: String?, page: Int, size: Int) async throws -> UserSearchResponse {
        .init(content: [], page: .init(size: 0, number: 0, totalElements: 0, totalPages: 0))
    }

    func deleteMyProfileImage() async throws -> UserModel {
        try await fetchMyUser()
    }

    func issuePresignedURL() async throws -> PresignedURLResponse {
        .init(id: 0, presignedUrl: "")
    }

    func uploadImageToPresignedURL(imageData: Data, presignedURL: URL) async throws {}

    func updateMyProfileImage(request: UpdateMyProfileImageRequest) async throws -> UserModel {
        try await fetchMyUser()
    }

    func updateMyUsername(username: String) async throws -> UserModel {
        .init(
            userId: 1,
            username: username,
            tag: "tester",
            identifier: "KAKAO-1",
            profileImageUrl: "",
            userRoleType: "USER",
            socialType: "KAKAO"
        )
    }

    func updateMyTag(tag: String) async throws -> UserModel {
        .init(
            userId: 1,
            username: "test",
            tag: tag,
            identifier: "KAKAO-1",
            profileImageUrl: "",
            userRoleType: "USER",
            socialType: "KAKAO"
        )
    }
}

private final class MockTokenStore: TokenStoring {
    var accessToken: String?
    var refreshToken: String?
    var hasSessionTokens: Bool

    init(hasSessionTokens: Bool) {
        self.hasSessionTokens = hasSessionTokens
        self.accessToken = hasSessionTokens ? "access" : nil
        self.refreshToken = hasSessionTokens ? "refresh" : nil
    }

    func save(accessToken: String, refreshToken: String) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        hasSessionTokens = true
    }

    func clearTokens() {
        accessToken = nil
        refreshToken = nil
        hasSessionTokens = false
    }
}

private extension UserInitSettingsResponse {
    static func make() -> UserInitSettingsResponse {
        UserInitSettingsResponse(
            app: .init(needsForceUpdate: false, needsOptionalUpdate: false),
            needsPolicyAgreement: false,
            needsTagSetup: true,
            policies: []
        )
    }
}
