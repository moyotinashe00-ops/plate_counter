# PlateCount (Flutter)

Mobile/web/desktop client for the PlateCount backend.

## Setup
```bash
flutter create . --project-name platecount   # generates android/ios/web platform folders
flutter pub get
flutter run --dart-define=API_URL=http://10.0.2.2:4000   # Android emulator
# iOS simulator / web / desktop: --dart-define=API_URL=http://localhost:4000
```
Start the backend first (see platecount-backend/README.md).
On Android add `android:usesCleartextTraffic="true"` to the `<application>` tag in
AndroidManifest.xml when using a plain http:// backend during development.

## Screens
- Welcome & sign in / create account (first account = chef)
- Serve: one-tap plate sales, quantity sheet, sold-out/low badges, your sales today
- Stock (chef): add/edit food, prepared more, corrections, low-stock alerts
- Change & credit: money owed to/by customers, mark given/repaid, chef toggle for credit
- Today (chef): revenue, change & credit owed, sales by item, stock, cashier activity
- Reports (chef): date range, totals, per-item, per-staff, void sales, CSV copy
- Team (chef): promote/demote chef & cashier
