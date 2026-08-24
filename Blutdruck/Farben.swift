import SwiftUI

// Reihen-Farben und Status-Farben sind streng getrennt:
// Eine Farbe, die eine Messgröße kennzeichnet, darf nie zugleich eine Bewertung bedeuten.
// Deshalb kein Orange, Rot oder Grün für die Messreihen.

extension Color {
    init(hell: UInt32, dunkel: UInt32) {
        self.init(uiColor: UIColor { zug in
            let wert = zug.userInterfaceStyle == .dark ? dunkel : hell
            return UIColor(red: CGFloat((wert >> 16) & 0xFF) / 255,
                           green: CGFloat((wert >> 8) & 0xFF) / 255,
                           blue: CGFloat(wert & 0xFF) / 255, alpha: 1)
        })
    }

    // Messgrößen
    static let sysFarbe     = Color(hell: 0x2A78D6, dunkel: 0x3987E5)   // Blau
    static let diaFarbe     = Color(hell: 0x4A3AA7, dunkel: 0x9085E9)   // Violett
    static let pulsFarbe    = Color(hell: 0x0E8EA8, dunkel: 0x35A9C4)   // Petrol
    static let gewichtFarbe = Color(hell: 0x1BAF7A, dunkel: 0x2ECC96)   // Aqua
    static let fettFarbe    = Color(hell: 0x5F6570, dunkel: 0xA8ADB6)   // Graphit, bewusst neutral

    // Bewertungen – ausschließlich für Text und kleine Zeichen
    static let statusGut      = Color(hell: 0x0A7D0A, dunkel: 0x0CA30C)
    static let statusErhoeht  = Color(hell: 0xC2551F, dunkel: 0xEC835A)
    static let statusKritisch = Color(hell: 0xC0322F, dunkel: 0xE66767)
}

extension Bewertung {
    var farbe: Color {
        switch self {
        case .sehrHoch, .deutlich: return .statusKritisch
        case .erhoeht:             return .statusErhoeht
        case .niedrig:             return .secondary
        case .normal:              return .statusGut
        }
    }
    var zeichen: String {
        switch self {
        case .sehrHoch, .deutlich: return "exclamationmark.triangle.fill"
        case .erhoeht:             return "arrow.up.right"
        case .niedrig:             return "arrow.down.right"
        case .normal:              return "checkmark.circle.fill"
        }
    }
}
