import Foundation

struct MainStartupPayload {
    let playCollectionViewModel: MyCollectionViewModel
}

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
    @Published private(set) var isSplashReadyToFinish = false
    @Published private(set) var mainStartupPayload: MainStartupPayload?
    @Published private(set) var activeDeepLinkRequest: DeepLinkRequest?

    let loginViewModel: LoginViewModel

    private let authenticationService: AuthenticationServicing
    private let tokenStore: TokenStoring
    private let userService: UserServicing
    private let diaryService: DiaryServicing
    private let calendarService: CalendarServicing
    private let subscribeService: SubscribeServicing
    private let notificationCenter: NotificationCenter
    private let appStoreURL: URL?
    private var sessionExpiredObserver: NSObjectProtocol?
    private var splashPreparationTask: Task<Void, Never>?
    private var preparedPostSplashStep: AppFlowStep?
    private var pendingDeepLinkRequest: DeepLinkRequest?

    init(
        authenticationService: AuthenticationServicing = AuthenticationService(),
        authService: AuthServicing = AuthService(),
        userService: UserServicing = UserService(),
        diaryService: DiaryServicing = DiaryService(),
        calendarService: CalendarServicing = CalendarService(),
        subscribeService: SubscribeServicing = SubscribeService(),
        tokenStore: TokenStoring = TokenStore.shared,
        notificationCenter: NotificationCenter = .default
    ) {
        self.authenticationService = authenticationService
        self.tokenStore = tokenStore
        self.userService = userService
        self.diaryService = diaryService
        self.calendarService = calendarService
        self.subscribeService = subscribeService
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
                self?.resetSession(preservePendingDeepLink: self?.pendingDeepLinkRequest != nil)
            }
        }
    }

    deinit {
        splashPreparationTask?.cancel()
        if let sessionExpiredObserver {
            notificationCenter.removeObserver(sessionExpiredObserver)
        }
    }

    func prepareSplashIfNeeded() {
        guard currentStep == .splash else { return }
        guard !isSplashReadyToFinish else { return }
        guard splashPreparationTask == nil else { return }

        splashPreparationTask = Task { @MainActor [weak self] in
            await self?.prepareSplash()
        }
    }

    func completeSplash() {
        guard let preparedPostSplashStep else {
            prepareSplashIfNeeded()
            return
        }

        currentStep = preparedPostSplashStep
        if case .main = preparedPostSplashStep {
            schedulePushPermissionRequest()
        }
        self.preparedPostSplashStep = nil
    }

    func resolvePostLoginFlow() async {
        await resolvePostLoginFlow(
            deferStepUntilSplash: false,
            shouldPreloadMain: false
        )
    }

    func handleDeepLink(_ url: URL) -> Bool {
        guard let route = DeepLinkRoute(url: url) else {
            return false
        }

        pendingDeepLinkRequest = DeepLinkRequest(route: route)
        activeDeepLinkRequest = nil

        if currentStep == .splash {
            prepareSplashIfNeeded()
            return true
        }

        guard tokenStore.hasSessionTokens else {
            currentStep = .login
            return true
        }

        Task { @MainActor [weak self] in
            await self?.resolvePostLoginFlow()
        }
        return true
    }

    func consumeDeepLinkRequest(_ request: DeepLinkRequest) {
        guard activeDeepLinkRequest == request else { return }
        activeDeepLinkRequest = nil
    }

    private func prepareSplash() async {
        defer { splashPreparationTask = nil }

        guard tokenStore.hasSessionTokens else {
            preparedPostSplashStep = .login
            setupFlowViewModel = nil
            mainStartupPayload = nil
            isSplashReadyToFinish = true
            return
        }

        await resolvePostLoginFlow(
            deferStepUntilSplash: true,
            shouldPreloadMain: true
        )

        if preparedPostSplashStep == nil {
            preparedPostSplashStep = .login
        }
        isSplashReadyToFinish = true
    }

    private func resolvePostLoginFlow(
        deferStepUntilSplash: Bool,
        shouldPreloadMain: Bool
    ) async {
        guard !isResolvingPostLoginFlow else { return }

        isResolvingPostLoginFlow = true
        loginViewModel.loginErrorMessage = nil
        defer { isResolvingPostLoginFlow = false }

        do {
            let settings = try await userService.fetchInitSettings()
            let shouldSkipNameSetupForAppleLogin = await resolveShouldSkipNameSetupForAppleLogin(with: settings)
            await applyRoute(
                for: settings,
                shouldSkipNameSetupForAppleLogin: shouldSkipNameSetupForAppleLogin,
                deferStepUntilSplash: deferStepUntilSplash,
                shouldPreloadMain: shouldPreloadMain
            )

            if settings.app.needsForceUpdate {
                updatePrompt = .force
            } else if settings.app.needsOptionalUpdate {
                updatePrompt = .optional
            }
        } catch {
            if isRequestCancelled(error) { return }
            if deferStepUntilSplash {
                preparedPostSplashStep = .login
            } else {
                currentStep = .login
            }
            setupFlowViewModel = nil
            mainStartupPayload = nil
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
        resetSession(preservePendingDeepLink: false)
    }

    private func resetSession(preservePendingDeepLink: Bool) {
        splashPreparationTask?.cancel()
        splashPreparationTask = nil
        preparedPostSplashStep = nil
        isSplashReadyToFinish = false
        loginViewModel.resetState()
        setupFlowViewModel = nil
        mainStartupPayload = nil
        activeDeepLinkRequest = nil
        if !preservePendingDeepLink {
            pendingDeepLinkRequest = nil
        }
        updatePrompt = nil
        currentStep = .login
    }

    private func applyRoute(
        for settings: UserInitSettingsResponse,
        shouldSkipNameSetupForAppleLogin: Bool,
        deferStepUntilSplash: Bool,
        shouldPreloadMain: Bool
    ) async {
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
            mainStartupPayload = nil
            if deferStepUntilSplash {
                preparedPostSplashStep = .setup
            } else {
                currentStep = .setup
            }
            return
        }

        let startupPayload = shouldPreloadMain ? await makeMainStartupPayload() : nil
        enterMainFlow(
            startupPayload: startupPayload,
            deferStepUntilSplash: deferStepUntilSplash
        )
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

    private func enterMainFlow(
        startupPayload: MainStartupPayload? = nil,
        deferStepUntilSplash: Bool = false
    ) {
        setupFlowViewModel = nil
        mainStartupPayload = startupPayload

        if deferStepUntilSplash {
            preparedPostSplashStep = .main
        } else {
            currentStep = .main
            schedulePushPermissionRequest()
        }
        activatePendingDeepLinkRouteIfNeeded()
    }

    private func activatePendingDeepLinkRouteIfNeeded() {
        guard let pendingDeepLinkRequest else { return }
        activeDeepLinkRequest = pendingDeepLinkRequest
        self.pendingDeepLinkRequest = nil
    }

    private func makeMainStartupPayload() async -> MainStartupPayload {
        let playCollectionViewModel = MyCollectionViewModel(
            authenticationService: authenticationService,
            userService: userService,
            diaryService: diaryService,
            subscribeService: subscribeService
        )
        await playCollectionViewModel.preloadPlaybackFeeds()
        return MainStartupPayload(playCollectionViewModel: playCollectionViewModel)
    }

    private func schedulePushPermissionRequest() {
        DispatchQueue.main.async {
            PushNotificationPermissionManager.handleAuthorizationAfterEnteringMain()
        }
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
