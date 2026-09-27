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

## Week 2: Finals, September 27, 2026

**What changed this week**
* Restored the project scope back to cross-platform, explicitly supporting both mobile (393 × 852 px) and desktop (1440 × 1024 px) viewports.
* Completed Phase 2 (PocketBase Connection): Successfully configured the local database on the G: drive, created the `rooms` and `reservations` collections with relational mapping, and built the corresponding Dart models.
* Completed Phase 3 (Dashboard): Built the responsive dashboard UI using `LayoutBuilder` to automatically switch between a mobile `BottomNavigationBar` and a desktop `NavigationRail`.
* Completed Phase 4 (Add Reservation): Created the form for capturing guest details and schedules, and wired up the database write operations.
* Implemented the client-side date-overlap validation logic to actively prevent conflicting room bookings.

**Why**
* Restoring the cross-platform scope ensures the application fulfills the original requirements, utilizing `DevicePreview` to verify both Windows desktop and mobile layouts simultaneously.
* The client-side date validation is a critical business rule; blocking the database write entirely when `(New Check-In < Existing Check-Out) AND (New Check-Out > Existing Check-In)` prevents the need for complex server-side rollbacks.
* Relying on PocketBase's native Relation field for the `assignedRoomId` handled the database constraints automatically, avoiding manual SQL foreign key errors.

**What broke or what I got stuck on**
* Encountered an architecture mismatch during the initial PocketBase setup. I originally downloaded the `arm64` executable, which Windows 11 blocked from running on my AMD Ryzen (x64) processor. I resolved this by deleting the directory and running the correct `amd64` executable from the command prompt.
* Briefly hit a compilation error when extracting the `DashboardContent` widget because it was accidentally placed inside the state class, but this was quickly fixed by moving it to the root file level.

**What is left**
* Phase 5: Building the searchable Reservation List screen to replace the current placeholder widget and display the live data from PocketBase.
* Phase 6: Creating the Reservation Details view to show expanded information and status badges.
* Phase 7: Building the visual Calendar interface to map reservations to specific dates.
* Phases 8 & 9: Final end-to-end integration testing and viewport padding cleanup.

