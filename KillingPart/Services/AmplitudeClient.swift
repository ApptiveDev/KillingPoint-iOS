import AmplitudeUnified
import Foundation

final class AmplitudeClient {
    static let shared = AmplitudeClient()

    private var amplitude: Amplitude?
    private var isConfigured = false

    private init() {}

    func configure(apiKey: String) {
        guard !isConfigured else { return }
        guard let normalizedKey = normalizedApiKey(from: apiKey) else { return }

        // Session Replay가 CALayer에 KVO를 걸어둔 채 레이어가 해제되면 iOS 27에서 NSKVODeallocate 크래시가 발생해 비활성화
        amplitude = Amplitude(
            apiKey: normalizedKey,
            sessionReplayConfig: .init(sampleRate: 0, enableRemoteConfig: false, autoStart: false)
        )
        isConfigured = true
    }

    func track(eventType: String, properties: [String: Any]? = nil) {
        guard let amplitude else { return }

        if let properties, !properties.isEmpty {
            amplitude.track(eventType: eventType, eventProperties: properties)
            return
        }

        amplitude.track(eventType: eventType)
    }

    func setUserId(_ userId: String?) {
        guard
            let amplitude,
            let userId = userId?.trimmingCharacters(in: .whitespacesAndNewlines),
            !userId.isEmpty
        else {
            return
        }

        amplitude.setUserId(userId: userId)
    }

    private func normalizedApiKey(from rawValue: String) -> String? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else { return nil }
        guard !trimmed.hasPrefix("$(") else { return nil }
        guard !trimmed.hasPrefix("YOUR_") else { return nil }
        guard trimmed != "AMPLITUDE_API_KEY" else { return nil }
        guard trimmed != "<TEST_API_KEY>" else { return nil }

        return trimmed
    }
}
