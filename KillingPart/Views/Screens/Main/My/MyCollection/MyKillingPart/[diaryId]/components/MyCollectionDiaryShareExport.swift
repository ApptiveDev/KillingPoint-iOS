import Photos
import SwiftUI
import UIKit
import KakaoSDKShare
import KakaoSDKTemplate

struct MyCollectionDiaryActivityShareItem: Identifiable {
    let id = UUID()
    let image: UIImage
    let url: URL
}

struct MyCollectionDiaryActionAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

struct MyCollectionDiaryActivityShareSheet: UIViewControllerRepresentable {
    let item: MyCollectionDiaryActivityShareItem

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(
            activityItems: [
                MyCollectionDiaryShareURLActivityItemSource(url: item.url),
                MyCollectionDiaryShareImageActivityItemSource(image: item.image)
            ],
            applicationActivities: nil
        )
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

final class MyCollectionDiaryShareURLActivityItemSource: NSObject, UIActivityItemSource {
    private let url: URL

    init(url: URL) {
        self.url = url
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        url
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
        if activityType == .copyToPasteboard {
            return url.absoluteString
        }

        return url
    }
}

final class MyCollectionDiaryShareImageActivityItemSource: NSObject, UIActivityItemSource {
    private let image: UIImage

    init(image: UIImage) {
        self.image = image
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        image
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
        if activityType == .copyToPasteboard {
            return nil
        }

        return image
    }
}

enum MyCollectionDiaryShareExportError: LocalizedError {
    case renderFailed
    case photoAccessDenied
    case photoSaveFailed
    case pngEncodingFailed
    case shareURLUnavailable
    case instagramAppIDMissing
    case instagramUnavailable
    case kakaoTalkUnavailable
    case kakaoImageUploadFailed
    case kakaoShareFailed
    case kakaoShareOpenFailed

    var errorDescription: String? {
        switch self {
        case .renderFailed:
            return "이미지를 만들지 못했어요. 잠시 후 다시 시도해 주세요."
        case .photoAccessDenied:
            return "사진 보관함 저장 권한이 필요해요."
        case .photoSaveFailed:
            return "사진 보관함에 이미지를 저장하지 못했어요."
        case .pngEncodingFailed:
            return "공유 이미지를 PNG로 변환하지 못했어요."
        case .shareURLUnavailable:
            return "공유 링크를 만들지 못했어요."
        case .instagramAppIDMissing:
            return "Instagram Story 공유를 위해 FACEBOOK_APP_ID 설정이 필요해요."
        case .instagramUnavailable:
            return "Instagram 앱을 열 수 없어요. Instagram 설치 여부를 확인해 주세요."
        case .kakaoTalkUnavailable:
            return "카카오톡 앱 설치 여부를 확인해 주세요."
        case .kakaoImageUploadFailed:
            return "카카오톡 공유 이미지를 업로드하지 못했어요."
        case .kakaoShareFailed:
            return "카카오톡 공유 메시지를 만들지 못했어요."
        case .kakaoShareOpenFailed:
            return "카카오톡 공유 화면을 열지 못했어요."
        }
    }
}

enum MyCollectionDiaryShareImageRenderer {
    private static let canvasSize = MyCollectionDiaryShareImageLayout.canvasSize
    private static let canvasScale = MyCollectionDiaryShareImageLayout.renderScale

    @MainActor
    static func render(
        diary: DiaryFeedModel,
        displayedContent: String,
        createdDateText: String,
        tagText: String,
        startMinuteSecondText: String,
        endMinuteSecondText: String,
        startProgress: CGFloat,
        endProgress: CGFloat
    ) async throws -> UIImage {
        let artworkImage = await loadArtworkImage(from: diary.albumImageURL)
        let content = MyCollectionDiaryShareImageView(
            artworkURL: diary.albumImageURL,
            artworkImage: artworkImage,
            musicTitle: diary.musicTitle,
            artist: diary.artist,
            displayedContent: displayedContent,
            createdDateText: createdDateText,
            tagText: tagText,
            startMinuteSecondText: startMinuteSecondText,
            endMinuteSecondText: endMinuteSecondText,
            startProgress: startProgress,
            endProgress: endProgress
        )
        .frame(width: canvasSize.width, height: canvasSize.height)

        let renderer = ImageRenderer(content: content)
        renderer.proposedSize = ProposedViewSize(width: canvasSize.width, height: canvasSize.height)
        renderer.scale = canvasScale
        renderer.isOpaque = true

        guard let image = renderer.uiImage else {
            throw MyCollectionDiaryShareExportError.renderFailed
        }

        return image
    }

    private static func loadArtworkImage(from url: URL?) async -> UIImage? {
        guard let url else { return nil }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            if let httpResponse = response as? HTTPURLResponse,
               !(200..<300).contains(httpResponse.statusCode) {
                return nil
            }
            return UIImage(data: data)
        } catch {
            return nil
        }
    }
}

private enum MyCollectionDiaryShareImageLayout {
    static let renderScale: CGFloat = 3
    static let canvasSize = CGSize(width: 360, height: 640)
    static let contentTopPadding: CGFloat = 90 / renderScale
    static let contentHorizontalPadding: CGFloat = 132 / renderScale
    static let cardSpacing: CGFloat = 35 / renderScale
    static let trackCardHeight: CGFloat = 942 / renderScale
    static let trackCardCornerRadius: CGFloat = 72.52941 / renderScale
    static let trackCardBackgroundOpacity: CGFloat = 0.3
    static let trackCardShadowRadius: CGFloat = 2 / renderScale
    static let trackCardShadowY: CGFloat = 4 / renderScale
    static let commentCardHeight: CGFloat = 728.22681 / renderScale
    static let commentCardCornerRadius: CGFloat = 45.58705 / renderScale
    static let albumArtworkSize = CGSize(
        width: 428.416748046875 / renderScale,
        height: 427.9999694824219 / renderScale
    )
    static let albumArtworkCornerRadius: CGFloat = 17.23639 / renderScale
    static let musicTitleFontSize: CGFloat = 48 / renderScale
    static let artistFontSize: CGFloat = 38 / renderScale
    static let artistTextWidth: CGFloat = 377.04599 / renderScale
    static let timelineLabelFontSize: CGFloat = 32 / renderScale
    static let commentFontSize: CGFloat = 32 / renderScale
    static let commentTextSize = CGSize(
        width: 704 / renderScale,
        height: 488 / renderScale
    )
    static let commentHorizontalInset = (
        canvasSize.width - contentHorizontalPadding * 2 - commentTextSize.width
    ) / 2
    static let metadataFontSize: CGFloat = 26 / renderScale
    static let dateTextSize = CGSize(
        width: 167.01755 / renderScale,
        height: 37.4258 / renderScale
    )
    static let appIconSize = CGSize(
        width: 108.8 / renderScale,
        height: 112 / renderScale
    )
    static let appIconCornerRadius: CGFloat = 8
    static let appIconShadowRadius: CGFloat = 1.96087 / renderScale
    static let appIconShadowY: CGFloat = 3.92174 / renderScale
    static let appIconStrokeWidth: CGFloat = 1.96087 / renderScale
    static let metadataColor = Color(red: 0.48, green: 0.48, blue: 0.48)
}

enum MyCollectionDiaryPhotoSaver {
    static func save(_ image: UIImage) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw MyCollectionDiaryShareExportError.photoAccessDenied
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            } completionHandler: { isSuccess, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if isSuccess {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: MyCollectionDiaryShareExportError.photoSaveFailed)
                }
            }
        }
    }
}

@MainActor
enum MyCollectionDiaryInstagramStorySharer {
    static func share(_ image: UIImage, url: URL) throws {
        let appID = (Bundle.main.object(forInfoDictionaryKey: "FACEBOOK_APP_ID") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !appID.isEmpty, appID != "$(FACEBOOK_APP_ID)" else {
            throw MyCollectionDiaryShareExportError.instagramAppIDMissing
        }

        guard
            let urlScheme = URL(string: "instagram-stories://share?source_application=\(appID)"),
            UIApplication.shared.canOpenURL(urlScheme)
        else {
            throw MyCollectionDiaryShareExportError.instagramUnavailable
        }

        guard let pngData = image.pngData() else {
            throw MyCollectionDiaryShareExportError.pngEncodingFailed
        }

        let pasteboardItems = [
            [
                "com.instagram.sharedSticker.backgroundImage": pngData,
                "com.instagram.sharedSticker.contentURL": url.absoluteString
            ]
        ]
        let pasteboardOptions: [UIPasteboard.OptionsKey: Any] = [
            .expirationDate: Date().addingTimeInterval(60 * 5)
        ]

        UIPasteboard.general.setItems(pasteboardItems, options: pasteboardOptions)
        UIApplication.shared.open(urlScheme, options: [:], completionHandler: nil)
    }
}

struct MyCollectionDiaryKakaoSharePayload: Equatable {
    let title: String
    let description: String
    let imageURL: URL
    let imageWidth: Int
    let imageHeight: Int
    let shareURL: URL
    let kakaoExecutionParams: [String: String]

    static func make(
        diary: DiaryFeedModel,
        displayedContent: String,
        imageURL: URL,
        imageWidth: Int,
        imageHeight: Int,
        shareURL: URL,
        kakaoExecutionParams: [String: String]
    ) -> MyCollectionDiaryKakaoSharePayload {
        let trackTitle = [diary.musicTitle, diary.artist]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " - ")
        let fallbackTitle = trackTitle.isEmpty ? "킬링파트 다이어리" : trackTitle
        let trimmedContent = displayedContent.trimmingCharacters(in: .whitespacesAndNewlines)
        let description = trimmedContent.isEmpty ? "킬링파트에서 다이어리를 확인해 보세요." : trimmedContent

        return MyCollectionDiaryKakaoSharePayload(
            title: fallbackTitle,
            description: description,
            imageURL: imageURL,
            imageWidth: imageWidth,
            imageHeight: imageHeight,
            shareURL: shareURL,
            kakaoExecutionParams: kakaoExecutionParams
        )
    }

    func makeFeedTemplate() -> FeedTemplate {
        let link = Link(
            webUrl: shareURL,
            mobileWebUrl: shareURL,
            iosExecutionParams: kakaoExecutionParams
        )
        let content = Content(
            title: title,
            imageUrl: imageURL,
            imageWidth: imageWidth,
            imageHeight: imageHeight,
            description: description,
            link: link
        )
        return FeedTemplate(
            content: content,
            buttons: [
                Button(title: "킬링파트 보러가기", link: link)
            ]
        )
    }
}

@MainActor
enum MyCollectionDiaryKakaoSharer {
    static func share(
        image: UIImage,
        diary: DiaryFeedModel,
        displayedContent: String,
        diaryId: Int
    ) async throws {
        guard ShareApi.isKakaoTalkSharingAvailable() else {
            throw MyCollectionDiaryShareExportError.kakaoTalkUnavailable
        }

        guard let shareURL = DeepLinkURLBuilder.diaryURL(diaryId: diaryId) else {
            throw MyCollectionDiaryShareExportError.shareURLUnavailable
        }
        guard let kakaoExecutionParams = DeepLinkURLBuilder.kakaoDiaryExecutionParams(diaryId: diaryId) else {
            throw MyCollectionDiaryShareExportError.shareURLUnavailable
        }

        let uploadedImage = try await uploadImage(image)
        let payload = MyCollectionDiaryKakaoSharePayload.make(
            diary: diary,
            displayedContent: displayedContent,
            imageURL: uploadedImage.url,
            imageWidth: uploadedImage.width,
            imageHeight: uploadedImage.height,
            shareURL: shareURL,
            kakaoExecutionParams: kakaoExecutionParams
        )
        let kakaoShareURL = try await makeShareURL(template: payload.makeFeedTemplate())
        let didOpen = await open(kakaoShareURL)
        guard didOpen else {
            throw MyCollectionDiaryShareExportError.kakaoShareOpenFailed
        }
    }

    private static func uploadImage(_ image: UIImage) async throws -> ImageInfo {
        try await withCheckedThrowingContinuation { continuation in
            ShareApi.shared.imageUpload(image: image) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let imageInfo = result?.infos.original else {
                    continuation.resume(throwing: MyCollectionDiaryShareExportError.kakaoImageUploadFailed)
                    return
                }

                continuation.resume(returning: imageInfo)
            }
        }
    }

    private static func makeShareURL(template: FeedTemplate) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            ShareApi.shared.shareDefault(templatable: template) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let shareURL = result?.url else {
                    continuation.resume(throwing: MyCollectionDiaryShareExportError.kakaoShareFailed)
                    return
                }

                continuation.resume(returning: shareURL)
            }
        }
    }

    private static func open(_ url: URL) async -> Bool {
        await withCheckedContinuation { continuation in
            UIApplication.shared.open(url, options: [:]) { isSuccess in
                continuation.resume(returning: isSuccess)
            }
        }
    }
}

private struct MyCollectionDiaryShareImageView: View {
    let artworkURL: URL?
    let artworkImage: UIImage?
    let musicTitle: String
    let artist: String
    let displayedContent: String
    let createdDateText: String
    let tagText: String
    let startMinuteSecondText: String
    let endMinuteSecondText: String
    let startProgress: CGFloat
    let endProgress: CGFloat

    var body: some View {
        backgroundLayer
            .overlay(alignment: .top) {
                VStack(spacing: MyCollectionDiaryShareImageLayout.cardSpacing) {
                    trackCard
                        .frame(height: MyCollectionDiaryShareImageLayout.trackCardHeight)

                    commentCard
                        .frame(height: MyCollectionDiaryShareImageLayout.commentCardHeight)
                }
                .padding(.horizontal, MyCollectionDiaryShareImageLayout.contentHorizontalPadding)
                .padding(.top, MyCollectionDiaryShareImageLayout.contentTopPadding)
                .frame(
                    width: MyCollectionDiaryShareImageLayout.canvasSize.width,
                    height: MyCollectionDiaryShareImageLayout.canvasSize.height,
                    alignment: .top
                )
            }
            .frame(
                width: MyCollectionDiaryShareImageLayout.canvasSize.width,
                height: MyCollectionDiaryShareImageLayout.canvasSize.height
            )
            .clipped()
    }

    private var backgroundLayer: some View {
        Image("my_background")
            .resizable()
            .scaledToFill()
            .frame(
                width: MyCollectionDiaryShareImageLayout.canvasSize.width,
                height: MyCollectionDiaryShareImageLayout.canvasSize.height
            )
            .overlay(Color.black.opacity(0.30))
            .clipped()
    }

    private var trackCard: some View {
        ZStack {
            RoundedRectangle(
                cornerRadius: MyCollectionDiaryShareImageLayout.trackCardCornerRadius,
                style: .continuous
            )
            .fill(Color.black.opacity(0.34))
            
            

            VStack(spacing: 0) {
                AddSearchDetailAlbumArtworkView(
                    url: artworkURL,
                    preloadedImage: artworkImage,
                    coverSize: MyCollectionDiaryShareImageLayout.albumArtworkSize,
                    coverCornerRadius: MyCollectionDiaryShareImageLayout.albumArtworkCornerRadius
                )
                .frame(
                    height: MyCollectionDiaryShareImageLayout.albumArtworkSize.height,
                    alignment: .center
                )
                .padding(.top, 24)

                trackTextSection
                    .padding(.top, 16)

                MyCollectionDiaryTimelineRangeView(
                    startMinuteSecondText: startMinuteSecondText,
                    endMinuteSecondText: endMinuteSecondText,
                    startProgress: startProgress,
                    endProgress: endProgress,
                    trackHeight: 4,
                    segmentHeight: 8,
                    labelWidth: 40,
                    labelY: 24,
                    height: 38,
                    startFontSize: MyCollectionDiaryShareImageLayout.timelineLabelFontSize,
                    endFontSize: MyCollectionDiaryShareImageLayout.timelineLabelFontSize,
                    trackColor: Color.white.opacity(0.42),
                    segmentColor: AppColors.primary600,
                    startLabelColor: MyCollectionDiaryShareImageLayout.metadataColor,
                    endLabelColor: MyCollectionDiaryShareImageLayout.metadataColor,
                    usesThinLabelFont: true
                )
                .padding(.horizontal, 36)
                .padding(.top, 10)

                Spacer(minLength: 12)
            }
        }
    }

    private var trackTextSection: some View {
        VStack(spacing: 5) {
            Text(musicTitle)
                .font(AppFont.paperlogy7Bold(size: MyCollectionDiaryShareImageLayout.musicTitleFontSize))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.74)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 266)

            Text(artist)
                .font(AppFont.paperlogy4Regular(size: MyCollectionDiaryShareImageLayout.artistFontSize))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .frame(width: MyCollectionDiaryShareImageLayout.artistTextWidth, alignment: .top)
        }
        .frame(maxWidth: .infinity)
    }

    private var commentCard: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(
                cornerRadius: MyCollectionDiaryShareImageLayout.commentCardCornerRadius,
                style: .continuous
            )
            .fill(Color.kpGray700)

            Text(displayedContent.isEmpty ? "작성된 코멘트가 없어요." : displayedContent)
                .font(AppFont.paperlogy4Regular(size: MyCollectionDiaryShareImageLayout.commentFontSize))
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
                .lineSpacing(2.5)
                .frame(
                    width: MyCollectionDiaryShareImageLayout.commentTextSize.width,
                    height: MyCollectionDiaryShareImageLayout.commentTextSize.height,
                    alignment: .topLeading
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .offset(y: 24)

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(createdDateText)
                        .font(AppFont.paperlogy4Regular(size: MyCollectionDiaryShareImageLayout.metadataFontSize))
                        .foregroundStyle(MyCollectionDiaryShareImageLayout.metadataColor)
                        .frame(
                            width: MyCollectionDiaryShareImageLayout.dateTextSize.width,
                            height: MyCollectionDiaryShareImageLayout.dateTextSize.height,
                            alignment: .topLeading
                        )

                    Text(tagText)
                        .font(AppFont.paperlogy5Medium(size: MyCollectionDiaryShareImageLayout.metadataFontSize))
                        .foregroundStyle(MyCollectionDiaryShareImageLayout.metadataColor)
                }

                Spacer()

                appIcon
            }
            .padding(.horizontal, MyCollectionDiaryShareImageLayout.commentHorizontalInset)
            .padding(.bottom, 18)
        }
    }

    @ViewBuilder
    private var appIcon: some View {
        if let image = MyCollectionDiaryAppIconImageProvider.image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(
                    width: MyCollectionDiaryShareImageLayout.appIconSize.width,
                    height: MyCollectionDiaryShareImageLayout.appIconSize.height
                )
                .clipped()
                .background(Color(red: 0.81, green: 1, blue: 0.26))
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: MyCollectionDiaryShareImageLayout.appIconCornerRadius,
                        style: .continuous
                    )
                )
                .shadow(
                    color: .black.opacity(0.25),
                    radius: MyCollectionDiaryShareImageLayout.appIconShadowRadius,
                    x: 0,
                    y: MyCollectionDiaryShareImageLayout.appIconShadowY
                )
                .overlay {
                    RoundedRectangle(
                        cornerRadius: MyCollectionDiaryShareImageLayout.appIconCornerRadius,
                        style: .continuous
                    )
                        .stroke(.black, lineWidth: MyCollectionDiaryShareImageLayout.appIconStrokeWidth)
                }
        } else {
            RoundedRectangle(
                cornerRadius: MyCollectionDiaryShareImageLayout.appIconCornerRadius,
                style: .continuous
            )
                .fill(Color(red: 0.81, green: 1, blue: 0.26))
                .frame(
                    width: MyCollectionDiaryShareImageLayout.appIconSize.width,
                    height: MyCollectionDiaryShareImageLayout.appIconSize.height
                )
                .overlay {
                    Text("KP")
                        .font(AppFont.paperlogy8ExtraBold(size: 14))
                        .foregroundStyle(.black)
                }
                .shadow(
                    color: .black.opacity(0.25),
                    radius: MyCollectionDiaryShareImageLayout.appIconShadowRadius,
                    x: 0,
                    y: MyCollectionDiaryShareImageLayout.appIconShadowY
                )
                .overlay {
                    RoundedRectangle(
                        cornerRadius: MyCollectionDiaryShareImageLayout.appIconCornerRadius,
                        style: .continuous
                    )
                        .stroke(.black, lineWidth: MyCollectionDiaryShareImageLayout.appIconStrokeWidth)
                }
        }
    }
}

private enum MyCollectionDiaryAppIconImageProvider {
    static var image: UIImage? {
        if let iconFiles = primaryIconFiles,
           let iconName = iconFiles.last,
           let image = UIImage(named: iconName) {
            return image
        }

        return UIImage(named: "ic_KillingPart")
            ?? UIImage(named: "ic_alpha_KillingPart")
            ?? UIImage(named: "AppIcon")
    }

    private static var primaryIconFiles: [String]? {
        guard
            let icons = Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any],
            let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any]
        else {
            return nil
        }

        return primaryIcon["CFBundleIconFiles"] as? [String]
    }
}
