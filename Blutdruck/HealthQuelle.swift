import Foundation
import HealthKit

/// Liest die Blutdruckmessungen aus der Health-App – und schreibt beim CSV-Import hinein.
@MainActor
final class Speicher: ObservableObject {

    @Published var messungen: [Messung] = []
    @Published var gewicht: [Wert] = []
    @Published var koerperfett: [Wert] = []
    @Published var pulsReihe: [Wert] = []
    /// Fertig verdichtet, damit die Diagramme nicht bei jedem Bildaufbau zehntausende
    /// Einzelwerte durchrechnen müssen.
    @Published var pulsBand: [Bandwert] = []
    @Published var pulsProTag: [Wert] = []
    @Published var pulsAnzahl = 0
    @Published var pulsHinweis = ""
    private var pulsSchluessel = ""
    @Published var meldung = ""
    @Published var laedt = false
    @Published var healthVerfuegbar = HKHealthStore.isHealthDataAvailable()

    private let store = HKHealthStore()

    /// Wie viele Einzelproben Health zurückgegeben hat – hilft beim Eingrenzen von Problemen.
    @Published var gelesen: (sys: Int, dia: Int, puls: Int) = (0, 0, 0)

    private let sysTyp = HKQuantityType(.bloodPressureSystolic)
    private let diaTyp = HKQuantityType(.bloodPressureDiastolic)
    private let pulsTyp = HKQuantityType(.heartRate)
    private let gewichtTyp = HKQuantityType(.bodyMass)
    private let fettTyp = HKQuantityType(.bodyFatPercentage)

    private let mmHg = HKUnit.millimeterOfMercury()
    private var proMinute: HKUnit { HKUnit.count().unitDivided(by: .minute()) }

    // MARK: Berechtigung

    func erlaubnisEinholen() async -> Bool {
        guard healthVerfuegbar else {
            meldung = "Auf diesem Gerät gibt es keine Health-Daten."
            return false
        }
        do {
            // Nur lesen – die App schreibt nichts in die Health-App.
            // Für Korrelationstypen darf keine Leseerlaubnis angefordert werden,
            // der Blutdruck wird über seine Einzelwerte freigegeben.
            try await store.requestAuthorization(
                toShare: [], read: [sysTyp, diaTyp, pulsTyp, gewichtTyp, fettTyp])
            return true
        } catch {
            meldung = "Health hat den Zugriff nicht erlaubt: \(error.localizedDescription)"
            return false
        }
    }

    // MARK: Lesen

    func laden() async {
        laedt = true
        pulsSchluessel = ""
        defer { laedt = false }
        print("BD: laden() gestartet, Health verfügbar: \(healthVerfuegbar)")
        guard await erlaubnisEinholen() else {
            print("BD: Berechtigung fehlgeschlagen – \(meldung)")
            return
        }
        print("BD: Berechtigung erteilt, frage Blutdruck ab …")
        do {
            // Einzelwerte abfragen statt der Blutdruck-Korrelation: Korrelationen legt nur
            // die schreibende App an, die beiden Quantitäten gibt es dagegen immer.
            async let sysA = werteLesen(sysTyp)
            async let diaA = werteLesen(diaTyp)
            let (systolisch, diastolisch) = try await (sysA, diaA)
            print("BD: systolisch \(systolisch.count), diastolisch \(diastolisch.count)")
            if let e = systolisch.first, let l = systolisch.last {
                print("BD: Zeitraum \(e.startDate) bis \(l.startDate)")
                print("BD: Quelle \(e.sourceRevision.source.name)")
            }
            for (i, s) in systolisch.prefix(3).enumerated() {
                let d = diastolisch.count > i ? "\(diastolisch[i].startDate)" : "–"
                print("BD: Probe \(i): sys \(s.startDate) / dia \(d)")
            }

            guard let ersteMessung = systolisch.first?.startDate,
                  let letzteMessung = systolisch.last?.startDate else {
                messungen = []
                gelesen = (systolisch.count, diastolisch.count, 0)
                meldung = "Health liefert keine Blutdruckwerte zurück.\n\nEntweder stehen dort noch keine, oder der Lesezugriff ist nicht erlaubt: Health-App → Profilbild → Apps und Dienste → Blutdruck → alles einschalten."
                return
            }

            // Nur Pulswerte aus dem Zeitraum der Blutdruckmessungen holen. Ohne diese
            // Einschränkung würde die Abfrage jede je aufgezeichnete Herzfrequenz laden –
            // bei einer Apple Watch sind das schnell Hunderttausende.
            // Nur Pulswerte aus denselben Quellen wie der Blutdruck. Ohne das käme die
            // komplette Herzfrequenz-Historie der Apple Watch mit – Hunderttausende Werte,
            // die weder gebraucht werden noch in vertretbarer Zeit zu verarbeiten sind.
            let quellen = Set(systolisch.map(\.sourceRevision.source))
            let pulse = try await werteLesen(pulsTyp,
                                             von: ersteMessung.addingTimeInterval(-300),
                                             bis: letzteMessung.addingTimeInterval(300),
                                             quellen: quellen)
            print("BD: Pulswerte aus \(quellen.count) Quelle(n): \(pulse.count)")

            // Systolisch und diastolisch gehören zusammen, wenn sie denselben Zeitpunkt tragen.
            // Systolisch und diastolisch zusammenführen. Normalerweise tragen beide denselben
            // Zeitstempel, manche Quellen weichen aber um Sekundenbruchteile ab – deshalb mit
            // Toleranz, notfalls mit einer größeren. Jeder Wert wird nur einmal vergeben.
            var paare = zusammenfuehren(systolisch, diastolisch, toleranz: 15)
            var weitGefasst = false
            if paare.isEmpty && !systolisch.isEmpty && !diastolisch.isEmpty {
                paare = zusammenfuehren(systolisch, diastolisch, toleranz: 600)
                weitGefasst = !paare.isEmpty
            }

            print("BD: Paare gebildet: \(paare.count) (weiter gefasst: \(weitGefasst))")
            var pulsNachMinute: [Int: [HKQuantitySample]] = [:]
            for p in pulse { pulsNachMinute[Int(p.startDate.timeIntervalSince1970 / 60), default: []].append(p) }
            var gefunden: [Messung] = []
            for (s, d) in paare {
                // Über den Minutenindex statt linearer Suche – sonst wächst der Aufwand
                // mit Messungen × Pulswerten.
                let minute = Int(s.startDate.timeIntervalSince1970 / 60)
                let nahePuls = [minute - 1, minute, minute + 1]
                    .flatMap { pulsNachMinute[$0] ?? [] }
                    .filter { abs($0.startDate.timeIntervalSince(s.startDate)) <= 90 }
                    .min { abs($0.startDate.timeIntervalSince(s.startDate))
                         < abs($1.startDate.timeIntervalSince(s.startDate)) }
                gefunden.append(Messung(
                    datum: s.startDate,
                    sys: s.quantity.doubleValue(for: mmHg).rounded(),
                    dia: d.quantity.doubleValue(for: mmHg).rounded(),
                    puls: nahePuls?.quantity.doubleValue(for: proMinute).rounded()))
            }
            _ = weitGefasst
            gefunden.sort { $0.datum < $1.datum }
            messungen = Auswertung.filtern(gefunden)

            // Gewicht und Körperfett – wenige Werte, deshalb ohne Einschränkung.
            let kg = HKUnit.gramUnit(with: .kilo)
            gewicht = (try? await werteLesen(gewichtTyp))?
                .map { Wert(datum: $0.startDate, wert: $0.quantity.doubleValue(for: kg)) } ?? []
            koerperfett = (try? await werteLesen(fettTyp))?
                .map { Wert(datum: $0.startDate, wert: $0.quantity.doubleValue(for: .percent()) * 100) } ?? []
            print("BD: fertig – \(gefunden.count) Messungen, \(gewicht.count) Gewichte, \(koerperfett.count) Körperfett")
            gelesen = (systolisch.count, diastolisch.count, pulse.count)
            gelesen = (systolisch.count, diastolisch.count, pulse.count)
            meldung = gefunden.isEmpty
                ? "Gelesen: \(systolisch.count) systolische, \(diastolisch.count) diastolische Werte – keiner ließ sich paaren."
                : "\(gefunden.count) Messungen aus Health"
                  + (weitGefasst ? " (Zeitstempel wichen ab, weiter gefasst zusammengeführt)" : "")
        } catch {
            print("BD: FEHLER \(error)")
            meldung = "Health-Daten konnten nicht gelesen werden: \(error.localizedDescription)"
        }
    }

    /// Pulswerte für den angezeigten Zeitraum – erst hier, weil über Jahre hinweg
    /// leicht Hunderttausende Herzschlagwerte zusammenkommen.
    func pulsLaden(von: Date, bis: Date) async {
        let schluessel = "\(Int(von.timeIntervalSince1970))-\(Int(bis.timeIntervalSince1970))"
        guard schluessel != pulsSchluessel else { return }
        pulsSchluessel = schluessel

        let tage = bis.timeIntervalSince(von) / 86400
        guard tage <= 400 else {
            pulsReihe = []
            pulsHinweis = "Der Zeitraum ist zu groß für die Pulsdarstellung – bitte höchstens ein Jahr wählen."
            return
        }
        do {
            let proben = try await werteLesen(pulsTyp,
                                              von: von.addingTimeInterval(-300),
                                              bis: bis.addingTimeInterval(300))
            let werte = proben.map { Wert(datum: $0.startDate,
                                          wert: $0.quantity.doubleValue(for: proMinute).rounded()) }
            pulsAnzahl = werte.count
            pulsReihe = werte.count > 3000 ? [] : werte     // Rohwerte nur, wenn überschaubar
            pulsBand = verdichten(werte)
            pulsProTag = Auswertung.proTag(werte)
            pulsHinweis = werte.isEmpty
                ? "Für diesen Zeitraum liegen in Health keine Pulswerte vor."
                : ""
            print("BD: Puls im Zeitraum: \(werte.count), verdichtet auf \(pulsBand.count)")
        } catch {
            pulsReihe = []; pulsBand = []; pulsProTag = []; pulsAnzahl = 0
            pulsHinweis = "Pulswerte konnten nicht gelesen werden."
        }
    }

    /// Je Viertelstunde des Tages: mittlerer Puls und der Bereich der mittleren 80 %.
    private func verdichten(_ werte: [Wert]) -> [Bandwert] {
        let kal = Calendar.current
        var eimer: [Int: [Double]] = [:]
        for w in werte {
            let t = kal.dateComponents([.hour, .minute], from: w.datum)
            let minute = (t.hour ?? 0) * 60 + (t.minute ?? 0)
            eimer[minute / 15, default: []].append(w.wert)
        }
        return eimer.keys.sorted().compactMap { k in
            let v = eimer[k]!.sorted()
            guard let m = Auswertung.mittel(v) else { return nil }
            let u = v[Int(Double(v.count) * 0.1)]
            let o = v[min(v.count - 1, Int(Double(v.count) * 0.9))]
            return Bandwert(minute: Double(k * 15 + 7), unten: u, oben: o, mitte: m)
        }
    }

    private func werteLesen(_ typ: HKQuantityType,
                            von: Date? = nil, bis: Date? = nil,
                            quellen: Set<HKSource>? = nil) async throws -> [HKQuantitySample] {
        var teile: [NSPredicate] = []
        if von != nil || bis != nil {
            teile.append(HKQuery.predicateForSamples(withStart: von, end: bis))
        }
        if let quellen, !quellen.isEmpty {
            teile.append(HKQuery.predicateForObjects(from: quellen))
        }
        let filter = teile.isEmpty ? nil : NSCompoundPredicate(andPredicateWithSubpredicates: teile)
        let abfrage = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: typ, predicate: filter)],
            sortDescriptors: [SortDescriptor(\.startDate)], limit: nil)
        return try await abfrage.result(for: store)
    }

    /// Führt zwei nach Zeit sortierte Reihen paarweise zusammen (Zwei-Zeiger-Verfahren).
    private func zusammenfuehren(_ a: [HKQuantitySample], _ b: [HKQuantitySample],
                                 toleranz: TimeInterval) -> [(HKQuantitySample, HKQuantitySample)] {
        var paare: [(HKQuantitySample, HKQuantitySample)] = []
        var i = 0, j = 0
        while i < a.count && j < b.count {
            let abstand = a[i].startDate.timeIntervalSince(b[j].startDate)
            if abs(abstand) <= toleranz { paare.append((a[i], b[j])); i += 1; j += 1 }
            else if abstand > 0 { j += 1 }
            else { i += 1 }
        }
        return paare
    }

}
