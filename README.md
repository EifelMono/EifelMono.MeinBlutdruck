# Mein Blutdruck

Eine iPhone-App, die Blutdruck, Puls, Gewicht und Körperfett aus der
**Health-App von Apple** liest und auswertet. Ohne Konto, ohne Server, ohne
Werbung – alles bleibt auf dem Gerät.

- [Datenschutzerklärung](DATENSCHUTZ.md)
- [Impressum](IMPRESSUM.md)
- Fragen und Rückmeldungen: [andreas@klapperich.de](mailto:andreas@klapperich.de)

## Was die App zeigt

- **Tagesverlauf über 24 Stunden** – alle Messtage übereinandergelegt, mit
  gleitendem Mittelwert
- **Tagesabschnitte** morgens, mittags, abends – wahlweise stündlich
- **Verlauf über alle Tage** mit Trendkurve, darunter Puls, Gewicht und
  Körperfett auf derselben Zeitachse
- **Messwerte** einzeln, als Messreihe zusammengefasst oder je Tag
- **PDF-Bericht** auf zwei Seiten für die ärztliche Praxis
- Eigene Grenzwerte, optionale Sperre mit Face ID

Messungen, die dicht beieinander liegen, fasst die App zu Messreihen zusammen
und erkennt Ausreißer, damit einzelne Fehlmessungen das Bild nicht verzerren.

## Kein Medizinprodukt

Mein Blutdruck ist kein Medizinprodukt. Die App diagnostiziert, behandelt oder
heilt keine Erkrankung und ersetzt keine ärztliche Beurteilung. Grenzwerte und
Bewertungen sind rechnerische Hilfsmittel.

## Für Entwickler

Xcode-Projekt, Swift und SwiftUI, ab iOS 18. Keine Fremdbibliotheken.

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project EifelMono.MeinBlutdruck.xcodeproj -scheme MeinBlutdruck \
  -destination 'generic/platform=iOS' build
```

Die Unterlagen für die Veröffentlichung liegen in [`AppStore/`](AppStore/).
