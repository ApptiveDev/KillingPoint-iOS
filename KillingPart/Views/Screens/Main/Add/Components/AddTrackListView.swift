import SwiftUI

struct AddTrackListView: View {
    let tracks: [SpotifySimpleTrack]
    let isLoadingMore: Bool
    let onTrackAppear: (SpotifySimpleTrack.ID) -> Void
    let onDiarySaved: () -> Void

    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppSpacing.s) {
                ForEach(tracks) { track in
                    NavigationLink {
                        AddSearchDetailView(
                            track: track,
                            onSaved: onDiarySaved
                        )
                    } label: {
                        AddTrackRowView(track: track)
                    }
                    .buttonStyle(.plain)
                    .onAppear {
                        onTrackAppear(track.id)
                    }
                }

                if isLoadingMore {
                    HStack {
                        Spacer()
                        ProgressView()
                            .tint(.white.opacity(0.85))
                        Spacer()
                    }
                    .padding(.top, AppSpacing.s)
                }
            }
            .padding(.top, AppSpacing.xs)
            .padding(.bottom, AppSpacing.l)
        }
        .scrollDismissesKeyboard(.immediately)
        .scrollIndicators(.hidden)
    }
}

private struct AddTrackRowView: View {
    let track: SpotifySimpleTrack

    var body: some View {
        HStack(spacing: AppSpacing.s) {
            AddTrackArtworkView(url: track.albumImageURL)

            VStack(alignment: .leading, spacing: 4) {
                Text(track.title)
                    .font(AppFont.paperlogy6SemiBold(size: 15))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(track.artist)
                    .font(AppFont.paperlogy4Regular(size: 13))
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(AppSpacing.s)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
    }
}

private struct AddTrackArtworkView: View {
    let url: URL?

    var body: some View {
        Group {
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .empty, .failure:
                        placeholder
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var placeholder: some View {
        Rectangle()
            .fill(Color.white.opacity(0.12))
            .overlay {
                Image(systemName: "music.note")
                    .foregroundStyle(.white.opacity(0.72))
            }
    }
}
