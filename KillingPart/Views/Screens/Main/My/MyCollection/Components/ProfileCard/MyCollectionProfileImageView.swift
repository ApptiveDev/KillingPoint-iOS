import SwiftUI

struct MyCollectionProfileImageView: View {
    let profileImageURL: URL?
    let size: CGFloat
    let iconSize: CGFloat
    @State private var imageReloadKey = UUID()

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
            .onAppear {
                imageReloadKey = UUID()
            }
            .onChange(of: profileImageURL?.absoluteString) { _ in
                imageReloadKey = UUID()
            }
            .onReceive(NotificationCenter.default.publisher(for: .diaryCreated)) { _ in
                imageReloadKey = UUID()
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
            .id(imageReloadKey)
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
