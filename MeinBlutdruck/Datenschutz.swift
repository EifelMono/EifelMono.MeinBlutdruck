import SwiftUI

/// Datenschutzerklärung – wortgleich zur veröffentlichten Fassung im Netz,
/// damit sie auch ohne Verbindung lesbar ist.
enum Datenschutz {
    static let stand = "August 2026"
    static let adresse = "https://github.com/EifelMono/EifelMono.MeinBlutdruck/blob/main/DATENSCHUTZ.md"

    static let text = """
    **Kurz gesagt:** Diese App sammelt nichts, sendet nichts und hat keine Konten. \
    Alle Werte bleiben auf deinem iPhone.

    ### Wer verantwortlich ist

    Andreas Klapperich · eifelmono
    Dornheck 41, 56745 Rieden
    E-Mail: andreas@klapperich.de

    ### Welche Daten die App liest

    Die App liest ausschließlich aus der Health-App von Apple, und zwar nur lesend:

    - Blutdruck, systolisch und diastolisch
    - Herzfrequenz
    - Körpergewicht
    - Körperfettanteil

    Sie schreibt nichts in die Health-App zurück und ändert dort nichts.

    ### Was mit den Daten geschieht

    Die Auswertung – Mittelwerte, Messreihen, Ausreißerfilter, Diagramme – findet \
    **ausschließlich auf deinem Gerät** statt. Es gibt keinen Server, kein Benutzerkonto, \
    keine Anmeldung. Die App überträgt keine Gesundheitsdaten, weder an den Entwickler \
    noch an Dritte.

    Es findet keine Analyse des Nutzungsverhaltens statt, keine Werbung, kein Tracking, \
    keine Weitergabe zu Werbezwecken. Es werden keine Cookies oder vergleichbare Techniken \
    eingesetzt, da die App keine Internetverbindung benötigt.

    ### Was die App selbst speichert

    Auf dem Gerät gespeichert werden nur deine Einstellungen: die Grenzwerte, ob die \
    Sperre beim Öffnen aktiv ist und ob der Nutzungshinweis bestätigt wurde. Messwerte \
    speichert die App nicht – sie liest sie bei jedem Start neu aus der Health-App.

    ### Wenn du etwas weitergibst

    Zwei Funktionen geben auf deine ausdrückliche Anweisung hin Daten aus der App heraus:

    - **PDF-Bericht:** enthält deine ausgewerteten Messwerte. Wohin er geht, entscheidest \
    du im Teilen-Dialog.
    - **Diagnoseprotokoll:** enthält nur den Ablauf der Health-Abfrage, App-Version, \
    iOS-Version und Anzahlen – keine Messwerte.

    Beides passiert nur, wenn du es auslöst.

    ### Rechtsgrundlage und deine Rechte

    Da die Verarbeitung allein lokal auf deinem Gerät stattfindet und der Entwickler zu \
    keinem Zeitpunkt Kenntnis von deinen Daten erhält, werden vom Entwickler keine \
    personenbezogenen Daten im Sinne der DSGVO verarbeitet. Es liegen daher auch keine \
    Daten vor, über die Auskunft erteilt oder die gelöscht werden könnten.

    Deine Gesundheitsdaten selbst verwaltet Apple in der Health-App. Welche davon die App \
    lesen darf, bestimmst du jederzeit in der Health-App unter Profilbild → Datenschutz → \
    Apps → Mein Blutdruck. Entziehst du die Freigabe, zeigt die App keine Werte mehr.

    Löschst du die App, werden die gespeicherten Einstellungen mit entfernt. Deine \
    Gesundheitsdaten in der Health-App bleiben davon unberührt.

    ### Verwendete Software

    Die App verwendet keine Bibliotheken von Drittanbietern. Sie ist ausschließlich mit \
    Apples eigenen Rahmenwerken gebaut: SwiftUI, Swift Charts, HealthKit und \
    LocalAuthentication.

    ### Änderungen

    Ändert sich der Funktionsumfang, wird diese Erklärung angepasst. Maßgeblich ist die \
    Fassung, die zur jeweiligen App-Version gehört.
    """
}

struct Datenschutzseite: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(.init(Datenschutz.text))
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)

                Divider()

                Link(destination: URL(string: Datenschutz.adresse)!) {
                    Label("Fassung im Netz öffnen", systemImage: "safari")
                        .font(.footnote)
                }

                Text("Stand: \(Datenschutz.stand)")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            .padding(20)
        }
        .navigationTitle("Datenschutz")
        .navigationBarTitleDisplayMode(.inline)
    }
}
