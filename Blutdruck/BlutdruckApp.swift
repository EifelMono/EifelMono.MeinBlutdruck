import SwiftUI

@main
struct BlutdruckApp: App {
    @StateObject private var speicher = Speicher()
    @StateObject private var schutz = Schutz()
    @StateObject private var grenzen = Grenzwerte.geteilt
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            ZStack {
                Uebersicht()
                    .environmentObject(speicher)
                    .environmentObject(schutz)
                    .environmentObject(grenzen)
                    .opacity(schutz.entsperrt ? 1 : 0)

                if !schutz.entsperrt {
                    Sperrbildschirm().environmentObject(schutz)
                }
                // Beim Wechsel in die App-Übersicht nichts preisgeben
                if phase == .inactive && schutz.aktiv && schutz.entsperrt {
                    Abdeckung().transition(.opacity)
                }
            }
            // Die Oberfläche ist durchgehend deutsch – dann sollen es Datum und
            // Uhrzeit auch sein, unabhängig von der Systemsprache.
            .environment(\.locale, Locale(identifier: "de_DE"))
            .task { await schutz.pruefen() }
            .onChange(of: phase) { _, neu in
                if neu == .background { schutz.sperren() }
                if neu == .active && !schutz.entsperrt { Task { await schutz.pruefen() } }
            }
        }
    }
}
