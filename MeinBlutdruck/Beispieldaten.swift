import Foundation

/// Erfundene, aber plausible Werte – für Bildschirmfotos und für die Prüfung im App Store.
/// Bewusst fest vorgegeben (kein Zufall zur Laufzeit), damit jeder Durchlauf gleich aussieht.
enum Beispieldaten {

    /// Einfacher, wiederholbarer Zahlengenerator: gleiche Bilder bei jedem Aufruf.
    private struct Streuung {
        private var zustand: UInt64
        init(_ saat: UInt64) { zustand = saat }
        mutating func naechste() -> Double {
            zustand = zustand &* 6364136223846793005 &+ 1442695040888963407
            return Double((zustand >> 33) % 10_000) / 10_000
        }
        /// annähernd glockenförmig verteilt
        mutating func streuung(_ breite: Double) -> Double {
            ((naechste() + naechste() + naechste()) / 3 - 0.5) * 2 * breite
        }
    }

    struct Satz {
        var messungen: [Messung]
        var gewicht: [Wert]
        var koerperfett: [Wert]
        var puls: [Bandwert]
    }

    /// Rund drei Monate mit morgens erhöhten, tagsüber ruhigeren Werten und leichtem Rückgang.
    static func erzeugen(tage: Int = 92, bis: Date = .now) -> Satz {
        var z = Streuung(20260824)
        let kal = Calendar.current
        var messungen: [Messung] = []
        var gewicht: [Wert] = [], fett: [Wert] = []

        // Messreihen: Uhrzeit, Ausgangswerte, wie viele Einzelmessungen
        let reihen: [(stunde: Int, minute: Int, sys: Double, dia: Double, puls: Double)] = [
            (6, 40, 148, 96, 71),
            (12, 30, 133, 86, 78),
            (18, 20, 137, 89, 75),
            (22, 10, 130, 84, 69),
        ]

        for tag in 0..<tage {
            guard let datum = kal.date(byAdding: .day, value: -(tage - 1 - tag), to: bis) else { continue }
            // langsamer Rückgang über den Zeitraum, dazu ein Wochenrhythmus
            let verlauf = -6.0 * Double(tag) / Double(tage)
            let woche = 2.0 * sin(Double(tag) / 7 * .pi)

            for reihe in reihen {
                // nicht jeden Tag jede Reihe – so wirkt es echt
                if z.naechste() < 0.18 { continue }
                let anzahl = 3 + Int(z.naechste() * 2.99)
                let grundSys = reihe.sys + verlauf + woche + z.streuung(7)
                let grundDia = reihe.dia + verlauf * 0.5 + z.streuung(5)

                for k in 0..<anzahl {
                    guard let zeit = kal.date(bySettingHour: reihe.stunde,
                                              minute: reihe.minute + k,
                                              second: 0, of: datum) else { continue }
                    // die erste Messung liegt typisch etwas höher
                    let ersteHoeher = k == 0 ? 6.0 : 0
                    messungen.append(Messung(
                        datum: zeit,
                        sys: (grundSys + ersteHoeher + z.streuung(4)).rounded(),
                        dia: (grundDia + ersteHoeher * 0.5 + z.streuung(3)).rounded(),
                        puls: (reihe.puls + z.streuung(6)).rounded()))
                }
                // gelegentlich ein Ausreißer, damit der Filter sichtbar arbeitet
                if z.naechste() < 0.12,
                   let zeit = kal.date(bySettingHour: reihe.stunde, minute: reihe.minute + anzahl,
                                       second: 0, of: datum) {
                    messungen.append(Messung(datum: zeit,
                                             sys: (grundSys + 24 + z.streuung(6)).rounded(),
                                             dia: (grundDia + 14 + z.streuung(4)).rounded(),
                                             puls: (reihe.puls + 12).rounded()))
                }
            }

            // Gewicht und Körperfett: langsam fallend mit kleinen Schwankungen
            if let morgens = kal.date(bySettingHour: 7, minute: 5, second: 0, of: datum) {
                gewicht.append(Wert(datum: morgens,
                                    wert: ((84.6 - 2.4 * Double(tag) / Double(tage)) + z.streuung(0.5) * 0.6)
                                        .rounded(toPlaces: 1)))
                fett.append(Wert(datum: morgens,
                                 wert: ((22.4 - 1.1 * Double(tag) / Double(tage)) + z.streuung(0.4) * 0.5)
                                     .rounded(toPlaces: 1)))
            }
        }

        messungen.sort { $0.datum < $1.datum }
        let gefiltert = Auswertung.filtern(messungen)

        // Puls über den Tag – dieselbe Verdichtung wie bei echten Werten
        var eimer: [Int: [Double]] = [:]
        for m in gefiltert where m.puls != nil {
            eimer[m.minuten / 15, default: []].append(m.puls!)
        }
        let band: [Bandwert] = eimer.keys.sorted().compactMap { k in
            let v = eimer[k]!.sorted()
            guard let mittel = Auswertung.mittel(v) else { return nil }
            return Bandwert(minute: Double(k * 15 + 7),
                            unten: v.first! - 4, oben: v.last! + 4, mitte: mittel)
        }

        return Satz(messungen: gefiltert, gewicht: gewicht, koerperfett: fett, puls: band)
    }
}

private extension Double {
    func rounded(toPlaces stellen: Int) -> Double {
        let faktor = pow(10.0, Double(stellen))
        return (self * faktor).rounded() / faktor
    }
}
