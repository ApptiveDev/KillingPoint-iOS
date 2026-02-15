import Foundation

struct UserModel: Decodable {
    let userId: Int
    let username: String
    let tag: String
    let identifier: String
    let profileImageUrl: String
    let userRoleType: String
    let socialType: String

    var profileImageURL: URL? {
        URL(string: profileImageUrl)
    }
}
