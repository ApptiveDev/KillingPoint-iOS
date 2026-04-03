import SwiftUI

struct SocialFriendProfileImageView: View {
    let profileImageURL: URL?
    @State private var imageReloadKey = UUID()

    var body: some View {
        Group {
            if let profileImageURL {
                AsyncImage(url: profileImageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .empty, .failure:
                        profilePlaceholder
                    @unknown default:
                        profilePlaceholder
                    }
                }
                .id(imageReloadKey)
            } else {
                profilePlaceholder
            }
        }
        .frame(width: 40, height: 40)
        .clipShape(Circle())
        .onAppear {
            imageReloadKey = UUID()
        }
        .onChange(of: profileImageURL?.absoluteString) { _ in
            imageReloadKey = UUID()
        }
    }

    private var profilePlaceholder: some View {
        Circle()
            .fill(Color.white.opacity(0.16))
            .overlay {
                Image(systemName: "person.fill")
                    .foregroundStyle(Color.white.opacity(0.7))
            }
    }
}
