import SwiftUI
import Charts

// MARK: - Farben (dieselben wie im Bericht)

extension Color {
    static let sysFarbe = Color(red: 0.165, green: 0.471, blue: 0.839)
    static let diaFarbe = Color(red: 0.922, green: 0.408, blue: 0.204)
    static let pulsFarbe = Color(red: 0.106, green: 0.686, blue: 0.478)
}

extension Bewertung {
    var farbe: Color {
        switch self {
        case .sehrHoch, .deutlich: return Color(red: 0.816, green: 0.231, blue: 0.231)
        case .erhoeht: return .diaFarbe
        case .niedrig: return .secondary
        case .normal: return Color(red: 0.047, green: 0.639, blue: 0.047)
        }
    }
}

// MARK: - Hauptansicht

struct Uebersicht: View {
    @EnvironmentObject var speicher: Speicher
    @State private var zeitraum: Zeitraum = .vierzehn
    @State private var darstellung: Darstellung = .einzeln
    @State private var zeigeAusreisser = true
    @State private var eigenerZeitraum = false
    @State private var von = Calendar.current.date(byAdding: .day, value: -13, to: .now) ?? .now
    @State private var bis = Date.now
    @State private var gewaehlt: Messung?

    private var gefiltert: [Messung] {
        eigenerZeitraum ? Auswertung.imZeitraum(speicher.messungen, von: von, bis: bis)
                        : Auswertung.imZeitraum(speicher.messungen, zeitraum)
    }
    private var zeitfenster: ClosedRange<Date> {
        let alle = speicher.messungen.map(\.datum)
        guard let a = alle.min(), let b = alle.max() else { return Date.distantPast...Date.now }
        return a...max(b, a)
    }
    private var gueltig: [Messung] { gefiltert.filter { !$0.ausreisser } }
    private var punkte: [Messung] { darstellung == .mittel ? Auswertung.mitteln(gefiltert) : gueltig }
    private var ausreisser: [Messung] { gefiltert.filter(\.ausreisser) }

    /// Schneidet Gewichts- und Körperfettreihen auf denselben Zeitraum zu.
    private func werteImZeitraum(_ werte: [Wert]) -> [Wert] {
        guard let a = gefiltert.map(\.datum).min(), let b = gefiltert.map(\.datum).max() else { return [] }
        let kal = Calendar.current
        let start = kal.startOfDay(for: a)
        let ende = kal.date(byAdding: .day, value: 1, to: kal.startOfDay(for: b)) ?? b
        return werte.filter { $0.datum >= start && $0.datum < ende }.sorted { $0.datum < $1.datum }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if speicher.messungen.isEmpty {
                        Leerzustand()
                    } else {
                        Steuerung(zeitraum: $zeitraum, darstellung: $darstellung,
                                  zeigeAusreisser: $zeigeAusreisser,
                                  eigenerZeitraum: $eigenerZeitraum, von: $von, bis: $bis,
                                  fenster: zeitfenster)
                        Kacheln(punkte: punkte, alle: gefiltert, ausreisser: ausreisser.count,
                                gemittelt: darstellung == .mittel)
                        Tagesprofil(punkte: punkte, ausreisser: zeigeAusreisser ? ausreisser : [],
                                    gewaehlt: $gewaehlt)
                        Tagesabschnitte(werte: Auswertung.abschnitte(punkte))
                        Verlauf(punkte: punkte)
                        Koerperwerte(gewicht: werteImZeitraum(speicher.gewicht),
                                     fett: werteImZeitraum(speicher.koerperfett))
                        Messliste(punkte: punkte.reversed(), gemittelt: darstellung == .mittel)
                        Fusszeile()
                    }
                }
                .padding(16)
            }
            .navigationTitle("Blutdruck")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await speicher.laden() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel("Aus Health aktualisieren")
                }
            }
            .overlay { if speicher.laedt { ProgressView().controlSize(.large) } }
            .task { await speicher.laden() }
        }
    }
}

// MARK: - Bausteine

struct Leerzustand: View {
    @EnvironmentObject var speicher: Speicher
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "heart.text.square").font(.system(size: 46)).foregroundStyle(.secondary)
            Text("Noch keine Messwerte").font(.title3.bold())
            Text(speicher.meldung.isEmpty
                 ? "Die App wertet den Blutdruck aus der Health-App aus."
                 : speicher.meldung)
                .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)

            // Was Health zurückgegeben hat – hilft, ein Problem einzugrenzen.
            VStack(spacing: 2) {
                Text("Aus Health gelesen").font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary).textCase(.uppercase)
                Text("systolisch \(speicher.gelesen.sys) · diastolisch \(speicher.gelesen.dia) · Puls \(speicher.gelesen.puls)")
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                if speicher.gelesen.sys == 0 {
                    Text("Null bedeutet: kein Lesezugriff oder keine Werte vorhanden.\nHealth-App → Profilbild → Apps und Dienste → Blutdruck")
                        .font(.caption2).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(10)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 10))
            Button("Erneut aus Health laden") { Task { await speicher.laden() } }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 40)
    }
}

struct Steuerung: View {
    @Binding var zeitraum: Zeitraum
    @Binding var darstellung: Darstellung
    @Binding var zeigeAusreisser: Bool
    @Binding var eigenerZeitraum: Bool
    @Binding var von: Date
    @Binding var bis: Date
    let fenster: ClosedRange<Date>

    var body: some View {
        VStack(spacing: 10) {
            Picker("Zeitraum", selection: $zeitraum) {
                ForEach(Zeitraum.allCases) { Text($0.titel).tag($0) }
            }
            .pickerStyle(.segmented)
            .disabled(eigenerZeitraum)
            .opacity(eigenerZeitraum ? 0.4 : 1)

            Toggle("Eigener Zeitraum", isOn: $eigenerZeitraum.animation())
                .font(.footnote).tint(.sysFarbe)
            if eigenerZeitraum {
                HStack {
                    DatePicker("von", selection: $von, in: fenster, displayedComponents: .date)
                        .labelsHidden()
                    Text("bis").font(.footnote).foregroundStyle(.secondary)
                    DatePicker("bis", selection: $bis, in: fenster, displayedComponents: .date)
                        .labelsHidden()
                    Spacer()
                }
            }
            Picker("Darstellung", selection: $darstellung) {
                ForEach(Darstellung.allCases) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.segmented)
            Toggle("Ausgefilterte Messungen zeigen", isOn: $zeigeAusreisser)
                .font(.footnote).tint(.sysFarbe)
        }
    }
}

struct Kachel: View {
    let titel: String, wert: String, einheit: String, hinweis: String
    var farbe: Color = .primary
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(titel).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                .textCase(.uppercase)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(wert).font(.title.weight(.semibold)).foregroundStyle(farbe)
                Text(einheit).font(.caption).foregroundStyle(.secondary)
            }
            Text(hinweis).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct Kacheln: View {
    let punkte: [Messung], alle: [Messung], ausreisser: Int, gemittelt: Bool
    var body: some View {
        let sys = Auswertung.mittel(punkte.map(\.sys)) ?? 0
        let dia = Auswertung.mittel(punkte.map(\.dia)) ?? 0
        let puls = Auswertung.mittel(punkte.compactMap(\.puls))
        let ueber = punkte.filter { $0.sys >= 135 || $0.dia >= 85 }.count
        let bewertung = Bewertung.fuer(sys: sys, dia: dia)
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            Kachel(titel: "Ø Blutdruck", wert: "\(Int(sys.rounded()))/\(Int(dia.rounded()))",
                   einheit: "mmHg", hinweis: bewertung.rawValue, farbe: bewertung.farbe)
            Kachel(titel: "Ø Puls", wert: puls.map { "\(Int($0.rounded()))" } ?? "–",
                   einheit: "bpm", hinweis: gemittelt ? "Mittel je Reihe" : "gefiltert")
            Kachel(titel: "Über 135/85",
                   wert: punkte.isEmpty ? "–" : "\(Int((Double(ueber) / Double(punkte.count) * 100).rounded()))",
                   einheit: "%", hinweis: "\(ueber) von \(punkte.count)")
            Kachel(titel: "Messreihen", wert: "\(Set(alle.map(\.reihe)).count)",
                   einheit: "", hinweis: "\(ausreisser) Ausreißer entfernt")
        }
    }
}

struct Karte<Inhalt: View>: View {
    let titel: String, unterzeile: String
    @ViewBuilder var inhalt: Inhalt
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(titel).font(.headline)
            Text(unterzeile).font(.caption).foregroundStyle(.secondary)
            inhalt
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
    }
}

/// Sinnvoller Bereich für die senkrechte Achse – wie im Bericht: eng um die Werte.
func achsenBereich(_ werte: [Double], schritt: Double = 20) -> ClosedRange<Double> {
    guard let lo = werte.min(), let hi = werte.max() else { return 60...180 }
    let luft = (hi - lo) * 0.06 + 2
    return (((lo - luft) / schritt).rounded(.down) * schritt)...(((hi + luft) / schritt).rounded(.up) * schritt)
}

// MARK: - Tagesverlauf über 24 Stunden

struct KurvenStueck: Identifiable {
    let id = UUID(); let serie: String; let x: Double; let y: Double; let farbe: Color
}

struct Tagesprofil: View {
    let punkte: [Messung]
    let ausreisser: [Messung]
    @Binding var gewaehlt: Messung?

    private var kurven: [KurvenStueck] {
        var alle: [KurvenStueck] = []
        for (name, wert, farbe) in [("sys", \Messung.sys, Color.sysFarbe), ("dia", \Messung.dia, Color.diaFarbe)] {
            let roh = punkte.map { (x: Double($0.minuten), y: $0[keyPath: wert]) }
            for (i, stueck) in Auswertung.kurve(roh, von: 0, bis: 1440, breite: 70).enumerated() {
                alle += stueck.map { KurvenStueck(serie: "\(name)\(i)", x: $0.x, y: $0.wert, farbe: farbe) }
            }
        }
        return alle
    }

    var body: some View {
        Karte(titel: "Tagesverlauf über 24 Stunden",
              unterzeile: "Alle Messtage übereinandergelegt · Linie = gleitender Mittelwert") {
            Chart {
                ForEach([135.0, 85.0], id: \.self) { g in
                    RuleMark(y: .value("Grenzwert", g))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                        .foregroundStyle(.secondary.opacity(0.5))
                }
                ForEach([300.0, 720.0, 1080.0], id: \.self) { t in
                    RuleMark(x: .value("Abschnitt", t))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        .foregroundStyle(.secondary.opacity(0.3))
                }
                ForEach(kurven) { k in
                    LineMark(x: .value("Uhrzeit", k.x), y: .value("mmHg", k.y), series: .value("Kurve", k.serie))
                        .foregroundStyle(k.farbe)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                }
                ForEach(ausreisser) { m in
                    PointMark(x: .value("Uhrzeit", Double(m.minuten)), y: .value("mmHg", m.sys))
                        .foregroundStyle(.secondary.opacity(0.55)).symbolSize(26).symbol(.circle)
                    PointMark(x: .value("Uhrzeit", Double(m.minuten)), y: .value("mmHg", m.dia))
                        .foregroundStyle(.secondary.opacity(0.55)).symbolSize(26).symbol(.circle)
                }
                ForEach(punkte) { m in
                    PointMark(x: .value("Uhrzeit", Double(m.minuten)), y: .value("mmHg", m.sys))
                        .foregroundStyle(Color.sysFarbe).symbolSize(45)
                    PointMark(x: .value("Uhrzeit", Double(m.minuten)), y: .value("mmHg", m.dia))
                        .foregroundStyle(Color.diaFarbe).symbolSize(45)
                }
                if let g = gewaehlt {
                    RuleMark(x: .value("Uhrzeit", Double(g.minuten)))
                        .foregroundStyle(.secondary.opacity(0.7)).lineStyle(StrokeStyle(lineWidth: 1))
                }
            }
            .chartXScale(domain: 0...1440)
            .chartYScale(domain: achsenBereich(
                (punkte + ausreisser).flatMap { [$0.sys, $0.dia] } + [135, 85]))
            .chartXAxis {
                AxisMarks(values: [0.0, 360, 720, 1080, 1440]) { wert in
                    AxisGridLine()
                    AxisValueLabel { if let m = wert.as(Double.self) { Text("\(Int(m / 60))") } }
                }
            }
            .chartLegend(.hidden)
            .frame(height: 240)
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .onTapGesture { ort in
                            guard let rahmen = proxy.plotFrame else { return }
                            let x = ort.x - geo[rahmen].origin.x
                            let y = ort.y - geo[rahmen].origin.y
                            guard let minute: Double = proxy.value(atX: x),
                                  let wert: Double = proxy.value(atY: y) else { return }
                            gewaehlt = naechster(minute: minute, wert: wert)
                        }
                }
            }

            if let g = gewaehlt {
                Detailkarte(messung: g)
            } else {
                Text("Einen Messpunkt antippen zeigt die Einzelheiten.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func naechster(minute: Double, wert: Double) -> Messung? {
        (punkte + ausreisser).min { a, b in abstand(a, minute, wert) < abstand(b, minute, wert) }
    }

    private func abstand(_ m: Messung, _ minute: Double, _ wert: Double) -> Double {
        let dx = (Double(m.minuten) - minute) / 1440
        let dySys = (m.sys - wert) / 120, dyDia = (m.dia - wert) / 120
        return dx * dx + min(dySys * dySys, dyDia * dyDia)
    }
}

struct Detailkarte: View {
    let messung: Messung
    var body: some View {
        let b = Bewertung.fuer(sys: messung.sys, dia: messung.dia)
        VStack(alignment: .leading, spacing: 4) {
            Text(messung.datum.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute()))
                .font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Beschriftet(farbe: .sysFarbe, name: "Sys", wert: "\(Int(messung.sys))")
                Beschriftet(farbe: .diaFarbe, name: "Dia", wert: "\(Int(messung.dia))")
                if let p = messung.puls { Beschriftet(farbe: .pulsFarbe, name: "Puls", wert: "\(Int(p))") }
            }
            HStack(spacing: 6) {
                Text(b.rawValue).font(.caption.bold()).foregroundStyle(b.farbe)
                if messung.anzahl > 1 {
                    Text("· Ø aus \(messung.anzahl) Messungen").font(.caption).foregroundStyle(.secondary)
                }
                if messung.ausreisser {
                    Text("· ✕ \(messung.grund)").font(.caption).foregroundStyle(.red)
                }
                if messung.unregelmaessig {
                    Text("· ⚠ unregelmäßig").font(.caption).foregroundStyle(.red)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 10))
    }
}

struct Beschriftet: View {
    let farbe: Color, name: String, wert: String
    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(farbe).frame(width: 8, height: 8)
            Text(name).font(.caption).foregroundStyle(.secondary)
            Text(wert).font(.subheadline.bold())
        }
    }
}

// MARK: - Tagesabschnitte

struct Tagesabschnitte: View {
    let werte: [AbschnittsWert]
    var body: some View {
        Karte(titel: "Tagesabschnitte im Vergleich",
              unterzeile: "Morgens 5–12 · Mittags 12–18 · Abends 18–24 Uhr") {
            Chart {
                ForEach([135.0, 85.0], id: \.self) { g in
                    RuleMark(y: .value("Grenzwert", g))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                        .foregroundStyle(.secondary.opacity(0.5))
                }
                ForEach(werte) { w in
                    RuleMark(x: .value("Abschnitt", w.name),
                             yStart: .value("Dia", w.dia), yEnd: .value("Sys", w.sys))
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                        .foregroundStyle(.secondary.opacity(0.45))
                    PointMark(x: .value("Abschnitt", w.name), y: .value("Sys", w.sys))
                        .foregroundStyle(Color.sysFarbe).symbolSize(150)
                        .annotation(position: .top, spacing: 3) {
                            Text("\(Int(w.sys.rounded()))").font(.caption2.bold())
                        }
                    PointMark(x: .value("Abschnitt", w.name), y: .value("Dia", w.dia))
                        .foregroundStyle(Color.diaFarbe).symbolSize(150)
                        .annotation(position: .bottom, spacing: 3) {
                            Text("\(Int(w.dia.rounded()))").font(.caption2.bold())
                        }
                }
            }
            .chartYScale(domain: achsenBereich(
                werte.flatMap { [$0.sys, $0.dia] } + [135, 85], schritt: 10))
            .chartLegend(.hidden)
            .frame(height: 210)

            VStack(spacing: 6) {
                ForEach(werte) { w in
                    HStack {
                        Text(w.name).font(.subheadline.weight(.medium))
                        Text(w.spanne).font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Text("\(w.anzahl)").font(.caption).foregroundStyle(.secondary).frame(width: 34)
                        Text("\(Int(w.sys.rounded()))/\(Int(w.dia.rounded()))")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(Bewertung.fuer(sys: w.sys, dia: w.dia).farbe)
                            .frame(width: 66, alignment: .trailing)
                        Text("\(Int((Double(w.ueberGrenze) / Double(w.anzahl) * 100).rounded())) %")
                            .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                            .frame(width: 46, alignment: .trailing)
                    }
                }
            }
        }
    }
}

// MARK: - Verlauf über alle Tage

struct Verlauf: View {
    let punkte: [Messung]
    var body: some View {
        Karte(titel: "Verlauf über alle Tage", unterzeile: "Chronologisch, ein Punkt je Messung") {
            Chart {
                ForEach([135.0, 85.0], id: \.self) { g in
                    RuleMark(y: .value("Grenzwert", g))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                        .foregroundStyle(.secondary.opacity(0.5))
                }
                ForEach(punkte) { m in
                    PointMark(x: .value("Tag", m.datum), y: .value("mmHg", m.sys))
                        .foregroundStyle(Color.sysFarbe).symbolSize(35)
                    PointMark(x: .value("Tag", m.datum), y: .value("mmHg", m.dia))
                        .foregroundStyle(Color.diaFarbe).symbolSize(35)
                }
            }
            .chartYScale(domain: achsenBereich(punkte.flatMap { [$0.sys, $0.dia] } + [135, 85]))
            .chartLegend(.hidden)
            .frame(height: 200)
        }
    }
}

// MARK: - Liste

struct Messliste: View {
    let punkte: [Messung]
    let gemittelt: Bool
    @State private var offen = false
    var body: some View {
        Karte(titel: gemittelt ? "Messreihen" : "Alle Messwerte",
              unterzeile: "\(punkte.count) Einträge") {
            DisclosureGroup(isExpanded: $offen) {
                VStack(spacing: 0) {
                    ForEach(punkte.prefix(offen ? 400 : 0)) { m in
                        HStack {
                            Text(m.datum.formatted(.dateTime.day().month(.abbreviated)))
                                .font(.caption).frame(width: 62, alignment: .leading)
                            Text(m.datum.formatted(.dateTime.hour().minute()))
                                .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                            Spacer()
                            if gemittelt {
                                Text("Ø \(m.anzahl)").font(.caption2).foregroundStyle(.secondary)
                            }
                            Text("\(Int(m.sys))/\(Int(m.dia))")
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(Bewertung.fuer(sys: m.sys, dia: m.dia).farbe)
                                .frame(width: 66, alignment: .trailing)
                            Text(m.puls.map { "\(Int($0))" } ?? "–")
                                .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                                .frame(width: 30, alignment: .trailing)
                        }
                        .padding(.vertical, 5)
                        Divider()
                    }
                }
            } label: {
                Text(offen ? "Einklappen" : "Anzeigen").font(.subheadline)
            }
        }
    }
}

// MARK: - Gewicht und Körperfett

struct Koerperwerte: View {
    let gewicht: [Wert]
    let fett: [Wert]

    var body: some View {
        if gewicht.isEmpty && fett.isEmpty {
            EmptyView()
        } else {
            Karte(titel: "Gewicht und Körperfett",
                  unterzeile: "Aus der Health-App, im gewählten Zeitraum") {
                HStack(spacing: 10) {
                    Kennzahl(titel: "Gewicht", reihe: gewicht, einheit: "kg", nachkomma: 1, farbe: .sysFarbe)
                    Kennzahl(titel: "Körperfett", reihe: fett, einheit: "%", nachkomma: 1, farbe: .diaFarbe)
                }
                if gewicht.count > 1 {
                    Reihe(werte: gewicht, farbe: .sysFarbe, einheit: "kg")
                }
                if fett.count > 1 {
                    Reihe(werte: fett, farbe: .diaFarbe, einheit: "%")
                }
            }
        }
    }
}

private struct Kennzahl: View {
    let titel: String
    let reihe: [Wert]
    let einheit: String
    let nachkomma: Int
    let farbe: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(titel).font(.caption2.weight(.semibold)).foregroundStyle(.secondary).textCase(.uppercase)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(reihe.neuester.map { format($0.wert) } ?? "–")
                    .font(.title2.weight(.semibold))
                Text(einheit).font(.caption).foregroundStyle(.secondary)
            }
            if let d = reihe.veraenderung, abs(d) >= 0.05 {
                Text("\(d > 0 ? "+" : "−")\(format(abs(d))) \(einheit) im Zeitraum")
                    .font(.caption2).foregroundStyle(.secondary)
            } else {
                Text("\(reihe.count) Werte").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.background, in: RoundedRectangle(cornerRadius: 10))
    }

    private func format(_ v: Double) -> String {
        String(format: "%.\(nachkomma)f", v).replacingOccurrences(of: ".", with: ",")
    }
}

/// Kleiner Verlauf – eigene Skala je Größe, damit kg und % nie in einem Diagramm landen.
private struct Reihe: View {
    let werte: [Wert]
    let farbe: Color
    let einheit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(einheit == "kg" ? "Gewicht" : "Körperfett")
                .font(.caption2).foregroundStyle(.secondary)
            Chart(werte) { w in
                LineMark(x: .value("Tag", w.datum), y: .value(einheit, w.wert))
                    .foregroundStyle(farbe)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                PointMark(x: .value("Tag", w.datum), y: .value(einheit, w.wert))
                    .foregroundStyle(farbe).symbolSize(22)
            }
            .chartYScale(domain: achsenBereich(werte.map(\.wert), schritt: einheit == "kg" ? 1 : 0.5))
            .chartLegend(.hidden)
            .frame(height: 90)
        }
    }
}


// MARK: - Fußzeile mit Version

struct Fusszeile: View {
    @EnvironmentObject var speicher: Speicher

    private var version: String {
        let info = Bundle.main.infoDictionary
        let v = info?["CFBundleShortVersionString"] as? String ?? "?"
        let b = info?["CFBundleVersion"] as? String ?? "?"
        return "Version \(v) (Build \(b))"
    }

    var body: some View {
        VStack(spacing: 4) {
            Text(version).font(.caption2).foregroundStyle(.secondary)
            if !speicher.meldung.isEmpty {
                Text(speicher.meldung).font(.caption2).foregroundStyle(.secondary)
            }
            Text("Grenzwert für die Selbstmessung zu Hause: ab 135/85 mmHg gilt der Blutdruck als erhöht. Keine medizinische Beurteilung.")
                .font(.caption2).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 6)
    }
}
