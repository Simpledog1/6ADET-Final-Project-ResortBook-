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

**Verification status (added October 2026):** the PocketBase test above was a one-record fetch from a local server. It was not a full set of CRUD operations, and the date-overlap validation listed as "in progress" was finished in Week 2 of the finals reports below.

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
* Drafted the required `README.md` documentation and `SECURITY-CHECKLIST.md`. (The security checklist is now `docs/06-security-and-privacy.md`; there is no `SECURITY-CHECKLIST.md` file in the repository any more.)

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

**Verification status (added October 2026):** nothing from this week was compiled or run. I could not install Flutter, so the theme, spacing and folder structure were written but untested until Week 2. I had no screenshots and no test results to show for this week.

**What I would do differently (added October 2026):**

* Treat the toolchain as the first task, not a background task. Before writing any code, confirm that `flutter --version` and `flutter doctor` work. Record the exact Flutter and Dart versions in the README (this project now lists Flutter 3.47.5 and Dart 3.13.4 in `docs/08-setup-and-troubleshooting.md`).
* Download the big files (Flutter SDK, PocketBase, Visual Studio) on a better connection, such as a phone hotspot or another network, as soon as the connection fails, instead of waiting for the home Wi-Fi to recover.
* Keep the offline work useful. While I had no network I wrote UI code that I could not run. A better use of that time would have been work that does not need a server: the pure Dart booking rules and their tests, the data model classes written against the planned PocketBase fields, the screen layouts at fixed widths, and the documentation.
* Write down the PocketBase collection names and field types in the README at the same time as the models, then check the models against the real collections once the server runs. I later added `test/schema_models_test.dart` for this.

## Week 2: Finals, September 27, 2026

**What changed this week**
* Restored the project scope back to cross-platform, explicitly supporting both mobile (393 × 852 px) and desktop (1440 × 1024 px) viewports.
* Completed Phase 2 (PocketBase Connection): Successfully configured the local database on the G: drive, created the `rooms` and `reservations` collections with relational mapping, and built the corresponding Dart models.
* Completed Phase 3 (Dashboard): Built the responsive dashboard UI using `LayoutBuilder` to automatically switch between a mobile `BottomNavigationBar` and a desktop `NavigationRail`.
* Completed Phase 4 (Add Reservation): Created the form for capturing guest details and schedules, and wired up the database write operations.
* Implemented the client-side date-overlap validation logic to actively prevent conflicting room bookings.
* Configured native Windows desktop compilation by installing the Visual Studio C++ toolchain to bypass web browser file system restrictions.
* Integrated `device_preview_screenshot` to export automated, accurately framed cross-platform documentation assets directly to the local drive.

**Why**
* Restoring the cross-platform scope ensures the application fulfills the original requirements, utilizing `DevicePreview` to verify both Windows desktop and mobile layouts simultaneously.
* The client-side date validation is a critical business rule; blocking the database write entirely when `(New Check-In < Existing Check-Out) AND (New Check-Out > Existing Check-In)` prevents the need for complex server-side rollbacks.
* Relying on PocketBase's native Relation field for the `assignedRoomId` handled the database constraints automatically, avoiding manual SQL foreign key errors.
* Compiling to native Windows was mandatory because running the app in a web browser sandbox completely blocked the `dart:io` operations required to save screenshot files.

**Correction (added October 2026):** the sentence above says client-side validation "prevents the need for complex server-side rollbacks". That is too strong. The check only runs inside the Flutter app. A request that does not go through the app, or two people saving at the same moment, can still create overlapping bookings, and PocketBase does not check. I confirmed on a copy of the database that the server accepts an overlapping booking sent directly to its API. See `docs/09-reservations-and-data-integrity.md`.

**What broke or what I got stuck on**
* Encountered an architecture mismatch during the initial PocketBase setup. I originally downloaded the `arm64` executable, which Windows 11 blocked from running on my AMD Ryzen (x64) processor. I resolved this by deleting the directory and running the correct `amd64` executable from the command prompt.
* Briefly hit a compilation error when extracting the `DashboardContent` widget because it was accidentally placed inside the state class, but this was quickly fixed by moving it to the root file level.
* Received a `Platform._operatingSystem` unsupported error and a missing Visual Studio toolchain error when trying to export screenshots. I had to stop development to download and install the 5GB+ Visual Studio 2022 C++ compiler and enable Windows Developer Mode to fix it.
* Encountered a Git `Permission denied` error when trying to commit my work because background cache files in the newly generated `.vs/` folder were locked. I fixed this by adding `.vs/` to the `.gitignore` file.

**How to avoid these blockers next time (added October 2026):**

* Check the processor type before downloading a native tool: `$env:PROCESSOR_ARCHITECTURE` on Windows (`AMD64` needs the `amd64` build) or `uname -m` on Linux and macOS. Check the downloaded file size against the release page.
* Run `flutter doctor -v` and read the Flutter and Dart versions before starting, and install the Visual Studio C++ workload early if a Windows desktop target is planned.
* Create `.gitignore` before the first commit and include `.vs/`, `.dart_tool/`, `build/`, `.env` files and the database folder. Run `git status` before each commit so generated files are noticed early.
* Write the overlap function and its boundary tests first (back-to-back bookings, one-minute overlap, cancelled bookings), then build the screen on top of it.

**What is left**
* Phase 5: Building the searchable Reservation List screen to replace the current placeholder widget and display the live data from PocketBase.
* Phase 6: Creating the Reservation Details view to show expanded information and status badges.
* Phase 7: Building the visual Calendar interface to map reservations to specific dates.
* Phases 8 & 9: Final end-to-end integration testing and viewport padding cleanup.

## Week 3: Finals, October 5, 2026

### What changed this week

* Completed the remaining core ResortBook screens, including the Reservation List, Reservation Details, and Calendar.
* Generalized the reservation system from a room-only design into a configurable resort inventory system supporting different unit types such as rooms, cottages, villas, and other resort facilities.
* Expanded the PocketBase database structure with configurable unit types, units, stay types, and rates.
* Implemented reservation availability validation, including date and time overlap checking, capacity validation, cancelled-reservation handling, and back-to-back reservations.
* Implemented dynamic pricing based on unit type and stay type, including overnight, day tour, night tour, and multiple-night reservations.
* Completed the responsive desktop application shell and redesigned the desktop Dashboard, Reservation List, Reservation Details, Calendar, Add Reservation, and resort management screens.
* Added resort management features for configuring unit types, units, stay types, and rates.
* Implemented reservation management workflows for Reserved, Checked In, Completed, and Cancelled statuses, including editing, cancelling, restoring, and availability checks.
* Added reservation pagination, sorting, search, status indicators, calendar visualization, dashboard statistics, and synchronized updates between reservation screens.
* Completed final QA and release-readiness improvements, including friendly error messages, responsive layout testing, cleanup of obsolete code, updated documentation, and additional automated tests.
* Successfully completed the final automated test suite with **184 tests passing** and `flutter analyze` reporting **no issues**. (On October 9, 2026 the suite has 276 tests, all passing. It grew with the sign-in, sign-up, boundary and schema tests, see `docs/10-testing-and-verification.md`.)

### Why

* Generalizing the database and reservation system makes ResortBook useful for different types of resorts instead of limiting it to a single room-based setup.
* Configurable stay types and rates allow resorts to support different booking schedules and pricing models without changing the application code.
* Reservation status workflows provide a more realistic front-desk process from booking through check-in and completion.
* The responsive desktop and mobile layouts ensure the application can be used across different screen sizes while maintaining the intended Figma design.
* Automated testing was expanded to catch reservation, pricing, calendar, responsive layout, and management-related issues before final submission.

### What broke or what I got stuck on

* Encountered several integration and UI issues while connecting the reservation screens to the generalized PocketBase structure.
* Had to resolve date and time handling issues when storing reservation schedules in PocketBase, particularly for cross-midnight and multi-day reservations.
* Encountered UI testing issues with the desktop reservation pagination because the pagination controls were initially outside the widget test viewport. The test was corrected without changing the actual application behavior.
* Encountered various responsive layout and desktop UI issues during the final polish phase and adjusted the implementation while preserving the mobile and desktop designs.
* The Flutter test suite also produced a PocketBase connection error message during one dashboard widget test because the test environment did not have the expected local backend data, but the test itself continued successfully and the complete suite ultimately passed.

### What is left

* Complete the final documentation and demonstration materials.
* Record and prepare the final project demonstration video.
* Perform any final visual checks against the Figma mockups.
* Prepare the final GitHub repository and project submission.
* Make any minor fixes discovered during the final demonstration or submission review.

### Verification status (added October 2026)

* Checked by running the app (web version, current code): sign-in and sign-up, the dashboard, reservation list, calendar, Manage Resort screens at phone and desktop widths, and the conflict message on Add Reservation.
* Checked only by automated tests (not run by hand in these sessions): saving a reservation, Reservation Details actions, Edit, Check In, Complete, Cancel and Restore.
* Not checked: Android and iOS, and any test against a real PocketBase from inside `flutter test`.
* Known gap: the overlap check lives in the app only. A direct API request can still create a double booking, and two people saving at the same moment are not protected. This is described in `docs/09-reservations-and-data-integrity.md`.

### Hours spent, roughly:

* 15 hours

### Next week I will:

* Finalize the project documentation and demonstration video.
* Perform the final end-to-end demonstration of the reservation workflow.
* Verify the final mobile and desktop layouts.
* Review the GitHub repository for unnecessary files and unfinished documentation.
* Complete the final project submission.

## Reflection and plan (added October 9, 2026)

### What I would do differently

* Fix the environment first and write it down: exact Flutter and Dart versions, the right PocketBase build for the processor, and `.gitignore` before the first commit.
* Do not claim something works until I have run it. Several early entries describe features as "completed" without saying whether they were run or only written. The documentation now says "verified (live)", "verified (test)" or "not verified".
* Write the overlap rule and its boundary tests before the screens, and decide at the start whether the rule must also be enforced by the server.

### How to keep working when the network is down

* Business rules in plain Dart and their unit tests (`booking_logic`, `reservation_workflow`, and so on). These need no server.
* Widget tests with a fake data source, and checking layouts at phone and desktop widths.
* Data models and the schema file, checked against each other (`schema_models_test.dart`).
* Documentation, wireframes and the demo video script.
* Downloads that can wait for another network: SDKs, PocketBase and Visual Studio (see `docs/08-setup-and-troubleshooting.md`).

### Priority order for unfinished work

If the deadline gets tight, I would finish in this order, and drop from the bottom:

1. Add Reservation with the overlap check, the reservation list and Reservation Details (the core reservation workflow).
2. The calendar view.
3. Manage Resort (unit types, units, stay types, rates), because the booking form needs it.
4. A test run, a demo video and the README (graded work that is not code).
5. The desktop layout polish: sortable tables, paging, dashboard statistics.
6. Check In, Complete and Restore workflows.
7. Sign-in, hosting the database online and the public demo.
8. Stretch goals: PDF receipts, real-time sync (already out of scope in the proposal).

Items 5 to 8 are the first to postpone. Items 1 to 4 are not negotiable.