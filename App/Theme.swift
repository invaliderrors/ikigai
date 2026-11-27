import AppKit
import SwiftUI

/// Projection Booth tokens from DESIGN.md. Dark appearance only for now.
enum Theme {
    static let house = Color(hex: 0x17120F)
    static let house2 = Color(hex: 0x1F1915)
    static let house3 = Color(hex: 0x2A221D)
    static let house4 = Color(hex: 0x362C25)
    static let boothBlack = Color(hex: 0x0B0908)
    static let seat = Color(hex: 0x3B1519)
    static let seat2 = Color(hex: 0x2A0F12)
    /// Fills only the one primary action per screen (the One Lamp Rule).
    static let tungsten = Color(hex: 0xF2B544)
    static let tungstenInk = Color(hex: 0x1F1406)
    /// Selection and pressed states: a tint, never a fill.
    static let tungstenTint = Color(hex: 0xF2B544, opacity: 0.16)
    static let screen = Color(hex: 0xF4EFE6)
    static let screen2 = Color(hex: 0xF4EFE6, opacity: 0.72)
    static let screen3 = Color(hex: 0xF4EFE6, opacity: 0.6)
    static let line = Color(hex: 0xF4EFE6, opacity: 0.10)
    static let line2 = Color(hex: 0xF4EFE6, opacity: 0.16)
    static let live = Color(hex: 0x4FAE7A)
    /// Lighter than the contract's #e0533d, which is only ~4.9:1 on house and fails AA on house-3.
    static let stop = Color(hex: 0xEF6A52)

    static let sidebar = LinearGradient(colors: [seat, seat2], startPoint: .top, endPoint: .bottom)
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB, red: Double(hex >> 16 & 0xFF) / 255, green: Double(hex >> 8 & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255, opacity: opacity)
    }
}

/// Big Shoulders Display ExtraBold, uppercase and tracked. Only for letter boards and screen or
/// wallpaper titles (the Marquee Rule); everything else is SF Pro.
struct Marquee: ViewModifier {
    var size: CGFloat
    var tracking: CGFloat = 0.06

    func body(content: Content) -> some View {
        content
            .font(Self.font(size))
            .textCase(.uppercase)
            .tracking(size * tracking)
    }

    static func font(_ size: CGFloat) -> Font {
        let weight = NSFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String)
        let descriptor = NSFontDescriptor(fontAttributes: [.family: "Big Shoulders Display"])
            .addingAttributes([weight: [0x7767_6874 /* 'wght' */: 800]])
        return Font(NSFont(descriptor: descriptor, size: size) ?? .systemFont(ofSize: size, weight: .heavy))
    }

    /// The font ships inside the app (SIL OFL, see Resources/Fonts/OFL.txt).
    static func registerBundledFont() {
        guard let url = Bundle.main.url(forResource: "BigShouldersDisplay-Variable", withExtension: "ttf") else { return }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }
}

extension View {
    func marquee(_ size: CGFloat, tracking: CGFloat = 0.06) -> some View {
        modifier(Marquee(size: size, tracking: tracking))
    }
}
