# hero pet 🐾

An internal front-desk management system for a veterinary clinic — runs entirely **Offline** on an Android tablet (Honor Pad).

Built with Flutter + Dart + SQLite (sqflite), English LTR interface, official color dark green.

> ⚠️ This app does **not** record diagnoses, treatment, medication, or lab results — it only organizes front-desk operations (clients, pets, appointments, boarding, procedures, visits).

---

## Latest Updates (main changes from the original version)

- **Home screen**: a long mobile-width search bar at the top + reminders bell (left) + only 3 icons
  (add client / appointments / hotel), with a **Dashboard** directly below the icons showing:
  latest clients, latest hotel check-ins, latest hotel check-outs — each section has a "view all" button.
- **Removed** the standalone "add pet to existing client" screen entirely (search + client profile now cover this).
- **Appointments**: a unified list of all upcoming appointments + add/edit/delete, and the appointment
  type is now a fixed choice (vaccination / medical procedure) instead of free text.
- **Reminders**: 3 tabs — upcoming appointments, today's check-outs, **overdue check-outs**.
- **Hotel/Boarding**: a unified section with three cards (check-in / currently present / check-out), and the
  status type at check-in is now a single choice (regular boarding / medical boarding / medical procedure) with the same fields.
  Check-out always ends with a unified **"delivered"** status, and cannot be completed without a photo of the pickup receipt.
- **Notes during stay**: from the "currently present" screen, you can open any pet and add/edit/delete
  dated notes without this being counted as a check-out (new `AdmissionNotes` table).
- **Overdue system**: any pet whose expected check-out date has passed today's date is considered
  **"overdue for check-out"** and is clearly highlighted (in red) on: the dashboard, the currently-present screen, and the
  reminders screen (with the number of overdue days). It disappears automatically once the actual check-out is recorded.
- **Client profile**: quick action buttons (add pet / clinic visit / appointment / hotel check-in)
  save time without returning to the home screen, and each pet's profile now shows all contracts (with thumbnail
  images that can be enlarged), all notes, and all appointments.
- **Clinic visit**: an optional "add upcoming appointment" option automatically creates an appointment (follow-up/vaccination/
  medical procedure/other) that appears immediately on both the appointments and reminders screens.
- The app's display name was changed to **hero pet** (lowercase) throughout the interface.

## 1) Project Structure

```
hero_pet/
  lib/
    core/            # Colors, theme, constants
    models/           # Client, Pet, Visit, Appointment, Reminder, Admission, AdmissionNote
    database/         # db_helper.dart (all SQLite operations)
    utils/            # Helpers: images, WhatsApp, dates
    widgets/          # Shared UI components
    screens/
      home_screen.dart          # Home screen + dashboard
      dashboard/                 # Dashboard sections and "view all" screens
      client/                    # Add client + full client profile + quick actions
      pet/                       # Add pet + post-add options + pet profile
      hotel/                     # Unified hotel/boarding section (check-in/present/check-out/notes)
      clinic/                    # Clinic visit (with option to add upcoming appointment)
      appointments/              # Appointments (unified list + add/edit/delete)
      reminders/                 # Reminders (upcoming appointments / today's check-outs / overdue)
      backup/                    # Backup / restore
  setup_reference/
    AndroidManifest_reference.xml   # Camera permission to add after flutter create
  pubspec.yaml
```

## 2) Database (SQLite) — Version 3

Tables: `Clients, Pets, Visits, Appointments, Reminders, Admissions, AdmissionNotes`.
**Phone number (`phone`) is the primary key** used to look up a client.

- `Clients.created_at`: added in version 3 (date the client was added, used in the dashboard).
- `AdmissionNotes`: added in version 2 (dated notes while a pet is present).
- Upgrades between versions happen automatically via `onUpgrade` **without losing any existing data**.

The `Admissions` table unifies "hotel/boarding" and "medical procedure" via a `type` field
(`hotel` or `procedure`), with a `status` field that determines the pet's state:

- `normal` (no current procedure)
- `present in hotel` or `present in clinic` (currently active)
- `delivered` (the unified final status at check-out, for all types)

"Overdue for check-out" is **not** a stored field — it is computed directly by comparing
`expected_exit_date` to today's date for any admission that is still active.

---

## 3) How to Run the Project (one-time setup)

### Requirements
- Install [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable channel)
- Install Android Studio (for the Android SDK + accepting licenses)
- A Honor Pad device connected to the computer via USB with **Developer Mode + USB Debugging** enabled,
  or an Android emulator

### Steps

```bash
# 1) Unzip the project then enter the folder
cd hero_pet

# 2) This project contains Dart code only (lib/ + pubspec.yaml)
#    Run the following command to auto-generate the platform folders (android/ios/...):
flutter create .

# 3) During this, Flutter will ask whether to overwrite some files — choose "yes" only
#    for files you did not create yourself (it will not touch the lib/ folder or the pubspec.yaml we created)

# 4) Add the camera permission to android/app/src/main/AndroidManifest.xml
#    (copy the following two lines inside <manifest> as shown in
#    setup_reference/AndroidManifest_reference.xml):
#    <uses-permission android:name="android.permission.CAMERA" />
#    <uses-feature android:name="android.hardware.camera" android:required="false" />

# 5) Download the packages
flutter pub get

# 6) Make sure the device is connected
flutter devices

# 7) Run the app directly on the device (Debug mode for testing)
flutter run
```

> 💡 If the device already has a previous version of the app installed (before these updates),
> its database will be upgraded automatically on first launch without losing any data (clients,
> pets, appointments, hotel records... all remain intact).

## 4) Building a Final APK Ready to Install on the Honor Pad

```bash
flutter build apk --release
```

The APK file will appear at:

```
build/app/outputs/flutter-apk/app-release.apk
```

Copy this file to the Honor Pad tablet (via USB, SD card, or Bluetooth), then:

1. From the device settings, enable **"Allow installing apps from unknown sources"**
   (Install unknown apps) for the file manager app you'll use to open the APK.
2. Open the `app-release.apk` file from the file manager and tap install.

> 💡 If you want to reduce the file size based on processor architecture only, use:
> `flutter build apk --release --split-per-abi`

---

## 5) Important Technical Notes

- **Images (contracts/pet photos)**: stored inside the app's own data folder
  (`ApplicationDocumentsDirectory/images/`), and only the **path** is stored in SQLite — fully offline.
- **Database**: a single file `hero_pet.db` inside the same app data folder.
- **Backup**: available from the icon at the top-right of the home screen. The current version backs up
  the database file only and does not automatically include the images folder; this can be extended later to
  compress (zip) the `images/` folder together with the file if desired.
- **WhatsApp**: the "Send via WhatsApp" button opens the conversation with a pre-filled message, and the staff member taps "send"
  themselves (there is no automatic sending). The `whatsapp://send` link automatically opens whichever version is installed
  (regular or Business) — if both apps are installed together, it's the Android system that shows the
  selection menu (system behavior, the app cannot force either one).
- **Extensibility**: a clear separation between `models`, `database`, and `screens` to make it easier to add features
  in the future (printing, Excel export, cloud sync when internet becomes available later, etc.).

---

## 6) Why Isn't a Ready-Made APK File Included Directly?

Generating an APK requires the Flutter SDK + Android SDK and build tools (Gradle) along with an internet
connection to download dependencies — these are not available in the current generation environment. Therefore, all
**the source code has been fully prepared and is ready to run and build directly** with a single command (`flutter build apk --release`)
once Flutter is installed on any computer, as shown in the steps above.
