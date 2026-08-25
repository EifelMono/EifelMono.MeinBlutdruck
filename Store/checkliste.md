# Weg in den App Store — Checkliste

## Erledigt (im Projekt)
- [x] Bundle-ID `de.klapperich.meinblutdruck`
- [x] Version 1.0, Build 60, Deployment Target iOS 18.0
- [x] `ITSAppUsesNonExemptEncryption = false` (keine Exportfragen beim Upload)
- [x] Health-Zweckbeschreibungen (`NSHealthShareUsageDescription`) auf Deutsch
- [x] Nur lesender Health-Zugriff, keine Netzwerkverbindung, keine Fremdbibliotheken
- [x] Haftungshinweis beim ersten Start mit Bestaetigung, dazu in Einstellungen und Fusszeile
- [x] Datenschutzerklaerung in der App (Einstellungen → Datenschutz)
- [x] App-Icon und Startbildschirm fuer alle Groessen
- [x] Store/datenschutz.html, Store/impressum.html, Store/store-eintrag.md, Store/pruefhinweise-en.md

## Noch zu tun (ausserhalb des Projekts)
- [ ] Apple Developer Program: 99 USD/Jahr, Mitgliedschaft aktiv
- [ ] Datenschutzseite veroeffentlichen (z. B. GitHub Pages) und die URL in
      App Store Connect eintragen. Vorgesehen:
      https://eifelmono.github.io/MeinBlutdruck/datenschutz.html
- [ ] App-Datensatz in App Store Connect anlegen (Name, Untertitel, Kategorie
      Medizin, Altersfreigabe)
- [ ] App-Datenschutz-Fragebogen: "keine Daten erfasst"
- [ ] Bildschirmfotos: Pflicht ist 6,9 Zoll (1290x2796). Vorhandene Aufnahmen
      liegen im Repository, sonst neu auf dem iPhone erstellen
      (Beispieldaten aus dem letzten Commit nutzen)
- [ ] Archiv erstellen und hochladen: Xcode → Product → Archive →
      Distribute App → App Store Connect
- [ ] Pruefhinweise aus Store/pruefhinweise-en.md in App Review Information
      einfuegen (englisch)
- [ ] Zur Pruefung einreichen

## GitHub Pages einrichten (falls gewuenscht)
1. Repository auf GitHub veroeffentlichen
2. Einstellungen → Pages → Quelle: Branch `main`, Ordner `/Store`
   (oder die beiden HTML-Dateien nach `/docs` kopieren)
3. Nach wenigen Minuten ist die Seite unter der oben genannten Adresse erreichbar

## Womit die Pruefung erfahrungsgemaess anecken kann
- Health-Apps ohne sichtbare Daten wirken leer. Deshalb steht in den
  Pruefhinweisen ausdruecklich, dass die Leseschalter in Apples Dialog nach
  unten gescrollt und eingeschaltet werden muessen.
- Kategorie Medizin zieht mehr Aufmerksamkeit auf Heilaussagen. Die App
  vermeidet sie durchgehend und nennt Grenzwerte "Bezugswerte".
