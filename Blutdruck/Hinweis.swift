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

struct Haftungshinweis: View {
    @AppStorage("hinweisBestaetigt") private var bestaetigt = false
    @Environment(\.dismiss) private var schliessen
    /// true = beim ersten Start, mit Bestätigungsknopf
    var erstmalig = false

    var body: some View {
        NavigationStack {
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
                    if erstmalig {
                        Button {
                            bestaetigt = true
                            schliessen()
                        } label: {
                            Text("Verstanden").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .padding(.top, 6)
                    }
                }
                .padding(20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) { Kopfzeile(unterzeile: "Wichtiger Hinweis") }
            }
            .interactiveDismissDisabled(erstmalig)
            .toolbar {
                if !erstmalig {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Fertig") { schliessen() }
                    }
                }
            }
        }
    }
}
