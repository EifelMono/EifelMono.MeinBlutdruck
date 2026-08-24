import SwiftUI

/// Klarstellung, was diese App ist – und was sie ausdrücklich nicht ist.
enum Haftung {
    static let kurz = "Kein Medizinprodukt. Diagnostiziert, behandelt und heilt nichts."

    /// Der Kernsatz, gut sichtbar über allem anderen.
    static let kernsatz = """
    Diese App diagnostiziert, behandelt oder heilt keine Erkrankung. \
    Frage bei allem, was deine Gesundheit betrifft, immer eine Ärztin oder einen Arzt.
    """

    static let lang = """
    Diese App ist **kein Medizinprodukt** und nicht als solches geprüft oder zugelassen.

    Sie zeigt und berechnet ausschließlich Werte, die andere Geräte und Programme in die \
    Health-App geschrieben haben. Sie misst nichts selbst und prüft nicht, ob die \
    übernommenen Werte richtig sind.

    Sie stellt **keine Diagnose**, gibt **keine Behandlungsempfehlung** und ersetzt in keinem \
    Fall die Beurteilung durch eine Ärztin oder einen Arzt. Grenzwerte, Bewertungen wie \
    „erhöht" und der Ausreißerfilter sind rechnerische Hilfsmittel, keine medizinische Aussage.

    Fehler in Anzeige, Übernahme oder Berechnung lassen sich nicht ausschließen. Triff \
    **keine Entscheidung über Medikamente oder deine Behandlung** aufgrund dieser App.

    Bei starken Kopfschmerzen, Brustschmerz, Atemnot, Sehstörungen, Schwäche auf einer \
    Körperseite oder sehr hohen Werten: **sofort ärztliche Hilfe suchen, im Notfall 112.**

    Die Nutzung erfolgt auf eigene Verantwortung. Eine Haftung für Schäden, die aus der \
    Nutzung oder aus fehlerhaften Anzeigen entstehen, ist ausgeschlossen, soweit dies \
    gesetzlich zulässig ist.
    """
}

/// Der reine Inhalt – wird eingeschoben (Einstellungen) oder als Blatt gezeigt.
struct Hinweisinhalt: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Label("Bitte einmal lesen", systemImage: "exclamationmark.triangle.fill")
                    .font(.headline).foregroundStyle(Color.statusErhoeht)

                Text(Haftung.kernsatz)
                    .font(.callout.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.statusErhoeht.opacity(0.10),
                                in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.statusErhoeht.opacity(0.35)))

                Text(.init(Haftung.lang))
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)

            }
            .padding(20)
        }
    }
}

/// Als Blatt: eigene Navigationsleiste mit Kopfzeile.
struct Haftungshinweis: View {
    @Environment(\.dismiss) private var schliessen
    @AppStorage("hinweisBestaetigt") private var bestaetigt = false
    var erstmalig = false

    var body: some View {
        NavigationStack {
            Hinweisinhalt()
                .navigationBarTitleDisplayMode(.inline)
                .interactiveDismissDisabled(erstmalig)
                .toolbar {
                    ToolbarItem(placement: .principal) { Kopfzeile(unterzeile: "Wichtiger Hinweis") }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(erstmalig ? "Verstanden" : "Fertig") {
                            if erstmalig { bestaetigt = true }
                            schliessen()
                        }
                        .fontWeight(erstmalig ? .semibold : .regular)
                    }
                }
        }
    }
}
