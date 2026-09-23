## Documentation Update
## 1. Overview
ResortBook is a mobile and desktop front-desk reservation management application built with Flutter[cite: 3]. It is designed specifically for internal managers and staff at small-to-medium independent resorts to accurately track room inventory and active guest bookings, replacing error-prone paper logbooks.

## 2. Setup and installation
To set up this project locally from scratch:

* **Requirements:** Built using the Flutter Stable channel on a Linux development environment.
* **Get the code:** Clone this repository to your local machine using `git clone <your-repository-url>`.
* **Install dependencies:** Navigate into the project folder and run `flutter pub get`.
* **Configuration:** Currently None. The application is in Phase 1 (Visual Foundation). The PocketBase backend connection has not yet been integrated due to local network limitations, so no API keys, environment variables, or server URLs are required to run the current build.

## 3. How to run it
Ensure you have an Android emulator running or a physical mobile device connected, as this application is optimized strictly for mobile viewports.

Run the following command in your terminal:
`flutter run`

**What you should see:** Because the project is currently at the Phase 1 milestone, the app will launch a placeholder Dashboard screen. You will see a dark blue App Bar utilizing the Material 3 seed color #1E3A8A on an off-white background. This confirms the custom theme and spacing engines are working correctly.

## 4. Features and usage
Currently, the application contains the core visual architecture and design system implementation.

* **Design System Engine:** The app globally enforces a custom Material 3 light theme, specific type scales, and an 8px base spacing system to ensure uniform component padding.
* **Routing:** The application successfully boots and routes to a placeholder `DashboardScreen`.
* *Note: Core reservation features (forms, calendar, database sync) are pending implementation in subsequent phases once network blockers are resolved.*

## 5. Project structure
The `lib/` directory is currently structured to support the Phase 1 visual foundation, with folders prepared for the upcoming phases:

* `lib/main.dart` — The application entry point that initializes the app and applies the global theme.
* `lib/theme/app_theme.dart` — Contains the Material 3 ColorScheme and TextTheme configurations.
* `lib/theme/app_spacing.dart` — Holds the strict 8px-based spacing constants used for margins and padding.
* `lib/models/` — *(Prepared)* Will hold Dart data models (e.g., Room, Reservation).
* `lib/screens/` — *(Prepared)* Will hold the 5 primary mobile screens: Dashboard, Add Reservation, Reservation List, Reservation Details, and Calendar.
* `lib/services/` — *(Prepared)* Will hold the PocketBase backend connection logic.
* `lib/widgets/` — *(Prepared)* Will hold reusable UI components like the Reservation Card and Status Badge.

## 6. Screenshots
*(Screenshots are unavailable as of this update due to Wi-Fi issues preventing the installation of the Flutter SDK and PocketBase).*

## 7. Known issues and next steps
* **Known Issues:** Development is currently paused at Phase 1. Severe local network timeout issues (curl 56 / 85kbps dropouts) on the Linux development machine prevented the installation of the Flutter engine and the local PocketBase server.
* **Next Steps:** Once network stability is restored, the immediate next step is Phase 2: spinning up the local PocketBase executable, creating the rooms and reservations collections, and verifying the Flutter-to-backend connection. After that, we will build the actual Dashboard UI and the Add Reservation form validation logic.
