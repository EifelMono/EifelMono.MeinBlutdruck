import SwiftUI
import Charts

/// Erzeugt aus der aktuellen Auswertung einen PDF-Bericht im A4-Format.
enum PDFBericht {

    static let breite: CGFloat = 595   // A4 in Punkten
    static let hoehe: CGFloat = 842

    @MainActor
    static func erzeugen(messungen: [Messung], punkte: [Messung], puls: [Bandwert],
                         gewicht: [Wert], fett: [Wert], zeitraum: String,
                         darstellung: Darstellung) -> URL? {
        // Der Bericht folgt den Einstellungen – das steht im Kopf, damit später
        // nachvollziehbar bleibt, wie die Zahlen zustande kamen.
        let einstellung = "\(darstellung.rawValue) · erhöht ab \(Int(grenzeSys))/\(Int(grenzeDia)) mmHg"
            + " · Messreihe bis \(Int(Auswertung.fensterMinuten)) min Abstand, Ausreißer ab ±\(Int(Auswertung.toleranz)) mmHg"
        let seiten: [AnyView] = [
            AnyView(SeiteEins(messungen: messungen, punkte: punkte, puls: puls,
                              gewicht: gewicht, fett: fett, zeitraum: zeitraum,
                              einstellung: einstellung)),
            AnyView(SeiteZwei(tage: Auswertung.proTag(messungen), zeitraum: zeitraum,
                              einstellung: einstellung)),
        ]

        let ordner = FileManager.default.temporaryDirectory
        let ziel = ordner.appending(path: "Blutdruck-Bericht.pdf")
        var rahmen = CGRect(x: 0, y: 0, width: breite, height: hoehe)
        guard let ctx = CGContext(ziel as CFURL, mediaBox: &rahmen, nil) else { return nil }

        for seite in seiten {
            let zeichner = ImageRenderer(content: seite.frame(width: breite, height: hoehe))
            zeichner.scale = 3
            zeichner.render { _, male in
                ctx.beginPDFPage(nil)
                male(ctx)
                ctx.endPDFPage()
            }
        }
        ctx.closePDF()
        return ziel
    }
}

// MARK: - Erste Seite: Kennzahlen und Diagramme

private struct SeiteEins: View {
    let messungen: [Messung]
    let punkte: [Messung]
    let puls: [Bandwert]
    let gewicht: [Wert]
    let fett: [Wert]
    let zeitraum: String
    let einstellung: String

    var body: some View {
        let gueltig = messungen.filter { !$0.ausreisser }
        let sys = Auswertung.mittel(gueltig.map(\.sys)) ?? 0
        let dia = Auswertung.mittel(gueltig.map(\.dia)) ?? 0
        let ueber = gueltig.filter { $0.sys >= grenzeSys || $0.dia >= grenzeDia }.count
        let bewertung = Bewertung.fuer(sys: sys, dia: dia)

        VStack(alignment: .leading, spacing: 16) {
            Kopf(zeitraum: zeitraum, einstellung: einstellung, seite: 1)

            HStack(spacing: 10) {
                Feld(titel: "Ø Blutdruck", wert: "\(Int(sys.rounded()))/\(Int(dia.rounded()))",
                     einheit: "mmHg", zusatz: bewertung.rawValue, farbe: bewertung.farbe)
                Feld(titel: "Messungen", wert: "\(messungen.count)", einheit: "",
                     zusatz: "\(Set(messungen.map(\.reihe)).count) Messreihen")
                Feld(titel: "Über \(Int(grenzeSys))/\(Int(grenzeDia))",
                     wert: gueltig.isEmpty ? "–" : "\(Int((Double(ueber) / Double(gueltig.count) * 100).rounded()))",
                     einheit: "%", zusatz: "\(ueber) von \(gueltig.count)")
                Feld(titel: "Ø Puls",
                     wert: Auswertung.mittel(puls.map(\.mitte)).map { "\(Int($0.rounded()))" } ?? "–",
                     einheit: "bpm", zusatz: "aus Health")
            }

            Ueberschrift("Tagesabschnitte")
            VStack(spacing: 4) {
                HStack {
                    Text("Abschnitt").frame(maxWidth: .infinity, alignment: .leading)
                    Text("Messungen").frame(width: 80, alignment: .trailing)
                    Text("Ø mmHg").frame(width: 70, alignment: .trailing)
                    Text("über Grenzwert").frame(width: 100, alignment: .trailing)
                }
                .font(.system(size: 8, weight: .semibold)).foregroundStyle(.secondary)
                ForEach(Auswertung.abschnitte(punkte)) { a in
                    HStack {
                        Text("\(a.name) \(a.spanne)").frame(maxWidth: .infinity, alignment: .leading)
                        Text("\(a.anzahl)").frame(width: 80, alignment: .trailing)
                        Text("\(Int(a.sys.rounded()))/\(Int(a.dia.rounded()))")
                            .frame(width: 70, alignment: .trailing)
                        Text("\(Int((Double(a.ueberGrenze) / Double(a.anzahl) * 100).rounded())) %")
                            .frame(width: 100, alignment: .trailing)
                    }
                    .font(.system(size: 9))
                    Divider()
                }
            }

            Ueberschrift("Tagesverlauf über 24 Stunden")
            Chart {
                ForEach([grenzeSys, grenzeDia], id: \.self) { g in
                    RuleMark(y: .value("Grenzwert", g))
                        .lineStyle(StrokeStyle(lineWidth: 0.7, dash: [4, 3]))
                        .foregroundStyle(.secondary.opacity(0.6))
                }
                ForEach(punkte) { m in
                    PointMark(x: .value("Uhrzeit", Double(m.minuten)), y: .value("mmHg", m.sys))
                        .foregroundStyle(Color.sysFarbe).symbolSize(10)
                    PointMark(x: .value("Uhrzeit", Double(m.minuten)), y: .value("mmHg", m.dia))
                        .foregroundStyle(Color.diaFarbe).symbolSize(10)
                }
            }
            .chartXScale(domain: 0...1440)
            .chartXAxis {
                AxisMarks(values: [0.0, 360, 720, 1080, 1440]) { w in
                    AxisGridLine()
                    AxisValueLabel { if let m = w.as(Double.self) { Text("\(Int(m / 60))") } }
                }
            }
            .chartLegend(.hidden)
            .frame(height: 150)

            Ueberschrift("Verlauf über alle Tage")
            Chart {
                ForEach([grenzeSys, grenzeDia], id: \.self) { g in
                    RuleMark(y: .value("Grenzwert", g))
                        .lineStyle(StrokeStyle(lineWidth: 0.7, dash: [4, 3]))
                        .foregroundStyle(.secondary.opacity(0.6))
                }
                ForEach(punkte) { m in
                    PointMark(x: .value("Tag", m.datum), y: .value("mmHg", m.sys))
                        .foregroundStyle(Color.sysFarbe).symbolSize(8)
                    PointMark(x: .value("Tag", m.datum), y: .value("mmHg", m.dia))
                        .foregroundStyle(Color.diaFarbe).symbolSize(8)
                }
            }
            .chartLegend(.hidden)
            .frame(height: 130)

            HStack(spacing: 14) {
                Punkt("Systolisch", .sysFarbe)
                Punkt("Diastolisch", .diaFarbe)
                if let g = gewicht.neuester {
                    Text("Gewicht zuletzt \(String(format: "%.1f", g.wert).replacingOccurrences(of: ".", with: ",")) kg")
                        .font(.system(size: 8)).foregroundStyle(.secondary)
                }
                if let f = fett.neuester {
                    Text("Körperfett zuletzt \(String(format: "%.1f", f.wert).replacingOccurrences(of: ".", with: ",")) %")
                        .font(.system(size: 8)).foregroundStyle(.secondary)
                }
            }

            Spacer()
            Fuss()
        }
        .padding(36)
        .frame(width: PDFBericht.breite, height: PDFBericht.hoehe)
        .background(.white)
        .environment(\.colorScheme, .light)
    }
}

// MARK: - Zweite Seite: ein Wert je Tag

private struct SeiteZwei: View {
    let tage: [Messung]
    let zeitraum: String
    let einstellung: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Kopf(zeitraum: zeitraum, einstellung: einstellung, seite: 2)
            Ueberschrift("Mittelwerte je Tag")

            HStack {
                Text("Tag").frame(width: 90, alignment: .leading)
                Text("Messungen").frame(width: 70, alignment: .trailing)
                Text("Ø mmHg").frame(width: 70, alignment: .trailing)
                Text("Spanne systolisch").frame(width: 110, alignment: .trailing)
                Text("Ø Puls").frame(width: 60, alignment: .trailing)
                Text("Bewertung").frame(maxWidth: .infinity, alignment: .trailing)
            }
            .font(.system(size: 8, weight: .semibold)).foregroundStyle(.secondary)

            ForEach(tage.reversed().prefix(45)) { t in
                let b = Bewertung.fuer(sys: t.sys, dia: t.dia)
                HStack {
                    Text(t.datum.formatted(.dateTime.weekday(.abbreviated)
                                           .day(.twoDigits).month(.twoDigits)))
                        .frame(width: 90, alignment: .leading)
                    Text("\(t.anzahl)").frame(width: 70, alignment: .trailing)
                    Text("\(Int(t.sys))/\(Int(t.dia))").frame(width: 70, alignment: .trailing)
                    Text(t.niedrigster != nil && t.hoechster != nil
                         ? "\(Int(t.niedrigster!))–\(Int(t.hoechster!))" : "–")
                        .frame(width: 110, alignment: .trailing)
                    Text(t.puls.map { "\(Int($0))" } ?? "–").frame(width: 60, alignment: .trailing)
                    Text(b.rawValue).foregroundStyle(b.farbe)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .font(.system(size: 9))
                Divider()
            }

            Spacer()
            Fuss()
        }
        .padding(36)
        .frame(width: PDFBericht.breite, height: PDFBericht.hoehe)
        .background(.white)
        .environment(\.colorScheme, .light)
    }
}

// MARK: - Bausteine

private struct Kopf: View {
    let zeitraum: String
    let einstellung: String
    let seite: Int

    private var fassung: String {
        let i = Bundle.main.infoDictionary
        return "Mein Blutdruck \(i?["CFBundleShortVersionString"] as? String ?? "?")"
            + " (Build \(i?["CFBundleVersion"] as? String ?? "?"))"
    }
    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Blutdruck-Bericht").font(.system(size: 20, weight: .semibold))
                Text(zeitraum).font(.system(size: 10)).foregroundStyle(.secondary)
                Text(einstellung).font(.system(size: 7.5)).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("Erstellt \(Date().formatted(.dateTime.day(.twoDigits).month(.twoDigits).year().hour().minute()))")
                Text(fassung)
                Text("Seite \(seite) von 2")
            }
            .font(.system(size: 8)).foregroundStyle(.secondary)
        }
        Divider()
    }
}

private struct Ueberschrift: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text).font(.system(size: 12, weight: .semibold))
    }
}

private struct Feld: View {
    let titel: String, wert: String, einheit: String, zusatz: String
    var farbe: Color = .primary
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(titel).font(.system(size: 8, weight: .semibold)).foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(wert).font(.system(size: 18, weight: .semibold))
                Text(einheit).font(.system(size: 8)).foregroundStyle(.secondary)
            }
            Text(zusatz).font(.system(size: 8)).foregroundStyle(farbe)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color(white: 0.96), in: RoundedRectangle(cornerRadius: 6))
    }
}

private struct Punkt: View {
    let name: String, farbe: Color
    init(_ name: String, _ farbe: Color) { self.name = name; self.farbe = farbe }
    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(farbe).frame(width: 5, height: 5)
            Text(name).font(.system(size: 8)).foregroundStyle(.secondary)
        }
    }
}

private struct Fuss: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Divider()
            Text("Erstellt mit Mein Blutdruck – © \(Calendar.current.component(.year, from: .now).formatted(.number.grouping(.never))) eifelmono. "
                 + "Alle Werte stammen aus der Health-App. Erhöht ab \(Int(grenzeSys))/\(Int(grenzeDia)) mmHg. "
                 + "Kein Medizinprodukt – diese Auswertung diagnostiziert, behandelt oder heilt keine Erkrankung "
                 + "und ersetzt keine ärztliche Beurteilung.")
                .font(.system(size: 7)).foregroundStyle(.secondary)
        }
    }
}
