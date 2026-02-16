import SwiftUI

struct MyCollectionProfileImageView: View {
    let profileImageURL: URL?
    let size: CGFloat
    let iconSize: CGFloat

    var body: some View {
        Circle()
            .fill(Color.kpPrimary)
            .frame(width: size, height: size)
            .overlay {
                profileImageContent
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            }
            .overlay {
                Circle()
                    .stroke(Color.kpPrimary, lineWidth: 2)
            }
    }

    @ViewBuilder
    private var profileImageContent: some View {
        if let profileImageURL {
            AsyncImage(url: profileImageURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .empty, .failure:
                    profileImagePlaceholder
                @unknown default:
                    profileImagePlaceholder
                }
            }
        } else {
            profileImagePlaceholder
        }
    }

    private var profileImagePlaceholder: some View {
        Image(systemName: "person.fill")
            .font(.system(size: iconSize))
            .foregroundStyle(.black)
    }
}
