import Foundation

/// Dieselbe Rechnung wie in bericht.py: Messreihen bilden, Ausreißer robust erkennen,
/// wahlweise je Reihe mitteln, gleitende Mittelwerte für die Kurven.
enum Auswertung {

    static var fensterMinuten = 15.0
    static var toleranz = 10.0

    // MARK: Grundrechnung

    static func median(_ werte: [Double]) -> Double {
        guard !werte.isEmpty else { return .nan }
        let s = werte.sorted()
        return s.count % 2 == 1 ? s[s.count / 2] : (s[s.count / 2 - 1] + s[s.count / 2]) / 2
    }

    static func mittel(_ werte: [Double]) -> Double? {
        werte.isEmpty ? nil : werte.reduce(0, +) / Double(werte.count)
    }

    // MARK: Messreihen und Ausreißer

    static func reihenBilden(_ messungen: [Messung]) -> [[Messung]] {
        var gruppen: [[Messung]] = []
        for m in messungen.sorted(by: { $0.datum < $1.datum }) {
            if var letzte = gruppen.last, let vorige = letzte.last,
               m.datum.timeIntervalSince(vorige.datum) <= fensterMinuten * 60 {
                letzte.append(m); gruppen[gruppen.count - 1] = letzte
            } else {
                gruppen.append([m])
            }
        }
        return gruppen
    }

    static func filtern(_ messungen: [Messung]) -> [Messung] {
        var ergebnis: [Messung] = []
        for (i, gruppe) in reihenBilden(messungen).enumerated() {
            var g = gruppe.map { m -> Messung in
                var m = m; m.reihe = i + 1; m.ausreisser = false; m.grund = ""; return m
            }
            if g.count >= 3 {
                let mS = median(g.map(\.sys)), mD = median(g.map(\.dia))
                let limS = max(toleranz, 3 * median(g.map { abs($0.sys - mS) }) * 1.4826)
                let limD = max(toleranz, 3 * median(g.map { abs($0.dia - mD) }) * 1.4826)
                for k in g.indices {
                    let dS = abs(g[k].sys - mS), dD = abs(g[k].dia - mD)
                    if dS > limS || dD > limD {
                        g[k].ausreisser = true
                        let vz = { (w: Double, m: Double) in w > m ? "+" : "−" }
                        g[k].grund = dS > limS && dD > limD ? "Sys+Dia weit vom Median"
                            : dS > limS ? "Sys \(vz(g[k].sys, mS))\(Int(dS.rounded())) vom Median"
                                        : "Dia \(vz(g[k].dia, mD))\(Int(dD.rounded())) vom Median"
                    }
                }
                if g.allSatisfy(\.ausreisser) {
                    for k in g.indices { g[k].ausreisser = false; g[k].grund = "" }
                }
            }
            ergebnis.append(contentsOf: g)
        }
        return ergebnis
    }

    /// Fasst jede Messreihe zu einem Mittelwert zusammen.
    static func mitteln(_ messungen: [Messung]) -> [Messung] {
        var punkte: [Messung] = []
        for gruppe in reihenBilden(messungen) {
            let gueltig = gruppe.filter { !$0.ausreisser }
            guard !gueltig.isEmpty else { continue }
            let pulse = gueltig.compactMap(\.puls)
            var m = gueltig[gueltig.count / 2]
            m.sys = (mittel(gueltig.map(\.sys)) ?? 0).rounded()
            m.dia = (mittel(gueltig.map(\.dia)) ?? 0).rounded()
            m.puls = pulse.isEmpty ? nil : (mittel(pulse) ?? 0).rounded()
            m.puls = m.puls.map { $0.rounded() }
            m.unregelmaessig = gueltig.contains(where: \.unregelmaessig)
            m.anzahl = gueltig.count
            m.ausreisser = false
            punkte.append(m)
        }
        return punkte
    }

    /// Ein Eintrag je Tag – Mittelwert aus allen gültigen Messungen des Tages.
    static func proTag(_ messungen: [Messung]) -> [Messung] {
        let kal = Calendar.current
        let gruppen = Dictionary(grouping: messungen.filter { !$0.ausreisser }) {
            kal.startOfDay(for: $0.datum)
        }
        return gruppen.keys.sorted().map { tag in
            let teil = gruppen[tag]!
            let pulse = teil.compactMap(\.puls)
            var m = teil[teil.count / 2]
            m.datum = tag
            m.sys = (mittel(teil.map(\.sys)) ?? 0).rounded()
            m.dia = (mittel(teil.map(\.dia)) ?? 0).rounded()
            m.puls = pulse.isEmpty ? nil : (mittel(pulse) ?? 0).rounded()
            m.anzahl = teil.count
            m.hoechster = teil.map(\.sys).max() ?? m.sys
            m.niedrigster = teil.map(\.sys).min() ?? m.sys
            return m
        }
    }

    // MARK: Zeitraum

    /// Frei gewählter Abschnitt – von Tagesbeginn bis Tagesende.
    static func imZeitraum(_ messungen: [Messung], von: Date, bis: Date) -> [Messung] {
        let kal = Calendar.current
        let start = kal.startOfDay(for: min(von, bis))
        let ende = kal.date(byAdding: .day, value: 1, to: kal.startOfDay(for: max(von, bis))) ?? max(von, bis)
        return messungen.filter { $0.datum >= start && $0.datum < ende }
    }

    static func imZeitraum(_ messungen: [Messung], _ zeitraum: Zeitraum) -> [Messung] {
        guard zeitraum != .alle, let letzte = messungen.map(\.datum).max() else { return messungen }
        let kal = Calendar.current
        let start = kal.startOfDay(for: kal.date(byAdding: .day, value: -(zeitraum.rawValue - 1), to: letzte)!)
        return messungen.filter { $0.datum >= start }
    }

    // MARK: Tagesabschnitte

    static func abschnitte(_ messungen: [Messung]) -> [AbschnittsWert] {
        Abschnitt.alle.compactMap { a in
            let teil = messungen.filter { $0.minuten >= a.von && $0.minuten < a.bis }
            guard !teil.isEmpty else { return nil }
            return AbschnittsWert(
                name: a.name, spanne: a.spanne, anzahl: teil.count,
                sys: mittel(teil.map(\.sys)) ?? 0, dia: mittel(teil.map(\.dia)) ?? 0,
                puls: mittel(teil.compactMap(\.puls)),
                ueberGrenze: teil.filter { $0.sys >= grenzeSys || $0.dia >= grenzeDia }.count)
        }
    }

    /// Mittelwerte je Stunde – für die stündliche Ansicht der Tagesabschnitte.
    static func stunden(_ messungen: [Messung]) -> [AbschnittsWert] {
        (0..<24).compactMap { stunde in
            let teil = messungen.filter { $0.minuten / 60 == stunde }
            guard !teil.isEmpty else { return nil }
            return AbschnittsWert(
                name: String(format: "%02d", stunde), spanne: "\(stunde)–\(stunde + 1) Uhr",
                anzahl: teil.count,
                sys: mittel(teil.map(\.sys)) ?? 0, dia: mittel(teil.map(\.dia)) ?? 0,
                puls: mittel(teil.compactMap(\.puls)),
                ueberGrenze: teil.filter { $0.sys >= grenzeSys || $0.dia >= grenzeDia }.count,
                stunde: stunde)
        }
    }

    // MARK: Gleitender Mittelwert (Gauß-Kern) für die Kurven

    struct Kurvenpunkt: Identifiable { let id = UUID(); let x: Double; let wert: Double }

    static func kurve(_ punkte: [(x: Double, y: Double)], von: Double, bis: Double,
                      breite: Double, schritte: Int = 90) -> [[Kurvenpunkt]] {
        var abschnitte: [[Kurvenpunkt]] = []
        var lauf: [Kurvenpunkt] = []
        for i in 0...schritte {
            let x = von + (bis - von) * Double(i) / Double(schritte)
            var gewicht = 0.0, summe = 0.0, nah = false
            for p in punkte {
                let d = abs(p.x - x)
                if d < breite * 1.4 { nah = true }
                let w = exp(-0.5 * pow(d / breite, 2))
                gewicht += w; summe += w * p.y
            }
            if nah && gewicht > 0.25 {
                lauf.append(Kurvenpunkt(x: x, wert: summe / gewicht))
            } else if !lauf.isEmpty {
                abschnitte.append(lauf); lauf = []
            }
        }
        if !lauf.isEmpty { abschnitte.append(lauf) }
        return abschnitte.filter { $0.count > 1 }
    }
}
