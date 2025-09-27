# Traveleks (offline) - Starter Flutter Project

This archive contains a minimal offline Flutter starter project for **Traveleks** — a small CRM for travel agents.
It stores data locally using `sqflite` and includes a ready `lib/main.dart` with the core functionality:
- Create bookings
- Store operator and booking data locally
- Record payments
- Simple UI (dashboard, create booking, booking details)
- Manual input of operator rate for each booking

## Files in this archive
- `pubspec.yaml` - dependencies
- `lib/main.dart` - full single-file Flutter app (paste into your project's lib/)
- `design/mockup.png` - UI mockup image

## How to run
1. Install Flutter SDK and set up Android/iOS toolchains.
2. Create a new Flutter project or use this folder:
   ```bash
   flutter create traveleks_offline
   cd traveleks_offline
   ```
3. Replace the generated `pubspec.yaml` with this archive's `pubspec.yaml` (or merge dependencies), then run:
   ```bash
   flutter pub get
   ```
4. Replace `lib/main.dart` with the provided `lib/main.dart`.
5. Run on device/emulator:
   ```bash
   flutter run
   ```

## Notes
- This is an offline, single-user starter. If you later want cloud sync, push notifications, or PDF export — I can add them.
- Make backups of the local DB file located in app's databases path.

Enjoy — if you want, I can now split `main.dart` into multiple files and produce a full project structure (models, db_helper, screens) and re-package as a zip.
