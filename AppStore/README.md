# Weg in den App Store

Alles, was ohne Zugang zum Entwickler-Konto vorbereitet werden konnte, liegt in
diesem Ordner. Was bleibt, sind die Schritte in App Store Connect und in Xcode –
die brauchen die Anmeldung.

## Was schon erledigt ist

| | |
|---|---|
| Bildschirmfotos 6,9″ (1320 × 2868) | `screenshots-6.9/` – sieben Stück, mit **erfundenen** Werten |
| Beispieldaten in der App | Einstellungen → „Ausprobieren" → „Beispieldaten anzeigen" |
| Store-Texte (Name, Untertitel, Beschreibung, Schlüsselbegriffe) | `Store-Texte.md` |
| Datenschutzerklärung | `datenschutz.html` |
| Antworten zum Datenschutz-Fragebogen | `Datenschutz-Fragebogen.md` |
| Hinweise für die Prüfung | `Pruefhinweise.md` |
| `ITSAppUsesNonExemptEncryption = false` | in `MeinBlutdruck/Info.plist` |
| Signierung für die Veröffentlichung | Release steht auf automatischer Signierung, `xcodebuild archive` läuft durch |
| App-Symbol 1024 px, Startbildschirm, Version 1.0 (Build 60) | vorhanden |

Die Bildschirmfotos zeigen **keine echten Messwerte**. Die App wurde dafür mit
dem Startschalter `-Beispieldaten` gestartet; die Werte erzeugt
`MeinBlutdruck/Beispieldaten.swift` aus einer festen Zufallsfolge – immer
dieselben Zahlen, damit sich die Bilder jederzeit gleich wiederholen lassen.

## Bildschirmfotos neu erzeugen

```bash
xcrun simctl boot 3DEA4EA0-F139-4CD1-909E-936DB7554A31
xcrun simctl status_bar 3DEA4EA0-F139-4CD1-909E-936DB7554A31 override --time "09:41" --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3
xcrun simctl launch 3DEA4EA0-F139-4CD1-909E-936DB7554A31 de.klapperich.blutdruck -Beispieldaten
```

Die Kennung gehört zum Simulator „iPhone 17 Pro Max"; die Größe 1320 × 2868 ist
genau das, was Apple für 6,9″ verlangt. Andere Größen füllt App Store Connect
selbst auf, ein zweiter Satz ist nicht nötig.

## Was noch zu tun ist (mit Entwickler-Konto)

1. **Bundle-Kennung festlegen.**
   Zurzeit: `de.klapperich.blutdruck`. Sie lässt sich nach dem ersten Hochladen
   **nicht mehr ändern**. Wer lieber `de.eifelmono.meinblutdruck` hätte, muss das
   jetzt entscheiden – Änderung in den Ziel-Einstellungen und in
   `project.pbxproj`.

2. **App-ID anlegen** auf developer.apple.com → Certificates, Identifiers &
   Profiles → Identifiers → „+" → App IDs → App.
   Beschreibung „Mein Blutdruck", Bundle ID wie oben, **HealthKit ankreuzen**.

3. **Datenschutzseite veröffentlichen.**
   `datenschutz.html` z. B. über GitHub Pages erreichbar machen und in der
   Datei noch die vollständige Anschrift ergänzen.

4. **App in App Store Connect anlegen.**
   Meine Apps → „+" → Neue App. Plattform iOS, Name „Mein Blutdruck",
   Primärsprache Deutsch, Bundle ID auswählen, SKU frei wählbar
   (z. B. `meinblutdruck-1`).

5. **Texte und Bilder eintragen** aus `Store-Texte.md` und `screenshots-6.9/`.

6. **Datenschutz-Fragebogen** nach `Datenschutz-Fragebogen.md` beantworten.

7. **Altersfreigabe** ausfüllen → ergibt 4+.

8. **Hochladen.**
   In Xcode: Produkt → Archivieren, dann im Organizer
   „Distribute App" → „App Store Connect" → „Upload".
   Xcode signiert dabei selbst mit dem Verteilungszertifikat.

   Auf der Kommandozeile geht es auch:
   ```bash
   DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
     -project EifelMono.MeinBlutdruck.xcodeproj -scheme MeinBlutdruck \
     -configuration Release -destination 'generic/platform=iOS' \
     -archivePath ~/Desktop/MeinBlutdruck.xcarchive archive
   ```
   Der Export braucht danach eine `ExportOptions.plist` mit `method: app-store-connect`;
   über den Organizer ist es der kürzere Weg.

9. **Prüfhinweise** aus `Pruefhinweise.md` eintragen – ohne sie sieht die
   Prüfung eine leere App und lehnt sie ab. Das ist der häufigste Grund, warum
   Health-Apps abgelehnt werden.

10. **Zur Prüfung einreichen.**

## Worauf die Prüfung bei dieser Art App besonders schaut

- **Leerer Bildschirm ohne Health-Daten.** Deshalb die Beispieldaten und der
  Hinweis in `Pruefhinweise.md`.
- **HealthKit-Regeln.** Health-Daten dürfen nicht für Werbung genutzt und nicht
  ohne Zustimmung weitergegeben werden; eine Datenschutz-URL ist Pflicht.
  Beides ist erfüllt.
- **Kein Medizinprodukt.** Der Haftungshinweis beim ersten Start, in den
  Einstellungen und in der Fußzeile deckt das ab.
- **Aussagekraft der Bewertung.** Die Einordnung „erhöht" ist als Vergleich mit
  selbst gewählten Grenzwerten beschrieben, nicht als Diagnose. Wer noch
  vorsichtiger sein will, ersetzt in `Modell.swift` das Wort „erhöht" durch
  „über deinem Grenzwert" – nötig ist es nach heutiger Lesart nicht.

## Nach der Veröffentlichung

Für jede weitere Version muss `CURRENT_PROJECT_VERSION` (Build) steigen;
`MARKETING_VERSION` nur, wenn sich für die Nutzung etwas ändert.
