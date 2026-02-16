import SwiftUI

struct MyCollectionFeedAlbumImageView: View {
    let url: URL?

    var body: some View {
        Group {
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .empty, .failure:
                        albumImagePlaceholder
                    @unknown default:
                        albumImagePlaceholder
                    }
                }
            } else {
                albumImagePlaceholder
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
}
