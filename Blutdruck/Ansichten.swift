import SwiftUI
import Charts

// MARK: - Hauptansicht

struct Uebersicht: View {
    @EnvironmentObject var speicher: Speicher
    @EnvironmentObject var schutz: Schutz

    @State private var zeitraum: Zeitraum = .vierzehn
    @State private var darstellung: Darstellung = .einzeln
    @State private var aufteilung: Aufteilung = .abschnitte
    @State private var zeigeAusreisser = true
    @State private var eigenerZeitraum = false
    @State private var von = Calendar.current.date(byAdding: .day, value: -13, to: .now) ?? .now
    @State private var bis = Date.now
    @State private var gewaehlt: Messung?
    @State private var abstand: CGFloat = 0
    @State private var einstellungen = false

    private var gefiltert: [Messung] {
        eigenerZeitraum ? Auswertung.imZeitraum(speicher.messungen, von: von, bis: bis)
                        : Auswertung.imZeitraum(speicher.messungen, zeitraum)
    }
    private var gueltig: [Messung] { gefiltert.filter { !$0.ausreisser } }
    private var punkte: [Messung] { darstellung == .mittel ? Auswertung.mitteln(gefiltert) : gueltig }
    private var ausreisser: [Messung] { gefiltert.filter(\.ausreisser) }
    private var grenzen: (von: Date, bis: Date)? {
        guard let a = gefiltert.map(\.datum).min(), let b = gefiltert.map(\.datum).max() else { return nil }
        return (a, b)
    }
    private var zeitraumText: String {
        guard let g = grenzen else { return "kein Zeitraum" }
        let f = Date.FormatStyle.dateTime.day().month(.abbreviated).year(.twoDigits)
        return "\(g.von.formatted(f)) – \(g.bis.formatted(f))"
    }
    private var zeitfenster: ClosedRange<Date> {
        let alle = speicher.messungen.map(\.datum)
        guard let a = alle.min(), let b = alle.max(), a < b else { return Date.distantPast...Date.now }
        return a...b
    }
    private var obenAngekommen: Bool { abstand > -80 }

    var body: some View {
        NavigationStack {
            ScrollViewReader { blaettern in
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Color.clear.frame(height: 1).id("oben")
                            .background(GeometryReader { g in
                                Color.clear.preference(key: AbstandSchluessel.self,
                                                       value: g.frame(in: .named("rolle")).minY)
                            })
                        if speicher.messungen.isEmpty {
                            Leerzustand()
                        } else {
                            Steuerung(zeitraum: $zeitraum, darstellung: $darstellung,
                                      zeigeAusreisser: $zeigeAusreisser,
                                      eigenerZeitraum: $eigenerZeitraum, von: $von, bis: $bis,
                                      fenster: zeitfenster, zeitraumText: zeitraumText,
                                      ueberGrenze: punkte.filter { $0.sys >= grenzeSys || $0.dia >= grenzeDia }.count,
                                      anzahl: punkte.count,
                                      messreihen: Set(gefiltert.map(\.reihe)).count,
                                      ausreisser: ausreisser.count)
                            Kacheln(punkte: punkte, alle: gefiltert, ausreisser: ausreisser.count,
                                    puls: speicher.pulsReihe, gemittelt: darstellung == .mittel)
                            Tagesprofil(punkte: punkte, ausreisser: zeigeAusreisser ? ausreisser : [],
                                        gewaehlt: $gewaehlt)
                            PulsProfil(werte: speicher.pulsReihe, hinweis: speicher.pulsHinweis)
                            Tagesabschnitte(punkte: punkte, aufteilung: $aufteilung)
                            Verlauf(punkte: punkte, gewicht: imZeitraum(speicher.gewicht),
                                    fett: imZeitraum(speicher.koerperfett))
                            Koerperwerte(gewicht: imZeitraum(speicher.gewicht),
                                         fett: imZeitraum(speicher.koerperfett))
                            Messliste(punkte: punkte.reversed(), gemittelt: darstellung == .mittel)
                            Fusszeile()
                        }
                        Color.clear.frame(height: 1).id("unten")
                    }
                    .padding(16)
                }
                .coordinateSpace(name: "rolle")
                .onPreferenceChange(AbstandSchluessel.self) { abstand = $0 }
                .refreshable { await neuLaden() }
                .safeAreaInset(edge: .top, spacing: 0) {
                    // Nur beim Blättern – oben steht der Zeitraum ohnehin in der Steuerung.
                    if !obenAngekommen && !speicher.messungen.isEmpty {
                        Zeitraumleiste(text: zeitraumText, anzahl: gefiltert.count)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: obenAngekommen)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        // Beide Richtungen immer erreichbar – am Ende genauso wie am Anfang.
                        HStack(spacing: 2) {
                            Button {
                                withAnimation { blaettern.scrollTo("oben", anchor: .top) }
                            } label: { Image(systemName: "arrow.up.to.line") }
                                .accessibilityLabel("An den Anfang springen")
                                .disabled(obenAngekommen)
                            Button {
                                withAnimation { blaettern.scrollTo("unten", anchor: .bottom) }
                            } label: { Image(systemName: "arrow.down.to.line") }
                                .accessibilityLabel("Ans Ende springen")
                        }
                    }
                    ToolbarItem(placement: .topBarLeading) {
                        Button { einstellungen = true } label: { Image(systemName: "gearshape") }
                            .accessibilityLabel("Einstellungen")
                    }
                }
            }
            .navigationTitle("Blutdruck")
            .overlay { if speicher.laedt { ProgressView().controlSize(.large) } }
            .sheet(isPresented: $einstellungen) { Einstellungen() }
            .task { await neuLaden() }
            .task(id: neuladeSchluessel) { await pulsNachladen() }
        }
    }

    private var neuladeSchluessel: String {
        "\(zeitraum.rawValue)|\(eigenerZeitraum)|\(von.timeIntervalSince1970)|\(bis.timeIntervalSince1970)|\(speicher.messungen.count)"
    }

    private func neuLaden() async {
        await speicher.laden()
        await pulsNachladen()
    }

    private func pulsNachladen() async {
        guard let g = grenzen else { return }
        await speicher.pulsLaden(von: g.von, bis: g.bis)
    }

    private func imZeitraum(_ werte: [Wert]) -> [Wert] {
        guard let g = grenzen else { return [] }
        let kal = Calendar.current
        let start = kal.startOfDay(for: g.von)
        let ende = kal.date(byAdding: .day, value: 1, to: kal.startOfDay(for: g.bis)) ?? g.bis
        return werte.filter { $0.datum >= start && $0.datum < ende }.sorted { $0.datum < $1.datum }
    }
}

struct AbstandSchluessel: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

/// Zeigt dauerhaft, welcher Zeitraum gerade ausgewertet wird – beim Blättern hervorgehoben.
struct Zeitraumleiste: View {
    let text: String
    let anzahl: Int

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "calendar").font(.caption).foregroundStyle(.secondary)
            Text(text).font(.footnote.weight(.medium))
            Text("· \(anzahl) Messungen").font(.footnote).foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
        .background(.regularMaterial)
        .overlay(alignment: .bottom) { Divider() }
    }
}

// MARK: - Bausteine

struct Leerzustand: View {
    @EnvironmentObject var speicher: Speicher
    var body: some View {
        VStack(spacing: 14) {
            PulsendesLogo()
            Text("Noch keine Messwerte").font(.title3.bold())
            Text(speicher.meldung.isEmpty
                 ? "Die App wertet Blutdruck und Puls aus der Health-App aus – dazu Gewicht und Körperfett, um zu sehen, wie sie zusammenhängen."
                 : speicher.meldung)
                .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
            VStack(spacing: 2) {
                Text("Aus Health gelesen").font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary).textCase(.uppercase)
                Text("systolisch \(speicher.gelesen.sys) · diastolisch \(speicher.gelesen.dia)")
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                if speicher.gelesen.sys == 0 {
                    Text("Health-App → Profilbild → Apps und Dienste → Blutdruck")
                        .font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
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
    let zeitraumText: String
    let ueberGrenze: Int
    let anzahl: Int
    let messreihen: Int
    let ausreisser: Int

    var body: some View {
        VStack(spacing: 10) {
            Picker("Zeitraum", selection: $zeitraum) {
                ForEach(Zeitraum.allCases) { Text($0.titel).tag($0) }
            }
            .pickerStyle(.segmented)
            .disabled(eigenerZeitraum)
            .opacity(eigenerZeitraum ? 0.4 : 1)

            if eigenerZeitraum {
                HStack(spacing: 8) {
                    DatePicker("von", selection: $von, in: fenster, displayedComponents: .date)
                        .labelsHidden()
                    Text("bis").font(.footnote).foregroundStyle(.secondary)
                    DatePicker("bis", selection: $bis, in: fenster, displayedComponents: .date)
                        .labelsHidden()
                    Spacer()
                    Button("Zurück") { withAnimation { eigenerZeitraum = false } }
                        .font(.footnote)
                }
            } else {
                HStack {
                    Text(zeitraumText).font(.footnote).foregroundStyle(.secondary)
                    Spacer()
                    Button("Eigener Zeitraum") {
                        if let a = fenster.lowerBound as Date?, let b = fenster.upperBound as Date? {
                            von = max(a, Calendar.current.date(byAdding: .day, value: -13, to: b) ?? a)
                            bis = b
                        }
                        withAnimation { eigenerZeitraum = true }
                    }
                    .font(.footnote)
                }
            }

            Picker("Darstellung", selection: $darstellung) {
                ForEach(Darstellung.allCases) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.segmented)

            Toggle("Ausgefilterte Messungen zeigen", isOn: $zeigeAusreisser)
                .font(.footnote).tint(.sysFarbe)

            HStack(spacing: 12) {
                Angabe(wert: "\(ueberGrenze)", von: "von \(anzahl)",
                       was: "über \(Int(grenzeSys))/\(Int(grenzeDia))")
                Trenner()
                Angabe(wert: "\(messreihen)", von: nil, was: "Messreihen")
                Trenner()
                Angabe(wert: "\(ausreisser)", von: nil, was: "Ausreißer entfernt")
                Spacer()
            }
            .padding(.top, 2)
        }
    }
}

private struct Angabe: View {
    let wert: String
    let von: String?
    let was: String
    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(wert).font(.subheadline.weight(.semibold).monospacedDigit())
                if let v = von { Text(v).font(.caption2).foregroundStyle(.secondary) }
            }
            Text(was).font(.caption2).foregroundStyle(.secondary)
        }
    }
}

private struct Trenner: View {
    var body: some View {
        Rectangle().fill(.quaternary).frame(width: 1, height: 22)
    }
}

struct Kachel: View {
    let titel: String, wert: String, einheit: String, hinweis: String
    var punktFarbe: Color? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                if let f = punktFarbe { Circle().fill(f).frame(width: 8, height: 8) }
                Text(titel).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(wert).font(.title.weight(.semibold))
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
    let punkte: [Messung], alle: [Messung], ausreisser: Int
    let puls: [Wert]
    let gemittelt: Bool

    var body: some View {
        let sys = Auswertung.mittel(punkte.map(\.sys)) ?? 0
        let dia = Auswertung.mittel(punkte.map(\.dia)) ?? 0
        let mPuls = Auswertung.mittel(puls.map(\.wert)) ?? Auswertung.mittel(punkte.compactMap(\.puls))
        let ueber = punkte.filter { $0.sys >= grenzeSys || $0.dia >= grenzeDia }.count
        let bewertung = Bewertung.fuer(sys: sys, dia: dia)

        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            // Der Mittelwert steht in Textfarbe – die Bewertung daneben trägt die Farbe.
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Circle().fill(Color.sysFarbe).frame(width: 8, height: 8)
                    Circle().fill(Color.diaFarbe).frame(width: 8, height: 8)
                    Text("Ø Blutdruck").font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary).textCase(.uppercase)
                }
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(Int(sys.rounded()))/\(Int(dia.rounded()))")
                        .font(.title.weight(.semibold))
                    Text("mmHg").font(.caption).foregroundStyle(.secondary)
                }
                Label(bewertung.rawValue, systemImage: bewertung.zeichen)
                    .font(.caption2.weight(.medium)).foregroundStyle(bewertung.farbe)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))

            Kachel(titel: "Ø Puls", wert: mPuls.map { "\(Int($0.rounded()))" } ?? "–",
                   einheit: "bpm", hinweis: puls.isEmpty ? "keine Werte" : "\(puls.count) Werte",
                   punktFarbe: .pulsFarbe)
        }
    }
}

struct Karte<Inhalt: View>: View {
    let titel: String
    var unterzeile: String? = nil
    @ViewBuilder var inhalt: Inhalt
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(titel).font(.headline)
            if let u = unterzeile {
                Text(u).font(.caption).foregroundStyle(.secondary)
            }
            inhalt
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
    }
}

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
        for (name, pfad, farbe) in [("sys", \Messung.sys, Color.sysFarbe),
                                    ("dia", \Messung.dia, Color.diaFarbe)] {
            let roh = punkte.map { (x: Double($0.minuten), y: $0[keyPath: pfad]) }
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
                ForEach([grenzeSys, grenzeDia], id: \.self) { g in
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
                    LineMark(x: .value("Uhrzeit", k.x), y: .value("mmHg", k.y),
                             series: .value("Kurve", k.serie))
                        .foregroundStyle(k.farbe)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                }
                ForEach(ausreisser) { m in
                    PointMark(x: .value("Uhrzeit", Double(m.minuten)), y: .value("mmHg", m.sys))
                        .foregroundStyle(.secondary.opacity(0.5)).symbolSize(24)
                    PointMark(x: .value("Uhrzeit", Double(m.minuten)), y: .value("mmHg", m.dia))
                        .foregroundStyle(.secondary.opacity(0.5)).symbolSize(24)
                }
                ForEach(punkte) { m in
                    PointMark(x: .value("Uhrzeit", Double(m.minuten)), y: .value("mmHg", m.sys))
                        .foregroundStyle(Color.sysFarbe).symbolSize(42)
                    PointMark(x: .value("Uhrzeit", Double(m.minuten)), y: .value("mmHg", m.dia))
                        .foregroundStyle(Color.diaFarbe).symbolSize(42)
                }
                if let g = gewaehlt {
                    RuleMark(x: .value("Uhrzeit", Double(g.minuten)))
                        .foregroundStyle(.secondary.opacity(0.7))
                }
            }
            .chartXScale(domain: 0...1440)
            .chartYScale(domain: achsenBereich((punkte + ausreisser).flatMap { [$0.sys, $0.dia] } + [grenzeSys, grenzeDia]))
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

            Legende(eintraege: [("Systolisch", .sysFarbe), ("Diastolisch", .diaFarbe)])

            if let g = gewaehlt {
                Detailkarte(messung: g)
            } else {
                Text("Einen Messpunkt antippen zeigt die Einzelheiten.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func naechster(minute: Double, wert: Double) -> Messung? {
        (punkte + ausreisser).min { abstand($0, minute, wert) < abstand($1, minute, wert) }
    }
    private func abstand(_ m: Messung, _ minute: Double, _ wert: Double) -> Double {
        let dx = (Double(m.minuten) - minute) / 1440
        let dySys = (m.sys - wert) / 120, dyDia = (m.dia - wert) / 120
        return dx * dx + min(dySys * dySys, dyDia * dyDia)
    }
}

struct Legende: View {
    let eintraege: [(String, Color)]
    var body: some View {
        HStack(spacing: 14) {
            ForEach(eintraege, id: \.0) { name, farbe in
                HStack(spacing: 5) {
                    Circle().fill(farbe).frame(width: 8, height: 8)
                    Text(name).font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
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
                Label(b.rawValue, systemImage: b.zeichen).font(.caption.weight(.medium))
                    .foregroundStyle(b.farbe)
                if messung.anzahl > 1 {
                    Text("· Ø aus \(messung.anzahl)").font(.caption).foregroundStyle(.secondary)
                }
                if messung.ausreisser {
                    Text("· ✕ \(messung.grund)").font(.caption).foregroundStyle(Color.statusKritisch)
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

// MARK: - Puls

struct PulsProfil: View {
    let werte: [Wert]
    let hinweis: String

    var body: some View {
        Karte(titel: "Puls über 24 Stunden") {
            if werte.isEmpty {
                Text(hinweis.isEmpty ? "Für diesen Zeitraum liegen in Health keine Pulswerte vor."
                                     : hinweis)
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Chart {
                    // Bei vielen Werten – etwa aus der Apple Watch – wäre die Punktwolke
                    // ein einziger Klumpen. Dann zeigen wir das Streuband statt der Punkte.
                    if dicht {
                        ForEach(band) { b in
                            AreaMark(x: .value("Uhrzeit", b.x),
                                     yStart: .value("von", b.unten), yEnd: .value("bis", b.oben),
                                     series: .value("Band", b.serie))
                                .foregroundStyle(Color.pulsFarbe.opacity(0.16))
                        }
                    } else {
                        ForEach(werte) { w in
                            PointMark(x: .value("Uhrzeit", Double(minuten(w.datum))),
                                      y: .value("bpm", w.wert))
                                .foregroundStyle(Color.pulsFarbe.opacity(0.75)).symbolSize(26)
                        }
                    }
                    ForEach(kurve) { k in
                        LineMark(x: .value("Uhrzeit", k.x), y: .value("bpm", k.y),
                                 series: .value("Kurve", k.serie))
                            .foregroundStyle(Color.pulsFarbe)
                            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    }
                }
                .chartXScale(domain: 0...1440)
                .chartYScale(domain: achsenBereich(werte.map(\.wert), schritt: 10))
                .chartXAxis {
                    AxisMarks(values: [0.0, 360, 720, 1080, 1440]) { wert in
                        AxisGridLine()
                        AxisValueLabel { if let m = wert.as(Double.self) { Text("\(Int(m / 60))") } }
                    }
                }
                .chartLegend(.hidden)
                .frame(height: 150)
                Legende(eintraege: [("Puls", .pulsFarbe)])
            }
        }
    }

    private func minuten(_ d: Date) -> Int {
        let t = Calendar.current.dateComponents([.hour, .minute], from: d)
        return (t.hour ?? 0) * 60 + (t.minute ?? 0)
    }
    private var dicht: Bool { werte.count > 400 }

    struct Bandpunkt: Identifiable {
        let id = UUID(); let serie: String; let x: Double; let unten: Double; let oben: Double
    }

    /// Streuband: je Viertelstunde der Bereich, in dem die mittleren 80 % der Werte liegen.
    private var band: [Bandpunkt] {
        var eimer: [Int: [Double]] = [:]
        for w in werte { eimer[minuten(w.datum) / 15, default: []].append(w.wert) }
        return eimer.keys.sorted().compactMap { k in
            let v = eimer[k]!.sorted()
            guard v.count >= 3 else { return nil }
            let u = v[Int(Double(v.count) * 0.1)]
            let o = v[min(v.count - 1, Int(Double(v.count) * 0.9))]
            return Bandpunkt(serie: "band", x: Double(k * 15 + 7), unten: u, oben: o)
        }
    }

    private var kurve: [KurvenStueck] {
        var eimer: [Int: [Double]] = [:]
        for w in werte { eimer[minuten(w.datum) / 15, default: []].append(w.wert) }
        let roh = eimer.keys.sorted().map { k in
            (x: Double(k * 15 + 7), y: Auswertung.mittel(eimer[k]!) ?? 0)
        }
        return Auswertung.kurve(roh, von: 0, bis: 1440, breite: 70).enumerated().flatMap { i, stueck in
            stueck.map { KurvenStueck(serie: "p\(i)", x: $0.x, y: $0.wert, farbe: .pulsFarbe) }
        }
    }
}

// MARK: - Tagesabschnitte, wahlweise stündlich

struct Tagesabschnitte: View {
    let punkte: [Messung]
    @Binding var aufteilung: Aufteilung

    private var werte: [AbschnittsWert] {
        aufteilung == .abschnitte ? Auswertung.abschnitte(punkte) : Auswertung.stunden(punkte)
    }

    var body: some View {
        Karte(titel: "Tagesabschnitte im Vergleich") {
            Picker("Aufteilung", selection: $aufteilung) {
                ForEach(Aufteilung.allCases) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.segmented)

            Chart {
                ForEach([grenzeSys, grenzeDia], id: \.self) { g in
                    RuleMark(y: .value("Grenzwert", g))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                        .foregroundStyle(.secondary.opacity(0.5))
                }
                ForEach(werte) { w in
                    RuleMark(x: .value("Abschnitt", w.name),
                             yStart: .value("Dia", w.dia), yEnd: .value("Sys", w.sys))
                        .lineStyle(StrokeStyle(lineWidth: aufteilung == .abschnitte ? 3 : 2, lineCap: .round))
                        .foregroundStyle(.secondary.opacity(0.45))
                    PointMark(x: .value("Abschnitt", w.name), y: .value("Sys", w.sys))
                        .foregroundStyle(Color.sysFarbe)
                        .symbolSize(aufteilung == .abschnitte ? 150 : 45)
                    PointMark(x: .value("Abschnitt", w.name), y: .value("Dia", w.dia))
                        .foregroundStyle(Color.diaFarbe)
                        .symbolSize(aufteilung == .abschnitte ? 150 : 45)
                }
            }
            .chartYScale(domain: achsenBereich(werte.flatMap { [$0.sys, $0.dia] } + [grenzeSys, grenzeDia], schritt: 10))
            .chartXAxis {
                AxisMarks { wert in
                    AxisValueLabel {
                        if let n = wert.as(String.self) {
                            Text(aufteilung == .abschnitte ? n : (Int(n) ?? 0) % 3 == 0 ? n : "")
                                .font(.caption2)
                        }
                    }
                }
            }
            .chartLegend(.hidden)
            .frame(height: aufteilung == .abschnitte ? 210 : 190)
            Legende(eintraege: [("Ø Systolisch", .sysFarbe), ("Ø Diastolisch", .diaFarbe)])

            if aufteilung == .abschnitte {
                VStack(spacing: 6) {
                    ForEach(werte) { w in
                        HStack {
                            Text(w.name).font(.subheadline.weight(.medium))
                            Text(w.spanne).font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Text("\(w.anzahl)").font(.caption).foregroundStyle(.secondary).frame(width: 34)
                            Text("\(Int(w.sys.rounded()))/\(Int(w.dia.rounded()))")
                                .font(.subheadline.monospacedDigit())
                                .frame(width: 66, alignment: .trailing)
                            Text("\(Int((Double(w.ueberGrenze) / Double(w.anzahl) * 100).rounded())) %")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(Bewertung.fuer(sys: w.sys, dia: w.dia).farbe)
                                .frame(width: 46, alignment: .trailing)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Verlauf über alle Tage, darunter Gewicht und Körperfett

struct Verlauf: View {
    let punkte: [Messung]
    let gewicht: [Wert]
    let fett: [Wert]

    private var spanne: ClosedRange<Date>? {
        guard let a = punkte.map(\.datum).min(), let b = punkte.map(\.datum).max(), a < b else { return nil }
        return a...b
    }

    var body: some View {
        Karte(titel: "Verlauf über alle Tage",
              unterzeile: "Gleiche Zeitachse – so ist zu sehen, ob Gewicht und Blutdruck zusammen wandern") {
            Chart {
                ForEach([grenzeSys, grenzeDia], id: \.self) { g in
                    RuleMark(y: .value("Grenzwert", g))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                        .foregroundStyle(.secondary.opacity(0.5))
                }
                ForEach(punkte) { m in
                    PointMark(x: .value("Tag", m.datum), y: .value("mmHg", m.sys))
                        .foregroundStyle(Color.sysFarbe).symbolSize(32)
                    PointMark(x: .value("Tag", m.datum), y: .value("mmHg", m.dia))
                        .foregroundStyle(Color.diaFarbe).symbolSize(32)
                }
            }
            .chartYScale(domain: achsenBereich(punkte.flatMap { [$0.sys, $0.dia] } + [grenzeSys, grenzeDia]))
            .modifier(GleicheZeitachse(spanne: spanne))
            .chartLegend(.hidden)
            .frame(height: 190)

            if !gewicht.isEmpty {
                Nebenverlauf(werte: gewicht, farbe: .gewichtFarbe, name: "Gewicht",
                             einheit: "kg", schritt: 1, spanne: spanne)
            }
            if !fett.isEmpty {
                Nebenverlauf(werte: fett, farbe: .fettFarbe, name: "Körperfett",
                             einheit: "%", schritt: 0.5, spanne: spanne)
            }
            Legende(eintraege: [("Systolisch", .sysFarbe), ("Diastolisch", .diaFarbe)]
                    + (gewicht.isEmpty ? [] : [("Gewicht", .gewichtFarbe)])
                    + (fett.isEmpty ? [] : [("Körperfett", .fettFarbe)]))
        }
    }
}

/// Schmaler Verlauf unter dem Blutdruck – eigene Skala, aber dieselbe Zeitachse.
struct Nebenverlauf: View {
    let werte: [Wert]
    let farbe: Color
    let name: String
    let einheit: String
    let schritt: Double
    let spanne: ClosedRange<Date>?

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("\(name) (\(einheit))").font(.caption2).foregroundStyle(.secondary)
            Chart(werte) { w in
                LineMark(x: .value("Tag", w.datum), y: .value(einheit, w.wert))
                    .foregroundStyle(farbe)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.monotone)
                PointMark(x: .value("Tag", w.datum), y: .value(einheit, w.wert))
                    .foregroundStyle(farbe).symbolSize(18)
            }
            .chartYScale(domain: achsenBereich(werte.map(\.wert), schritt: schritt))
            .modifier(GleicheZeitachse(spanne: spanne))
            .chartLegend(.hidden)
            .frame(height: 84)
        }
    }
}

struct GleicheZeitachse: ViewModifier {
    let spanne: ClosedRange<Date>?
    func body(content: Content) -> some View {
        if let s = spanne { content.chartXScale(domain: s) } else { content }
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
            Karte(titel: "Gewicht und Körperfett") {
                HStack(spacing: 10) {
                    Kennzahl(titel: "Gewicht", reihe: gewicht, einheit: "kg", farbe: .gewichtFarbe)
                    Kennzahl(titel: "Körperfett", reihe: fett, einheit: "%", farbe: .fettFarbe)
                }
            }
        }
    }
}

private struct Kennzahl: View {
    let titel: String
    let reihe: [Wert]
    let einheit: String
    let farbe: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                Circle().fill(farbe).frame(width: 8, height: 8)
                Text(titel).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(reihe.neuester.map { zahl($0.wert) } ?? "–").font(.title2.weight(.semibold))
                Text(einheit).font(.caption).foregroundStyle(.secondary)
            }
            if let d = reihe.veraenderung, abs(d) >= 0.05 {
                Text("\(d > 0 ? "+" : "−")\(zahl(abs(d))) \(einheit) im Zeitraum")
                    .font(.caption2).foregroundStyle(.secondary)
            } else {
                Text("\(reihe.count) Werte").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.background, in: RoundedRectangle(cornerRadius: 10))
    }
    private func zahl(_ v: Double) -> String {
        String(format: "%.1f", v).replacingOccurrences(of: ".", with: ",")
    }
}

// MARK: - Liste, Einstellungen, Fußzeile

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
                                .frame(width: 66, alignment: .trailing)
                            Image(systemName: Bewertung.fuer(sys: m.sys, dia: m.dia).zeichen)
                                .font(.caption2)
                                .foregroundStyle(Bewertung.fuer(sys: m.sys, dia: m.dia).farbe)
                                .frame(width: 18)
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

struct Einstellungen: View {
    @EnvironmentObject var schutz: Schutz
    @EnvironmentObject var grenzen: Grenzwerte
    @Environment(\.dismiss) private var schliessen
    var body: some View {
        NavigationStack {
            Form {
                Section("Schutz") {
                    Toggle("Beim Öffnen sperren", isOn: $schutz.aktiv)
                    Text("Die Werte werden erst nach \(schutz.verfahren) angezeigt. Beim Wechsel in den Hintergrund sperrt die App wieder.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section {
                    Stepper(value: $grenzen.sys, in: 110...180, step: 5) {
                        HStack {
                            Text("Systolisch ab")
                            Spacer()
                            Text("\(Int(grenzen.sys)) mmHg").foregroundStyle(.secondary)
                        }
                    }
                    Stepper(value: $grenzen.dia, in: 60...110, step: 5) {
                        HStack {
                            Text("Diastolisch ab")
                            Spacer()
                            Text("\(Int(grenzen.dia)) mmHg").foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Ab wann gilt der Wert als erhöht")
                } footer: {
                    Text("Alle Kennzahlen, Bewertungen und die gestrichelten Linien in den Diagrammen richten sich nach diesen Werten.")
                }

                Section("Gebräuchliche Bezugswerte") {
                    ForEach(Grenzwerte.vorschlaege) { v in
                        Button {
                            grenzen.sys = v.sys; grenzen.dia = v.dia
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text(v.name).font(.subheadline.weight(.medium))
                                    Spacer()
                                    Text("\(Int(v.sys))/\(Int(v.dia))")
                                        .font(.subheadline.monospacedDigit())
                                        .foregroundStyle(grenzen.sys == v.sys && grenzen.dia == v.dia
                                                         ? Color.sysFarbe : .secondary)
                                    if grenzen.sys == v.sys && grenzen.dia == v.dia {
                                        Image(systemName: "checkmark").font(.caption).foregroundStyle(Color.sysFarbe)
                                    }
                                }
                                Text(v.erklaerung).font(.caption).foregroundStyle(.secondary)
                                    .multilineTextAlignment(.leading)
                            }
                        }
                        .tint(.primary)
                    }
                    Text("Welcher Wert für dich gilt, entscheidet die behandelnde Praxis. Die Vorschläge sind allgemeine Bezugswerte, keine ärztliche Empfehlung.")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) {
                Button("Fertig") { schliessen() } } }
        }
    }
}

struct Fusszeile: View {
    @EnvironmentObject var speicher: Speicher
    private var version: String {
        let i = Bundle.main.infoDictionary
        return "Version \(i?["CFBundleShortVersionString"] as? String ?? "?") (Build \(i?["CFBundleVersion"] as? String ?? "?"))"
    }
    var body: some View {
        VStack(spacing: 4) {
            Text("Alle Werte stammen aus der Health-App.")
                .font(.caption2).foregroundStyle(.secondary)
            Text(version).font(.caption2).foregroundStyle(.secondary)
            Text("Erhöht ab \(Int(grenzeSys))/\(Int(grenzeDia)) mmHg – in den Einstellungen änderbar. Keine medizinische Beurteilung.")
                .font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.top, 6)
    }
}


/// Das Logo schlägt – ruhig, etwa im Takt eines gelassenen Pulses.
struct PulsendesLogo: View {
    @State private var gross = false
    var body: some View {
        Image("Logo")
            .resizable().scaledToFit().frame(width: 96, height: 96)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(.quaternary))
            .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
            .scaleEffect(gross ? 1.06 : 1.0)
            .animation(.easeInOut(duration: 0.42).repeatForever(autoreverses: true), value: gross)
            .onAppear { gross = true }
            .accessibilityHidden(true)
    }
}
