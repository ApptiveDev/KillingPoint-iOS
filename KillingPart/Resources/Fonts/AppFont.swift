import SwiftUI
import CoreText

enum AppFont {
    private static let paperlogyFontNames = [
        "Paperlogy-1Thin",
        "Paperlogy-2ExtraLight",
        "Paperlogy-3Light",
        "Paperlogy-4Regular",
        "Paperlogy-5Medium",
        "Paperlogy-6SemiBold",
        "Paperlogy-7Bold",
        "Paperlogy-8ExtraBold",
        "Paperlogy-9Black"
    ]

    static func registerPaperlogyFonts() {
        for fontName in paperlogyFontNames {
            guard let fontURL = Bundle.main.url(forResource: fontName, withExtension: "ttf") else {
                continue
            }

            CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, nil)
        }
    }

    static func paperlogy1Thin(size: CGFloat) -> Font {
        .custom("Paperlogy-1Thin", size: size)
    }

    static func paperlogy2ExtraLight(size: CGFloat) -> Font {
        .custom("Paperlogy-2ExtraLight", size: size)
    }

    static func paperlogy3Light(size: CGFloat) -> Font {
        .custom("Paperlogy-3Light", size: size)
    }

    static func paperlogy4Regular(size: CGFloat) -> Font {
        .custom("Paperlogy-4Regular", size: size)
    }

    static func paperlogy5Medium(size: CGFloat) -> Font {
        .custom("Paperlogy-5Medium", size: size)
    }

    static func paperlogy6SemiBold(size: CGFloat) -> Font {
        .custom("Paperlogy-6SemiBold", size: size)
    }

    static func paperlogy7Bold(size: CGFloat) -> Font {
        .custom("Paperlogy-7Bold", size: size)
    }

    static func paperlogy8ExtraBold(size: CGFloat) -> Font {
        .custom("Paperlogy-8ExtraBold", size: size)
    }

    static func paperlogy9Black(size: CGFloat) -> Font {
        .custom("Paperlogy-9Black", size: size)
    }
}
