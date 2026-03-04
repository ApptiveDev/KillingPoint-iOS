import SwiftUI

struct MusicCalendarDiaryRow: View {
    let diary: DiaryFeedModel

    var body: some View {
        HStack(spacing: AppSpacing.m) {
            albumArtwork(for: diary)

            VStack(alignment: .leading, spacing: 5) {
                Text(diary.musicTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "제목 없음" : diary.musicTitle)
                    .font(AppFont.paperlogy6SemiBold(size: 14))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)

                Text(diary.artist.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "아티스트 정보 없음" : diary.artist)
                    .font(AppFont.paperlogy5Medium(size: 12))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            VStack(spacing: 4) {
                Text("코멘트읽기")
                    .font(AppFont.paperlogy5Medium(size: 14))
                    .foregroundStyle(Color.kpPrimary)

                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.kpPrimary)
            }
        }
        .padding(.horizontal, AppSpacing.m)
        .padding(.vertical, AppSpacing.m)
        .frame(minHeight: 82)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func albumArtwork(for diary: DiaryFeedModel) -> some View {
        Group {
            if let albumURL = diary.albumImageURL {
                AsyncImage(url: albumURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .empty, .failure:
                        placeholderArtwork
                    @unknown default:
                        placeholderArtwork
                    }
                }
            } else {
                placeholderArtwork
            }
        }
        .frame(width: 58, height: 58)
    }

    private var placeholderArtwork: some View {
        Rectangle()
            .fill(Color.white.opacity(0.12))
            .overlay {
                Image(systemName: "music.note")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.82))
            }
    }
}
