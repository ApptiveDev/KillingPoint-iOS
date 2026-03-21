import Foundation

struct ITunesSearchResponse: Decodable {
    let resultCount: Int
    let results: [ITunesTrackItem]
}

struct ITunesTrackItem: Decodable {
    let trackId: Int?
    let trackName: String?
    let artistName: String?
    let artworkUrl100: String?
    let collectionId: Int?
}
