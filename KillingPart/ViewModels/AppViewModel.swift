import Foundation

@MainActor
final class AppViewModel: ObservableObject {
    enum UpdatePrompt: Identifiable, Equatable {
        case force
        case optional

        var id: String {
            switch self {
            case .force:
                return "force"
            case .optional:
                return "optional"
            }
        }

        var title: String {
            switch self {
            case .force:
                return "업데이트 필요"
            case .optional:
                return "업데이트 권장"
            }
        }

        var message: String {
            switch self {
            case .force:
                return "안정적인 서비스 이용을 위해 최신 버전으로 업데이트해 주세요."
            case .optional:
                return "새 버전이 출시되었어요. 지금 업데이트하면 더 나은 경험을 이용할 수 있어요."
            }
        }
    }

    @Published var currentStep: AppFlowStep = .splash
    @Published var updatePrompt: UpdatePrompt?
    @Published var setupFlowViewModel: InitialSetupFlowViewModel?
    @Published var isResolvingPostLoginFlow = false

    let loginViewModel: LoginViewModel

    private let tokenStore: TokenStoring
    private let userService: UserServicing
    private let diaryService: DiaryServicing
    private let calendarService: CalendarServicing
    private let notificationCenter: NotificationCenter
    private let appStoreURL: URL?
    private var sessionExpiredObserver: NSObjectProtocol?

    init(
        authenticationService: AuthenticationServicing = AuthenticationService(),
        authService: AuthServicing = AuthService(),
        userService: UserServicing = UserService(),
        diaryService: DiaryServicing = DiaryService(),
        calendarService: CalendarServicing = CalendarService(),
        tokenStore: TokenStoring = TokenStore.shared,
        notificationCenter: NotificationCenter = .default
    ) {
        self.tokenStore = tokenStore
        self.userService = userService
        self.diaryService = diaryService
        self.calendarService = calendarService
        self.notificationCenter = notificationCenter
        self.appStoreURL = Self.resolveAppStoreURL()

        let loginViewModel = LoginViewModel(
            authenticationService: authenticationService,
            authService: authService
        )

        self.loginViewModel = loginViewModel
        self.loginViewModel.onLoginSuccess = { [weak self] _ in
            Task { @MainActor [weak self] in
                FCMManager.shared.registerPendingTokenIfNeeded()
                await self?.resolvePostLoginFlow()
            }
        }

        sessionExpiredObserver = notificationCenter.addObserver(
            forName: .authenticationSessionExpired,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.logout()
            }
        }
    }

    deinit {
        if let sessionExpiredObserver {
            notificationCenter.removeObserver(sessionExpiredObserver)
        }
    }

    func completeSplash() {
        guard tokenStore.hasSessionTokens else {
            currentStep = .login
            return
        }

        Task {
            await resolvePostLoginFlow()
        }
    }

    func resolvePostLoginFlow() async {
        guard !isResolvingPostLoginFlow else { return }

        isResolvingPostLoginFlow = true
        loginViewModel.loginErrorMessage = nil
        defer { isResolvingPostLoginFlow = false }

        do {
            let settings = try await userService.fetchInitSettings()
            let shouldSkipNameSetupForAppleLogin = await resolveShouldSkipNameSetupForAppleLogin(with: settings)
            applyRoute(
                for: settings,
                shouldSkipNameSetupForAppleLogin: shouldSkipNameSetupForAppleLogin
            )

            if settings.app.needsForceUpdate {
                updatePrompt = .force
            } else if settings.app.needsOptionalUpdate {
                updatePrompt = .optional
            }
        } catch {
            if isRequestCancelled(error) { return }
            currentStep = .login
            setupFlowViewModel = nil
            loginViewModel.loginErrorMessage = resolveErrorMessage(from: error)
        }
    }

    func openAppStoreURLForUpdate() -> URL? {
        appStoreURL
    }

    func dismissOptionalUpdatePrompt() {
        guard updatePrompt == .optional else { return }
        updatePrompt = nil
    }

    func logout() {
        loginViewModel.resetState()
        setupFlowViewModel = nil
        updatePrompt = nil
        currentStep = .login
    }

    private func applyRoute(
        for settings: UserInitSettingsResponse,
        shouldSkipNameSetupForAppleLogin: Bool
    ) {
        if settings.needsPolicyAgreement || settings.needsTagSetup {
            let setupViewModel = InitialSetupFlowViewModel(
                settings: settings,
                shouldSkipNameSetupForAppleLogin: shouldSkipNameSetupForAppleLogin,
                userService: userService,
                diaryService: diaryService,
                calendarService: calendarService
            )
            setupViewModel.onComplete = { [weak self] in
                self?.enterMainFlow()
            }
            setupFlowViewModel = setupViewModel
            currentStep = .setup
            return
        }

        enterMainFlow()
    }

    private func resolveShouldSkipNameSetupForAppleLogin(with settings: UserInitSettingsResponse) async -> Bool {
        guard settings.needsPolicyAgreement || settings.needsTagSetup else {
            return false
        }

        if let provider = loginViewModel.lastSuccessfulLoginProvider {
            switch provider {
            case .apple:
                return true
            case .kakao, .google, .tester:
                return false
            }
        }

        do {
            let user = try await userService.fetchMyUser()
            return isAppleSocialType(user.socialType)
        } catch {
            return false
        }
    }

    private func isAppleSocialType(_ rawSocialType: String) -> Bool {
        rawSocialType
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased() == "APPLE"
    }

    private func enterMainFlow() {
        setupFlowViewModel = nil
        currentStep = .main
    }

    private func resolveErrorMessage(from error: Error) -> String {
        if let userServiceError = error as? UserServiceError {
            return userServiceError.errorDescription ?? "초기 설정 정보를 불러오지 못했어요."
        }

        if let apiError = error as? APIClientError {
            return apiError.errorDescription ?? "초기 설정 정보를 불러오지 못했어요."
        }

        if let localizedError = error as? LocalizedError {
            return localizedError.errorDescription ?? "초기 설정 정보를 불러오지 못했어요."
        }

        return "초기 설정 정보를 불러오지 못했어요."
    }

    private func isRequestCancelled(_ error: Error) -> Bool {
        if error is CancellationError { return true }

        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
    }

    private static func resolveAppStoreURL() -> URL? {
        guard
            let rawValue = Bundle.main.object(forInfoDictionaryKey: "APP_STORE_URL") as? String
        else {
            return nil
        }

        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let url = URL(string: trimmed) else {
            return nil
        }

        return url
    }
}
