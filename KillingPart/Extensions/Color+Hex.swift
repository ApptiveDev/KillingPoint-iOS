import SwiftUI

extension Color {
    init(hex: String) {
        let cleanedHex = hex.replacingOccurrences(of: "#", with: "")
        guard cleanedHex.count == 6, let value = Int(cleanedHex, radix: 16) else {
            self = .clear
            return
        }

        let red = Double((value >> 16) & 0xFF) / 255.0
        let green = Double((value >> 8) & 0xFF) / 255.0
        let blue = Double(value & 0xFF) / 255.0

        self = Color(red: red, green: green, blue: blue)
    }
}
