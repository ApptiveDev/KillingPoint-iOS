import Photos
import SwiftUI
import UIKit

struct MyCollectionDiaryActivityShareItem: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct MyCollectionDiaryActionAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

struct MyCollectionDiaryActivityShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

enum MyCollectionDiaryShareExportError: LocalizedError {
    case renderFailed
    case photoAccessDenied
    case photoSaveFailed
    case pngEncodingFailed
    case instagramAppIDMissing
    case instagramUnavailable

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
        case .instagramAppIDMissing:
            return "Instagram Story 공유를 위해 FACEBOOK_APP_ID 설정이 필요해요."
        case .instagramUnavailable:
            return "Instagram 앱을 열 수 없어요. Instagram 설치 여부를 확인해 주세요."
        }
    }
}

enum MyCollectionDiaryShareImageRenderer {
    private static let canvasSize = CGSize(width: 360, height: 640)
    private static let canvasScale: CGFloat = 3

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
    static func share(_ image: UIImage) throws {
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
            ["com.instagram.sharedSticker.backgroundImage": pngData]
        ]
        let pasteboardOptions: [UIPasteboard.OptionsKey: Any] = [
            .expirationDate: Date().addingTimeInterval(60 * 5)
        ]

        UIPasteboard.general.setItems(pasteboardItems, options: pasteboardOptions)
        UIApplication.shared.open(urlScheme, options: [:], completionHandler: nil)
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
        ZStack {
            Image("my_background")
                .resizable()
                .scaledToFill()
                .frame(width: 360, height: 640)
                .clipped()

            Color.black.opacity(0.42)

            VStack(spacing: 0) {
                AddSearchDetailAlbumArtworkView(
                    url: artworkURL,
                    preloadedImage: artworkImage,
                    coverSize: 188
                )
                .frame(width: 278, height: 188, alignment: .center)
                .padding(.top, 54)

                trackTextSection
                    .padding(.top, 18)

                MyCollectionDiaryTimelineRangeView(
                    startMinuteSecondText: startMinuteSecondText,
                    endMinuteSecondText: endMinuteSecondText,
                    startProgress: startProgress,
                    endProgress: endProgress,
                    trackHeight: 3,
                    segmentHeight: 7,
                    labelWidth: 44,
                    labelY: 27,
                    height: 44,
                    startFontSize: 12,
                    endFontSize: 12,
                    trackColor: Color.white.opacity(0.46),
                    segmentColor: AppColors.primary600,
                    startLabelColor: Color.white.opacity(0.68),
                    endLabelColor: Color.white.opacity(0.68)
                )
                .padding(.horizontal, 34)
                .padding(.top, 12)

                Spacer(minLength: 18)

                commentCard
                    .frame(height: 238)
                    .padding(.horizontal, 21)
                    .padding(.bottom, 34)
            }
        }
        .frame(width: 360, height: 640)
        .clipped()
    }

    private var trackTextSection: some View {
        VStack(spacing: 7) {
            Text(musicTitle)
                .font(AppFont.paperlogy7Bold(size: 24))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.78)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 306)

            Text(artist)
                .font(AppFont.paperlogy4Regular(size: 18))
                .foregroundStyle(.white.opacity(0.82))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .frame(maxWidth: 306)
        }
        .frame(maxWidth: .infinity)
    }

    private var commentCard: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Color.white.opacity(0.10))
                .overlay {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                }

            Text(displayedContent.isEmpty ? "작성된 코멘트가 없어요." : displayedContent)
                .font(AppFont.paperlogy4Regular(size: 15))
                .foregroundStyle(.white.opacity(0.92))
                .multilineTextAlignment(.leading)
                .lineSpacing(4)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.horizontal, 24)
                .padding(.top, 26)
                .padding(.bottom, 82)

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(createdDateText)
                        .font(AppFont.paperlogy4Regular(size: 12))
                        .foregroundStyle(.white.opacity(0.52))

                    Text(tagText)
                        .font(AppFont.paperlogy5Medium(size: 13))
                        .foregroundStyle(.white.opacity(0.70))
                }

                Spacer()

                appIcon
            }
            .padding(.leading, 24)
            .padding(.trailing, 18)
            .padding(.bottom, 18)
        }
    }

    @ViewBuilder
    private var appIcon: some View {
        if let image = MyCollectionDiaryAppIconImageProvider.image {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: 54, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppColors.primary600)
                .frame(width: 54, height: 54)
                .overlay {
                    Text("KP")
                        .font(AppFont.paperlogy8ExtraBold(size: 22))
                        .foregroundStyle(.black)
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
