import SwiftUI

struct AddSearchDetailVideoCandidateSection: View {
    @ObservedObject var viewModel: AddSearchDetailViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            Text("다른 검색 결과")
                .font(AppFont.paperlogy6SemiBold(size: 16))
                .foregroundStyle(.white.opacity(0.9))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.s) {
                    ForEach(viewModel.videos) { video in
                        Button {
                            viewModel.selectVideo(video)
                        } label: {
                            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                AsyncImage(url: video.thumbnailURL) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFill()
                                    case .empty, .failure:
                                        placeholderThumbnail
                                    @unknown default:
                                        placeholderThumbnail
                                    }
                                }
                                .frame(width: 180, height: 102)
                                .clipShape(RoundedRectangle(cornerRadius: 12))

                                Text(video.title)
                                    .font(AppFont.paperlogy4Regular(size: 12))
                                    .foregroundStyle(.white.opacity(0.85))
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                    .frame(width: 180, alignment: .leading)
                            }
                            .padding(AppSpacing.xs)
                            .background(Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay {
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(
                                        video.id == viewModel.selectedVideo?.id
                                            ? AppColors.primary600
                                            : Color.white.opacity(0.08),
                                        lineWidth: 1
                                    )
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var placeholderThumbnail: some View {
        Rectangle()
            .fill(Color.white.opacity(0.12))
            .overlay {
                Image(systemName: "play.rectangle")
                    .foregroundStyle(.white.opacity(0.72))
            }
    }
}
