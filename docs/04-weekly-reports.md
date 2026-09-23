# Weekly reports

## Midterm Week 1

**Done this week**

* Finalized the ResortBook screen flow and main application screens.
* Completed and reviewed the mobile and desktop mockups in Figma.
* Exported the mockup screens as PNG files and organized them in `docs/assets/`.
* Updated the project documentation for the mockups, wireframes, and screen flow.
* Finalized PocketBase as the application's backend for storing room and reservation data.
* Tested a basic Flutter connection to a locally running PocketBase instance and successfully fetched a record.
* Updated the project proposal to reflect the reduced MVP scope and the selected backend.
* Updated the design system documentation with the color palette, typography, spacing rules, reusable components, and responsive layout rules.

**In progress**

* Implementing the ResortBook screens in Flutter.
* Connecting the Flutter screens to PocketBase.
* Preparing the final visual design-system asset for the documentation.
* Implementing reservation validation and room availability logic.

**Blocked or stuck on**

* Some Flutter screens and backend functionality still need to be connected and tested together.
* Date-range overlap validation still needs to be implemented and tested with existing reservations.

**Decisions made, and why**

* PocketBase was selected instead of Firebase or a purely local database because it provides a lightweight backend with SQLite and real-time capabilities while being easier to set up for the project.
* Real-time multi-device synchronization was moved to a stretch goal so the core reservation system remains achievable within the term.
* Live chat and automated notifications were removed from the MVP because they are not essential to the main reservation-management workflow.
* PDF booking receipt export was kept as a stretch goal because the core application can function without it.

**Hours spent, roughly:**

* 12 hours

**Next week I will:**

* Implement the basic PocketBase CRUD operations.
* Connect the room and reservation screens to the backend.
* Continue testing the main navigation and responsive layouts.
* Start implementing date-range overlap validation.
* Fix any Flutter errors encountered during integration.

## Week 1: Finals, September 23, 2026

**What changed this week**
* Corrected the project scope to focus strictly on a mobile-only application
* Completed Phase 1 (Visual Foundation) by writing the `main.dart` entry point, the Material 3 `app_theme.dart` (seeded with the primary blue #1E3A8A), and the 8px-based `app_spacing.dart`
* Established the core `lib/` folder structure (models, screens, services, theme, widgets).
* Drafted the required `README.md` documentation and `SECURITY-CHECKLIST.md`.

**Why**
* Establishing the theme and spacing engine first ensures the application perfectly matches the Figma design system without having to hardcode colors and padding across every individual screen
* The folder structure prepares the codebase for the core reservation features and database integration.

**What broke or what I got stuck on**
* Severe Wi-Fi issues completely blocked my development environment setup. My network connection kept dropping at 85kbps and timing out (`curl 56` and `early EOF` errors) when trying to clone the Flutter SDK repository to my Linux laptop. 
* Because I couldn't install Flutter or the PocketBase executable, I was stuck writing offline Dart code and couldn't compile the app, run the Android emulator, or generate the required screenshots for the documentation. 

**What is left**
* Successfully downloading and installing Flutter and PocketBase once my Wi-Fi stabilizes.
* Phase 2: Configuring the local PocketBase collections (`rooms` and `reservations`) and establishing the backend connection.
* Phases 3 through 7: Building the actual UI for the 5 core screens (Dashboard, Add Reservation, Reservation List, Reservation Details, and Calendar).
* Implementing the date-overlap validation logic to prevent double-bookings.
