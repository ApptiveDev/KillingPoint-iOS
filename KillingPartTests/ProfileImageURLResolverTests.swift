import Foundation
import Testing
@testable import KillingPart

struct ProfileImageURLResolverTests {
    @Test
    func resolvesSchemeRelativeURLAsHTTPS() {
        let url = resolvedProfileImageURL(from: "//cdn.example.com/profile.jpg")
        #expect(url?.absoluteString == "https://cdn.example.com/profile.jpg")
    }

    @Test
    func upgradesHTTPToHTTPS() {
        let url = resolvedProfileImageURL(from: "http://cdn.example.com/profile.jpg")
        #expect(url?.absoluteString == "https://cdn.example.com/profile.jpg")
    }

    @Test
    func encodesWhitespaceInPath() {
        let url = resolvedProfileImageURL(from: "cdn.example.com/profile image.jpg")
        #expect(url?.absoluteString == "https://cdn.example.com/profile%20image.jpg")
    }

    @Test
    func returnsNilForEmptyInput() {
        let url = resolvedProfileImageURL(from: "   ")
        #expect(url == nil)
    }
}
