import SwiftUI

/// Global gültige Grenzwerte, damit Bewertung, Diagramme und Kennzahlen dasselbe zugrunde legen.
nonisolated(unsafe) var grenzeSys: Double = UserDefaults.standard.object(forKey: "grenzeSys") as? Double ?? 135
nonisolated(unsafe) var grenzeDia: Double = UserDefaults.standard.object(forKey: "grenzeDia") as? Double ?? 85

@MainActor
final class Grenzwerte: ObservableObject {
    static let geteilt = Grenzwerte()

    @Published var sys: Double {
        didSet { grenzeSys = sys; UserDefaults.standard.set(sys, forKey: "grenzeSys") }
    }
    @Published var dia: Double {
        didSet { grenzeDia = dia; UserDefaults.standard.set(dia, forKey: "grenzeDia") }
    }

    private init() {
        sys = grenzeSys
        dia = grenzeDia
    }

    var text: String { "\(Int(sys))/\(Int(dia))" }

    /// Gebräuchliche Bezugswerte. Welcher gilt, entscheidet die behandelnde Praxis.
    struct Vorschlag: Identifiable {
        let id = UUID()
        let name: String, sys: Double, dia: Double, erklaerung: String
    }
    static let vorschlaege: [Vorschlag] = [
        .init(name: "Selbstmessung zu Hause", sys: 135, dia: 85,
              erklaerung: "Üblicher Bezugswert für zu Hause gemessene Werte. Zu Hause wird meist etwas niedriger gemessen als in der Praxis."),
        .init(name: "Messung in der Praxis", sys: 140, dia: 90,
              erklaerung: "Ab diesem Wert spricht man bei Messungen in der Praxis von Bluthochdruck."),
        .init(name: "Strengeres Ziel", sys: 130, dia: 80,
              erklaerung: "Wird häufig angestrebt, etwa bei Diabetes, Nierenerkrankung oder nach einem Herzereignis – nur nach ärztlicher Absprache."),
    ]
}
