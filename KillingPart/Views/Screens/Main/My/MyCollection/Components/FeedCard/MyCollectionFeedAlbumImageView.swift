import SwiftUI

struct MyCollectionFeedAlbumImageView: View {
    let url: URL?
    @State private var retryCount = 0
    private let maxRetryCount = 3

    var body: some View {
        Group {
            if let requestURL = requestURL {
                AsyncImage(url: requestURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .empty:
                        albumImageLoading
                    case .failure:
                        albumImagePlaceholder
                            .task(id: retryCount) {
                                await scheduleRetryIfNeeded()
                            }
                    @unknown default:
                        albumImagePlaceholder
                    }
                }
            } else {
                albumImagePlaceholder
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onChange(of: url?.absoluteString) { _ in
            retryCount = 0
        }
    }

    private var requestURL: URL? {
        guard let url else { return nil }
        guard retryCount > 0 else { return url }

        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        var queryItems = components?.queryItems ?? []
        queryItems.removeAll { $0.name == "kp_retry" }
        queryItems.append(URLQueryItem(name: "kp_retry", value: String(retryCount)))
        components?.queryItems = queryItems
        return components?.url ?? url
    }

    @MainActor
    private func scheduleRetryIfNeeded() async {
        guard retryCount < maxRetryCount else { return }
        let nextRetry = retryCount + 1
        let delayNanos = UInt64(nextRetry) * 600_000_000

        try? await Task.sleep(nanoseconds: delayNanos)
        guard !Task.isCancelled else { return }
        retryCount = nextRetry
    }

    private var albumImagePlaceholder: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .overlay {
                Image(systemName: "music.note")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Color.kpGray300)
            }
    }

    private var albumImageLoading: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .overlay {
                ProgressView()
                    .tint(.white.opacity(0.85))
            }
    }
}
