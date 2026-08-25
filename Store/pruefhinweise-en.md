# App Review Notes — Mein Blutdruck

*(Paste into App Store Connect → App Review Information → Notes)*

## What the app does

Mein Blutdruck reads blood pressure, heart rate, body mass and body fat
percentage from Apple Health (read-only) and shows them as statistics and
charts: 24-hour profile, time-of-day sections, long-term trend, and a PDF
report. All processing happens on device. No servers, no accounts, no
analytics, no advertising. Nothing is written back to HealthKit.

The user interface is in German only. The app is intended for the German
market.

## How to test — important

The app has no data of its own. It only displays what is already stored in
Apple Health. On a fresh device Health is empty, so the app will show its
empty state.

To see the app with data:

1. Open the app and tap **„Health-Zugriff erlauben"** (Allow Health access).
2. In Apple's authorization sheet, **scroll down to the section
   „darf Daten lesen" (allow to read)** and enable all switches, then tap
   **„Erlauben"**. The read section is below the fold — if it is skipped,
   the app receives no data by design of HealthKit.
3. If Health contains no blood pressure values, add a few manually:
   Health app → Durchsuchen (Browse) → Herz (Heart) → Blutdruck (Blood
   Pressure) → Hinzufügen (Add). Three or four entries on different days
   and times are enough to populate every chart.
4. Back in Mein Blutdruck, tap **„Erneut aus Health laden"**.

If the authorization sheet does not appear, it has already been answered
once. It can then only be changed in the Health app: profile picture →
Datenschutz (Privacy) → Apps → Mein Blutdruck.

## Health data usage

- Read-only access to: blood pressure systolic/diastolic, heart rate,
  body mass, body fat percentage.
- Data is used solely to display statistics to the user.
- No health data is transmitted off the device, stored in iCloud, used for
  advertising, or shared with third parties.
- The PDF report and the diagnostics log are only created and shared when
  the user explicitly taps the corresponding button.

## Not a medical device

The app states clearly on first launch — with a mandatory confirmation —
and in its settings and footer that it is not a medical device, does not
diagnose, treat or cure any disease, and does not replace medical advice.
Thresholds (default 135/85 mmHg for home measurement) are configurable and
labelled as reference values, not as a diagnosis.

## Privacy policy

https://eifelmono.github.io/MeinBlutdruck/datenschutz.html

## Sign-in

No account, no login, no demo credentials needed.
