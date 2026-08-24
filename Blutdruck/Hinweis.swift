import SwiftUI

/// Klarstellung, was diese App ist – und was sie ausdrücklich nicht ist.
enum Haftung {
    static let kurz = "Kein Medizinprodukt. Keine Diagnose, keine Behandlungsempfehlung."

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
            .navigationTitle("Mein Blutdruck")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Image("Logo")
                        .resizable().scaledToFit().frame(width: 28, height: 28)
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .strokeBorder(.quaternary))
                        .accessibilityHidden(true)
                }
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
