import SwiftUI

enum AppFont {
    static func title() -> Font {
        .system(size: 28, weight: .bold, design: .rounded)
    }

    static func body() -> Font {
        .system(size: 16, weight: .regular, design: .default)
    }

    static func button() -> Font {
        .system(size: 16, weight: .semibold, design: .rounded)
    }
}
