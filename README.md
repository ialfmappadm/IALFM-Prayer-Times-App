<<<<<<< HEAD
# IALFM-Prayer-Times-App
Public Git Repo for IALFM Prayer Times App
=======

# Prayer Times App (Flutter)

A minimal Flutter app that displays daily prayer times for 2026 and shows a live countdown to the next Adhan, using Central Time (America/Chicago).

## Prerequisites
- Flutter SDK installed (`flutter doctor` should pass)
- Android Studio or VS Code with Flutter/Dart extensions

## Setup
1. Create a Flutter skeleton (Android/iOS folders):
   ```bash
   flutter create prayer_times_app
   ```
2. Replace the generated `lib/` and `pubspec.yaml` with the ones in this folder, and copy the `assets/` directory.
   - Or simply copy everything from this `prayer_times_app` directory into the project created in step 1 (overwriting files).

3. Get packages:
   ```bash
   cd prayer_times_app
   flutter pub get
   ```

4. Run the app (Android emulator or device):
   ```bash
   flutter run
   ```

## Notes
- The time zone is fixed to America/Chicago via the `timezone` package, so DST transitions are handled automatically.
- JSON data is at `assets/data/prayer_times_2026.json`.
- UI is intentionally basic; you can style it later to match your PNG.

## Structure
```
prayer_times_app/
  lib/
    main.dart
    models.dart
    time_utils.dart
    pages/
      prayer_page.dart
  assets/
    data/
      prayer_times_2026.json
  pubspec.yaml
  README.md
```
>>>>>>> e382671 (Stable build before adding Firebase Messaging)
Test push after clean setup
