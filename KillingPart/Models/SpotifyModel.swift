import Foundation

struct SpotifyTokenResponse: Decodable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
    }
}

struct SpotifySearchResponse: Decodable {
    let tracks: SpotifyTracks
}

struct SpotifyTracks: Decodable {
    let items: [SpotifyTrackItem]
}

struct SpotifyTrackItem: Decodable {
    let id: String
    let name: String
    let artists: [SpotifyArtist]
    let album: SpotifyAlbum
}

struct SpotifyArtist: Decodable {
    let name: String
}

struct SpotifyAlbum: Decodable {
    let id: String
    let images: [SpotifyAlbumImage]
}

struct SpotifyAlbumImage: Decodable {
    let url: String
    let width: Int?
    let height: Int?
}

struct SpotifySimpleTrack: Identifiable {
    let id: String
    let title: String
    let artist: String
    let albumImageUrl: String?
    let albumId: String

    var albumImageURL: URL? {
        guard let albumImageUrl else { return nil }
        return URL(string: albumImageUrl)
    }
}
