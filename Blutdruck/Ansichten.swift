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
    @State private var geblaettert = false
    @State private var einstellungen = false
    @State private var hinweisZeigen = false
    @AppStorage("hinweisBestaetigt") private var hinweisBestaetigt = false

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
    private var obenAngekommen: Bool { !geblaettert }

    var body: some View {
        NavigationStack {
            ScrollViewReader { blaettern in
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Color.clear.frame(height: 1).id("oben")
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
                                    puls: speicher.pulsBand.map { Wert(datum: .now, wert: $0.mitte) },
                                    anzahlPuls: speicher.pulsAnzahl, gemittelt: darstellung == .mittel)
                            Tagesprofil(punkte: punkte, ausreisser: zeigeAusreisser ? ausreisser : [],
                                        gewaehlt: $gewaehlt,
                                        pulsBand: speicher.pulsBand, pulsAnzahl: speicher.pulsAnzahl)
                            Tagesabschnitte(punkte: punkte, aufteilung: $aufteilung)
                            Verlauf(punkte: punkte,
                                    puls: speicher.pulsProTag,
                                    gewicht: imZeitraum(speicher.gewicht),
                                    fett: imZeitraum(speicher.koerperfett))
                            Koerperwerte(gewicht: imZeitraum(speicher.gewicht),
                                         fett: imZeitraum(speicher.koerperfett))
                            Messliste(alle: gefiltert)
                            Fusszeile()
                        }
                        Color.clear.frame(height: 1).id("unten")
                    }
                    .padding(16)
                }
                // Nur der Wahrheitswert, nicht die Position: sonst würde jedes Pixel
                // beim Blättern die gesamte Ansicht neu aufbauen.
                .onScrollGeometryChange(for: Bool.self) { geometrie in
                    geometrie.contentOffset.y + geometrie.contentInsets.top > 80
                } action: { _, neu in
                    geblaettert = neu
                }
                .refreshable { await neuLaden() }
                .safeAreaInset(edge: .top, spacing: 0) {
                    // Nur beim Blättern – oben steht der Zeitraum ohnehin in der Steuerung.
                    if !obenAngekommen && !speicher.messungen.isEmpty {
                        Zeitraumleiste(text: zeitraumText)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: geblaettert)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        // Nur wenn es etwas zu blättern gibt.
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
                        .opacity(speicher.messungen.isEmpty ? 0 : 1)
                        .disabled(speicher.messungen.isEmpty)
                    }
                    ToolbarItem(placement: .topBarLeading) {
                        Button { einstellungen = true } label: { Image(systemName: "gearshape") }
                            .accessibilityLabel("Einstellungen")
                    }
                    ToolbarItem(placement: .principal) {
                        HStack(spacing: 7) {
                            Image("Logo")
                                .resizable().scaledToFit().frame(width: 22, height: 22)
                                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .strokeBorder(.quaternary))
                            Text("Mein Blutdruck").font(.headline)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
            .navigationTitle("Mein Blutdruck")
            .navigationBarTitleDisplayMode(.inline)
            .overlay { if speicher.laedt { ProgressView().controlSize(.large) } }
            .sheet(isPresented: $einstellungen) { Einstellungen() }
            .sheet(isPresented: $hinweisZeigen) { Haftungshinweis(erstmalig: !hinweisBestaetigt) }
            .task { if !hinweisBestaetigt { hinweisZeigen = true } }
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

/// Zeigt dauerhaft, welcher Zeitraum gerade ausgewertet wird – beim Blättern hervorgehoben.
struct Zeitraumleiste: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "calendar").font(.caption).foregroundStyle(.secondary)
            Text(text).font(.footnote.weight(.medium))
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
        let nichtsGelesen = speicher.gelesen.sys == 0

        VStack(spacing: 18) {
            PulsendesLogo()

            VStack(spacing: 6) {
                Text("Noch keine Messwerte").font(.title3.bold())
                Text(speicher.meldung.isEmpty
                     ? "Die App wertet Blutdruck und Puls aus der Health-App aus – dazu Gewicht und Körperfett."
                     : speicher.meldung)
                    .font(.callout).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Der Weg zur Freigabe: Knopf und Erklärung gehören zusammen.
            VStack(spacing: 10) {
                Button {
                    Ziele.oeffnen(Ziele.healthDatenzugriff)
                } label: {
                    Label("Health-Einstellungen öffnen", systemImage: "heart.text.square")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Text("Dort auf dein Profilbild tippen, dann „Apps und Dienste“, dann „Mein Blutdruck“ – und alles einschalten. Diesen letzten Schritt kann dir keine App abnehmen.")
                    .font(.caption).foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))

            Button("Erneut aus Health laden") { Task { await speicher.laden() } }
                .buttonStyle(.bordered)
                .disabled(speicher.laedt)
                .font(.footnote)

            if nichtsGelesen {
                VStack(spacing: 2) {
                    Text("Aus Health gelesen").font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary).textCase(.uppercase)
                    Text("systolisch \(speicher.gelesen.sys) · diastolisch \(speicher.gelesen.dia)")
                        .font(.caption2.monospacedDigit()).foregroundStyle(.tertiary)
                }
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
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

            HStack(spacing: 0) {
                Angabe(wert: "\(ueberGrenze)", zusatz: "von \(anzahl)",
                       was: "über \(Int(grenzeSys))/\(Int(grenzeDia))")
                Trenner()
                Angabe(wert: "\(messreihen)", zusatz: nil, was: "Messreihen")
                Trenner()
                Angabe(wert: "\(ausreisser)", zusatz: nil, was: "Ausreißer")
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 10))
        }
    }
}

private struct Angabe: View {
    let wert: String
    let zusatz: String?
    let was: String
    var body: some View {
        VStack(spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(wert).font(.headline.monospacedDigit())
                if let z = zusatz {
                    Text(z).font(.caption2).foregroundStyle(.secondary)
                }
            }
            Text(was)
                .font(.caption2).foregroundStyle(.secondary)
                .lineLimit(1).minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)        // gleich breite Drittel
        .accessibilityElement(children: .combine)
    }
}

private struct Trenner: View {
    var body: some View {
        Rectangle().fill(.quaternary).frame(width: 1, height: 26)
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
    let anzahlPuls: Int
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
                   einheit: "bpm", hinweis: anzahlPuls == 0 ? "keine Werte" : "\(anzahlPuls) Werte",
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
    var pulsBand: [Bandwert] = []
    var pulsAnzahl = 0

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
        Karte(titel: "Tagesverlauf über 24 Stunden") {
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
            .modifier(StundenAchse(zeigen: pulsBand.isEmpty))
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

            if !pulsBand.isEmpty {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Puls (bpm)").font(.caption2).foregroundStyle(.secondary)
                    Chart {
                        ForEach(pulsBand) { b in
                            AreaMark(x: .value("Uhrzeit", b.minute),
                                     yStart: .value("von", b.unten), yEnd: .value("bis", b.oben))
                                .foregroundStyle(Color.pulsFarbe.opacity(0.16))
                                .interpolationMethod(.monotone)
                        }
                        ForEach(pulsBand) { b in
                            LineMark(x: .value("Uhrzeit", b.minute), y: .value("bpm", b.mitte))
                                .foregroundStyle(Color.pulsFarbe)
                                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                                .interpolationMethod(.monotone)
                        }
                    }
                    .chartXScale(domain: 0...1440)
                    .chartYScale(domain: achsenBereich(pulsBand.flatMap { [$0.unten, $0.oben] }, schritt: 10))
                    .modifier(StundenAchse(zeigen: true))
                    .chartLegend(.hidden)
                    .frame(height: 84)
                }
            }

            Legende(eintraege: [("Systolisch", .sysFarbe), ("Diastolisch", .diaFarbe)]
                    + (pulsBand.isEmpty ? [] : [("Puls", .pulsFarbe)]))

            if let g = gewaehlt {
                Detailkarte(messung: g)
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

struct StundenAchse: ViewModifier {
    let zeigen: Bool
    func body(content: Content) -> some View {
        content.chartXAxis {
            AxisMarks(values: [0.0, 360, 720, 1080, 1440]) { wert in
                AxisGridLine()
                if zeigen {
                    AxisValueLabel { if let m = wert.as(Double.self) { Text("\(Int(m / 60))") } }
                }
            }
        }
    }
}

struct Legende: View {
    let eintraege: [(String, Color)]

    /// Kurzformen, damit die Legende auch bei fünf Einträgen in eine Zeile passt.
    private func kurz(_ name: String) -> String {
        switch name {
        case "Körperfett": return "Fett"
        default:           return name
        }
    }

    private func zeile(kurzform: Bool, klein: Bool = false) -> some View {
        HStack(spacing: klein ? 9 : 13) {
            ForEach(eintraege, id: \.0) { name, farbe in
                HStack(spacing: 4) {
                    Circle().fill(farbe).frame(width: klein ? 7 : 8, height: klein ? 7 : 8)
                    Text(kurzform ? kurz(name) : name)
                        .font(klein ? .system(size: 10) : .caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1).fixedSize()
                }
            }
        }
    }

    var body: some View {
        // Erst die volle Beschriftung; passt sie nicht, die Kurzform, notfalls kleiner.
        ViewThatFits(in: .horizontal) {
            zeile(kurzform: false)
            zeile(kurzform: true)
            zeile(kurzform: false, klein: true)
            zeile(kurzform: true, klein: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct Detailkarte: View {
    let messung: Messung
    var body: some View {
        let b = Bewertung.fuer(sys: messung.sys, dia: messung.dia)
        VStack(alignment: .leading, spacing: 4) {
            Text(messung.datum.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute()))
                .font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 10) {
                Beschriftet(farbe: .sysFarbe, name: "Systolisch", wert: "\(Int(messung.sys))")
                Beschriftet(farbe: .diaFarbe, name: "Diastolisch", wert: "\(Int(messung.dia))")
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
                .lineLimit(1).minimumScaleFactor(0.8)
            Text(wert).font(.subheadline.bold())
        }
    }
}

// MARK: - Puls

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
                    HStack {
                        Text("Abschnitt").frame(maxWidth: .infinity, alignment: .leading)
                        Text("Messungen").frame(width: 72, alignment: .trailing)
                        Text("Ø mmHg").frame(width: 66, alignment: .trailing)
                        Text("über \(Int(grenzeSys))/\(Int(grenzeDia))")
                            .frame(width: 66, alignment: .trailing)
                    }
                    .font(.caption2).foregroundStyle(.secondary).textCase(.uppercase)

                    ForEach(werte) { w in
                        HStack {
                            Text(w.name).font(.subheadline.weight(.medium))
                            Text(w.spanne).font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Text("\(w.anzahl)").font(.caption).foregroundStyle(.secondary)
                                .frame(width: 72, alignment: .trailing)
                            // Bewertung nach den angezeigten, gerundeten Werten – sonst
                            // widersprechen sich Zahl und Farbe bei 84,5 gegenüber 85.
                            let zSys = w.sys.rounded(), zDia = w.dia.rounded()
                            Text("\(Int(zSys))/\(Int(zDia))")
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(Bewertung.fuer(sys: zSys, dia: zDia).farbe)
                                .frame(width: 66, alignment: .trailing)
                            Text("\(Int((Double(w.ueberGrenze) / Double(w.anzahl) * 100).rounded())) %")
                                .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                                .frame(width: 66, alignment: .trailing)
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
    let puls: [Wert]
    let gewicht: [Wert]
    let fett: [Wert]

    private struct Reihe {
        let name: String, einheit: String, schritt: Double
        let farbe: Color, werte: [Wert]
    }
    private var nebenreihen: [Reihe] {
        var r: [Reihe] = []
        if puls.count > 1 { r.append(.init(name: "Puls", einheit: "bpm", schritt: 5,
                                           farbe: .pulsFarbe, werte: puls)) }
        if gewicht.count > 1 { r.append(.init(name: "Gewicht", einheit: "kg", schritt: 1,
                                              farbe: .gewichtFarbe, werte: gewicht)) }
        if fett.count > 1 { r.append(.init(name: "Körperfett", einheit: "%", schritt: 0.5,
                                           farbe: .fettFarbe, werte: fett)) }
        return r
    }

    struct Trendpunkt: Identifiable {
        let id = UUID(); let serie: String; let datum: Date; let wert: Double; let farbe: Color
    }

    /// Geglättete Verlaufskurven für systolisch und diastolisch über die Tage.
    private var trend: [Trendpunkt] {
        guard let s = spanne else { return [] }
        let von = s.lowerBound.timeIntervalSince1970, bis = s.upperBound.timeIntervalSince1970
        guard bis > von else { return [] }
        let breite = max(43200, (bis - von) / 14)
        var alle: [Trendpunkt] = []
        for (name, pfad, farbe) in [("sys", \Messung.sys, Color.sysFarbe),
                                    ("dia", \Messung.dia, Color.diaFarbe)] {
            let roh = punkte.map { (x: $0.datum.timeIntervalSince1970, y: $0[keyPath: pfad]) }
            for (i, stueck) in Auswertung.kurve(roh, von: von, bis: bis, breite: breite).enumerated() {
                alle += stueck.map {
                    Trendpunkt(serie: "\(name)\(i)", datum: Date(timeIntervalSince1970: $0.x),
                               wert: $0.wert, farbe: farbe)
                }
            }
        }
        return alle
    }

    private var spanne: ClosedRange<Date>? {
        guard let a = punkte.map(\.datum).min(), let b = punkte.map(\.datum).max(), a < b else { return nil }
        return a...b
    }

    var body: some View {
        Karte(titel: "Verlauf über alle Tage") {
            Chart {
                ForEach([grenzeSys, grenzeDia], id: \.self) { g in
                    RuleMark(y: .value("Grenzwert", g))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                        .foregroundStyle(.secondary.opacity(0.5))
                }
                ForEach(punkte) { m in
                    PointMark(x: .value("Tag", m.datum), y: .value("mmHg", m.sys))
                        .foregroundStyle(Color.sysFarbe.opacity(0.55)).symbolSize(26)
                    PointMark(x: .value("Tag", m.datum), y: .value("mmHg", m.dia))
                        .foregroundStyle(Color.diaFarbe.opacity(0.55)).symbolSize(26)
                }
                ForEach(trend) { t in
                    LineMark(x: .value("Tag", t.datum), y: .value("mmHg", t.wert),
                             series: .value("Kurve", t.serie))
                        .foregroundStyle(t.farbe)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                }
            }
            .chartYScale(domain: achsenBereich(punkte.flatMap { [$0.sys, $0.dia] } + [grenzeSys, grenzeDia]))
            .modifier(GleicheZeitachse(spanne: spanne))
            .chartXAxis { AxisMarks { AxisGridLine() } }   // Datum steht nur unter dem letzten Verlauf
            .chartLegend(.hidden)
            .frame(height: 190)

            ForEach(Array(nebenreihen.enumerated()), id: \.element.name) { i, reihe in
                Nebenverlauf(werte: reihe.werte, farbe: reihe.farbe, name: reihe.name,
                             einheit: reihe.einheit, schritt: reihe.schritt, spanne: spanne,
                             mitDatum: i == nebenreihen.count - 1)
            }

            Legende(eintraege: [("Systolisch", .sysFarbe), ("Diastolisch", .diaFarbe)]
                    + nebenreihen.map { ($0.name, $0.farbe) })
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
    var mitDatum = true

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
            .modifier(DatumsAchse(zeigen: mitDatum))
            .chartLegend(.hidden)
            .frame(height: 84)
        }
    }
}

struct DatumsAchse: ViewModifier {
    let zeigen: Bool
    func body(content: Content) -> some View {
        if zeigen { content } else { content.chartXAxis { AxisMarks { AxisGridLine() } } }
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
    let alle: [Messung]
    @State private var modus: Listenmodus = .reihen
    @State private var offen = false

    private var zeilen: [Messung] {
        switch modus {
        case .einzeln: return alle.filter { !$0.ausreisser }.sorted { $0.datum > $1.datum }
        case .reihen:  return Auswertung.mitteln(alle).sorted { $0.datum > $1.datum }
        case .tage:    return Auswertung.proTag(alle).sorted { $0.datum > $1.datum }
        }
    }

    var body: some View {
        Karte(titel: "Blutdruck-Messwerte") {
            Picker("Zusammenfassung", selection: $modus) {
                ForEach(Listenmodus.allCases) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.segmented)

            Text(hinweis).font(.caption).foregroundStyle(.secondary)

            DisclosureGroup(isExpanded: $offen) {
                VStack(spacing: 0) {
                    ForEach(zeilen.prefix(offen ? 400 : 0)) { m in
                        Zeile(messung: m, modus: modus)
                        Divider()
                    }
                    if zeilen.count > 400 {
                        Text("… weitere \(zeilen.count - 400) nicht angezeigt")
                            .font(.caption2).foregroundStyle(.secondary).padding(.top, 6)
                    }
                }
            } label: {
                Text(offen ? "Einklappen" : "\(zeilen.count) anzeigen").font(.subheadline)
            }
        }
    }

    private var hinweis: String {
        switch modus {
        case .einzeln: return "Jede einzelne Messung."
        case .reihen:  return "Messungen, die dicht beieinander liegen, zu einem Wert zusammengefasst."
        case .tage:    return "Ein Wert je Tag, dazu die Spanne der systolischen Werte."
        }
    }
}

private struct Zeile: View {
    let messung: Messung
    let modus: Listenmodus

    var body: some View {
        let b = Bewertung.fuer(sys: messung.sys, dia: messung.dia)
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(messung.datum.formatted(.dateTime.day().month(.abbreviated)))
                    .font(.caption)
                if modus == .tage {
                    Text(messung.datum.formatted(.dateTime.weekday(.abbreviated)))
                        .font(.caption2).foregroundStyle(.secondary)
                } else {
                    Text(messung.datum.formatted(.dateTime.hour().minute()))
                        .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                }
            }
            .frame(width: 62, alignment: .leading)

            if messung.anzahl > 1 {
                Text("Ø \(messung.anzahl)").font(.caption2).foregroundStyle(.secondary)
                    .frame(width: 34, alignment: .leading)
            } else {
                Color.clear.frame(width: 34, height: 1)
            }

            Spacer()

            if modus == .tage, let hoch = messung.hoechster, let tief = messung.niedrigster, hoch > tief {
                Text("\(Int(tief))–\(Int(hoch))")
                    .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
            }

            Text("\(Int(messung.sys))/\(Int(messung.dia))")
                .font(.subheadline.monospacedDigit())
                .frame(width: 66, alignment: .trailing)

            Text(messung.puls.map { "\(Int($0))" } ?? "–")
                .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                .frame(width: 26, alignment: .trailing)

            Image(systemName: b.zeichen).font(.caption2).foregroundStyle(b.farbe).frame(width: 16)
        }
        .padding(.vertical, 5)
    }
}

struct Einstellungen: View {
    @EnvironmentObject var schutz: Schutz
    @EnvironmentObject var grenzen: Grenzwerte
    @Environment(\.dismiss) private var schliessen
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationLink {
                        Hinweisinhalt()
                            .navigationTitle("Wichtiger Hinweis")
                            .navigationBarTitleDisplayMode(.inline)
                    } label: {
                        Label("Wichtiger Hinweis zur Nutzung", systemImage: "exclamationmark.triangle")
                    }
                } footer: {
                    Text(Haftung.kurz)
                }

                Section {
                    Toggle("Beim Öffnen sperren", isOn: $schutz.aktiv)
                } header: {
                    Text("Schutz")
                } footer: {
                    Text("Aus. Eingeschaltet werden die Werte erst nach \(schutz.verfahren) angezeigt, und beim Wechsel in den Hintergrund sperrt die App wieder.")
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) { Kopfzeile(unterzeile: "Einstellungen") }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { schliessen() }
                }
            }
        }
    }
}

struct Fusszeile: View {
    @EnvironmentObject var speicher: Speicher
    @State private var zeigeHinweis = false
    private var version: String {
        let i = Bundle.main.infoDictionary
        return "Version \(i?["CFBundleShortVersionString"] as? String ?? "?") (Build \(i?["CFBundleVersion"] as? String ?? "?"))"
    }
    var body: some View {
        VStack(spacing: 4) {
            Text("Alle Werte stammen aus der Health-App.")
                .font(.caption2).foregroundStyle(.secondary)
            Text(version).font(.caption2).foregroundStyle(.secondary)
            Text("Erhöht ab \(Int(grenzeSys))/\(Int(grenzeDia)) mmHg – in den Einstellungen änderbar.")
                .font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button { zeigeHinweis = true } label: {
                Label(Haftung.kurz, systemImage: "info.circle")
                    .font(.caption2)
            }
            .buttonStyle(.plain).foregroundStyle(.secondary)
            .padding(.top, 2)

            Text("© \(Calendar.current.component(.year, from: .now).formatted(.number.grouping(.never))) eifelmono")
                .font(.caption2).foregroundStyle(.tertiary)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity).padding(.top, 6)
        .sheet(isPresented: $zeigeHinweis) { Haftungshinweis() }
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


/// Logo, App-Name und darunter, worum es auf diesem Bildschirm geht.
struct Kopfzeile: View {
    let unterzeile: String
    var body: some View {
        HStack(spacing: 8) {
            Image("Logo")
                .resizable().scaledToFit().frame(width: 26, height: 26)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(.quaternary))
            VStack(spacing: 0) {
                Text("Mein Blutdruck").font(.subheadline.weight(.semibold))
                Text(unterzeile).font(.caption2).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}


/// Öffnet das erste Ziel, das iOS annimmt. Manche Adressen in die Systemeinstellungen
/// sind nicht dokumentiert und können jederzeit wegfallen – deshalb die Kette mit Rückfall.
enum Ziele {
    // Bewusst ohne "App-prefs:" und "prefs:root=": das sind private Schnittstellen,
    // die bei der App-Prüfung zur Ablehnung führen.
    static let healthDatenzugriff = [
        "x-apple-health://",                 // Health-App
        UIApplication.openSettingsURLString  // sonst: Einstellungen der App
    ]

    static func oeffnen(_ adressen: [String]) {
        var offen = adressen
        func naechstes() {
            guard !offen.isEmpty else { return }
            let text = offen.removeFirst()
            guard let ziel = URL(string: text) else { naechstes(); return }
            UIApplication.shared.open(ziel, options: [:]) { erfolg in
                if !erfolg { naechstes() }
            }
        }
        naechstes()
    }
}


/// Erlaubt es, zwischen zwei Knopfstilen umzuschalten.
struct AnyButtonStyle: PrimitiveButtonStyle {
    private let bauen: (Configuration) -> AnyView
    init<S: PrimitiveButtonStyle>(_ stil: S) {
        bauen = { AnyView(Button($0).buttonStyle(stil)) }
    }
    func makeBody(configuration: Configuration) -> some View { bauen(configuration) }
}
