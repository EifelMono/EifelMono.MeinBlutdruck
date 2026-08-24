import Foundation

/// Eine einzelne Messung – oder, wenn `anzahl` > 1, der Mittelwert einer Messreihe.
struct Messung: Identifiable, Hashable {
    let id = UUID()
    var datum: Date
    var sys: Double
    var dia: Double
    var puls: Double?
    var unregelmaessig = false

    var reihe = 0            // Nummer der Messreihe
    var ausreisser = false
    var grund = ""
    var anzahl = 1           // aus wie vielen Messungen gemittelt
    var hoechster: Double? = nil   // nur bei Tageszusammenfassung
    var niedrigster: Double? = nil

    var minuten: Int {
        let t = Calendar.current.dateComponents([.hour, .minute], from: datum)
        return (t.hour ?? 0) * 60 + (t.minute ?? 0)
    }
}

enum Bewertung: String {
    case niedrig = "niedrig", normal = "normal", erhoeht = "erhöht"
    case deutlich = "deutlich erhöht", sehrHoch = "sehr hoch"

    static func fuer(sys: Double, dia: Double) -> Bewertung {
        if sys >= grenzeSys + 45 || dia >= grenzeDia + 25 { return .sehrHoch }
        if sys >= grenzeSys + 25 || dia >= grenzeDia + 15 { return .deutlich }
        if sys >= grenzeSys || dia >= grenzeDia { return .erhoeht }
        if sys < 105 || dia < 65 { return .niedrig }
        return .normal
    }
}

enum Zeitraum: Int, CaseIterable, Identifiable {
    case sieben = 7, vierzehn = 14, dreissig = 30, neunzig = 90, alle = 0
    var id: Int { rawValue }
    var titel: String { self == .alle ? "Alle" : "\(rawValue) T" }
}

enum Darstellung: String, CaseIterable, Identifiable {
    case einzeln = "Einzelmessungen"
    case mittel  = "Mittel je Reihe"
    var id: String { rawValue }
}

/// Tagesabschnitte – wie im Bericht
struct Abschnitt: Identifiable {
    let id = UUID()
    let name: String, spanne: String, von: Int, bis: Int
    static let alle = [
        Abschnitt(name: "Nachts",  spanne: "0–5",   von: 0,    bis: 300),
        Abschnitt(name: "Morgens", spanne: "5–12",  von: 300,  bis: 720),
        Abschnitt(name: "Mittags", spanne: "12–18", von: 720,  bis: 1080),
        Abschnitt(name: "Abends",  spanne: "18–24", von: 1080, bis: 1440),
    ]
}

struct AbschnittsWert: Identifiable {
    let id = UUID()
    let name: String, spanne: String
    let anzahl: Int
    let sys: Double, dia: Double
    let puls: Double?
    let ueberGrenze: Int
    var stunde: Int? = nil
}

enum Aufteilung: String, CaseIterable, Identifiable {
    case abschnitte = "Tagesabschnitte"
    case stuendlich = "Stündlich"
    var id: String { rawValue }
}


/// Ein einzelner Messwert aus Health (Gewicht, Körperfett …)
struct Wert: Identifiable, Hashable {
    let id = UUID()
    var datum: Date
    var wert: Double
}

extension Array where Element == Wert {
    var neuester: Wert? { self.max(by: { $0.datum < $1.datum }) }
    /// Veränderung vom ersten zum letzten Wert der Reihe.
    var veraenderung: Double? {
        guard let a = self.min(by: { $0.datum < $1.datum }),
              let b = neuester, a.id != b.id else { return nil }
        return b.wert - a.wert
    }
}


enum Listenmodus: String, CaseIterable, Identifiable {
    case einzeln = "Einzeln"
    case reihen  = "Messreihen"
    case tage    = "Tage"
    var id: String { rawValue }
}
