import SwiftUI

struct AddSearchDetailAlbumArtworkView: View {
    let url: URL?
    @State private var isRotating = false

    private let coverSize: CGFloat = 124
    private var fixedLayoutDiskSize: CGFloat { coverSize }
    private var diskSize: CGFloat { coverSize * 0.9 }
    private var centerLabelSize: CGFloat { diskSize * 0.34 }
    private var grooveCount: Int { 9 }
    private var grooveBaseInset: CGFloat { diskSize * 0.08 }
    private var grooveStepInset: CGFloat { diskSize * 0.04 }
    private var centerImageInset: CGFloat { centerLabelSize * 0.12 }
    private var centerHoleSize: CGFloat { max(diskSize * 0.05, 4) }

    var body: some View {
        ZStack(alignment: .leading) {
            disk
                .frame(width: diskSize, height: diskSize)
                .rotationEffect(.degrees(isRotating ? 360 : 0))
                .animation(.linear(duration: 3.6).repeatForever(autoreverses: false), value: isRotating)
                .onAppear {
                    isRotating = true
                }
                .offset(x: coverSize * 0.55)
                .zIndex(0)

            albumCover
                .frame(width: coverSize, height: coverSize)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    }
                .zIndex(2)
        }
        .frame(width: coverSize + fixedLayoutDiskSize * 0.48, height: coverSize, alignment: .leading)
        
    }

    private var albumCover: some View {
        Group {
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .empty, .failure:
                        coverPlaceholder
                    @unknown default:
                        coverPlaceholder
                    }
                }
            } else {
                coverPlaceholder
            }
        }
    }

    private var disk: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.18),
                            Color.black.opacity(0.95),
                            Color.white.opacity(0.06),
                            Color.black.opacity(0.98)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            ForEach(0..<grooveCount, id: \.self) { index in
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: max(diskSize * 0.006, 0.8))
                    .padding(grooveBaseInset + CGFloat(index) * grooveStepInset)
            }

            Circle()
                .stroke(Color.white.opacity(0.26), lineWidth: max(diskSize * 0.008, 1))

            centerLabel
        }
    }

    private var coverPlaceholder: some View {
        Rectangle()
            .fill(Color.white.opacity(0.18))
            .overlay {
                Image(systemName: "music.note")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
            }
    }

    private var centerLabel: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.86))

            Group {
                if let url {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        case .empty, .failure:
                            centerPlaceholder
                        @unknown default:
                            centerPlaceholder
                        }
                    }
                } else {
                    centerPlaceholder
                }
            }
            .clipShape(Circle())
            .padding(centerImageInset)

            Circle()
                .fill(Color.black.opacity(0.9))
                .frame(width: centerHoleSize, height: centerHoleSize)
        }
        .frame(width: centerLabelSize, height: centerLabelSize)
    }

    private var centerPlaceholder: some View {
        Circle()
            .fill(Color.white.opacity(0.2))
            .overlay {
                Image(systemName: "music.note")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.9))
            }
    }
}
