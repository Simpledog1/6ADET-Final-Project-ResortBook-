# ResortBook Documentation Update

## 1. Overview
ResortBook is a cross-platform (mobile and desktop) front-desk reservation management application built with Flutter. It is designed specifically for internal managers and staff at small-to-medium independent resorts to accurately track room inventory and active guest bookings, replacing error-prone paper logbooks.

## 2. Setup and installation
To set up this project locally from scratch:

* **Requirements:** Built using the Flutter Stable channel on a Windows 11 development environment (x64 architecture).
* **Get the code:** Clone this repository to your local machine using `git clone <your-repository-url>`.
* **Install dependencies:** Navigate into the project folder and run `flutter pub get`.
* **Database Configuration:** This application requires a local PocketBase backend. 
  1. Download the `windows_amd64.zip` executable from PocketBase.
  2. Extract it (e.g., to your G: drive) and run `.\pocketbase serve` in PowerShell.
  3. Ensure the server is running at `http://127.0.0.1:8090`.
  4. Create the `rooms` and `reservations` collections and set their API rules to public/unlocked for local testing.

## 3. How to run it
Ensure your PocketBase server is running in a background terminal before launching the Flutter app. 

Run the following command in your terminal:
`flutter run`

**What you should see:** The app will launch with the `DevicePreview` wrapper active, allowing you to instantly toggle between mobile and desktop viewport constraints. It will boot directly into the responsive Dashboard screen, displaying your active database records in a dynamic grid alongside either a Bottom Navigation Bar (mobile) or a side Navigation Rail (desktop). 

## 4. Features and usage
Currently, the application contains the core visual architecture, database connection, and primary reservation flow.

* **Design System Engine:** The app globally enforces a custom Material 3 light theme (seeded with #1E3A8A), specific type scales, and an 8px base spacing system to ensure uniform component padding.
* **Responsive Layout:** The application utilizes `LayoutBuilder` to dynamically adapt the UI structure based on the active screen width.
* **Add Reservation & Validation:** Users can assign rooms and select dates. The form includes strict client-side validation logic that queries existing database records and actively blocks submission if the selected dates overlap with an existing booking: `(New Check-In < Existing Check-Out) AND (New Check-Out > Existing Check-In)`.
* **Database Sync:** Successfully connected to the local PocketBase backend using the Dart SDK.

## 5. Project structure
The `lib/` directory is structured to support the cross-platform architecture and separation of concerns:

* `lib/main.dart` — The application entry point that initializes the app, `DevicePreview`, and global theme.
* `lib/theme/app_theme.dart` — Contains the Material 3 ColorScheme and TextTheme configurations.
* `lib/theme/app_spacing.dart` — Holds the strict 8px-based spacing constants used for margins and padding.
* `lib/models/` — Contains Dart data models mapping to the database (`room.dart`, `reservation.dart`).
* `lib/screens/` — Contains the active UI screens (`dashboard_screen.dart`, `add_reservation_screen.dart`), alongside placeholders for upcoming phases.
* `lib/services/` — Contains `pocketbase_service.dart` for handling the backend connection logic.
* `lib/widgets/` — *(Prepared)* Will hold reusable UI components like the Reservation Card and Status Badge.

## 6. Screenshots
![Mobile Dashboard](docs/assets/Documentation%20Screenshots/mobile_dashboard.png)
![Mobile Validation](docs/assets/Documentation%20Screenshots/mobile_add_reservation_validation.png)
![Desktop Dashboard](docs/assets/Documentation%20Screenshots/desktop_dashboard.png)
![Desktop Validation](docs/assets/Documentation%20Screenshots/desktop_add_reservation_validation.png)


## 7. Known issues and next steps
* **Known Issues:** The "List" and "Calendar" tabs currently display empty placeholder text, as their respective UI screens have not yet been built.
* **Next Steps:** The immediate next step is Phase 5: replacing the placeholder text with the actual searchable `Reservation List` screen to display live data from PocketBase. Following that, we will build the `Reservation Details` view (Phase 6) and the visual `Calendar` interface (Phase 7).
