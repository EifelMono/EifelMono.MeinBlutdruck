# App-Datenschutz (App Privacy) in App Store Connect

Der Fragebogen unter **App-Datenschutz** fragt, welche Daten „gesammelt"
werden. Gesammelt heißt bei Apple: die Daten verlassen das Gerät oder werden
über eine Sitzung hinaus mit der Person verknüpft. Beides trifft hier nicht zu.

## Antwort auf die erste Frage

> „Erfasst diese App Daten?"

**Nein, wir erfassen keine Daten aus dieser App.**

Begründung, falls nachgefragt wird: Die Gesundheitsdaten werden ausschließlich
auf dem Gerät gelesen und angezeigt, nicht gespeichert und nicht übertragen.
Dauerhaft gespeichert werden nur Einstellungen ohne Personenbezug (Grenzwerte,
Zeitraum, Darstellung, Sperre ja/nein).

Damit erscheint im Store der Eintrag „Keine Daten erfasst".

## Was zusätzlich stimmen muss

- **Datenschutz-URL** ist Pflicht, sobald HealthKit verwendet wird.
  → `AppStore/datenschutz.html` veröffentlichen und die Adresse eintragen.
- Die Zweckbeschreibungen in der Info.plist sind vorhanden:
  - `NSHealthShareUsageDescription`
  - `NSFaceIDUsageDescription`
- Die App schreibt nicht in Health, deshalb ist
  `NSHealthUpdateUsageDescription` bewusst nicht gesetzt.
- HealthKit-Daten dürfen laut Apple nicht für Werbung genutzt und nicht ohne
  Zustimmung weitergegeben werden – beides findet nicht statt.

## Verschlüsselung (Export Compliance)

In der Info.plist steht `ITSAppUsesNonExemptEncryption = false`. Damit
entfällt die Frage bei jedem Upload. Das ist korrekt, weil die App keine
eigene Verschlüsselung verwendet und keine Netzverbindungen aufbaut.
