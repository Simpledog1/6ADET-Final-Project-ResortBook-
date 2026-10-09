# Testing and verification

What was tested, what the results were, and what is **not** verified. Dates are when I ran things. Nothing here is copied from reading the source alone: where a result comes only from reading the code, it says so.

## Automated tests

Run from the project folder:

```bash
flutter analyze
flutter test
```

Result on 2026-10-09 (Flutter 3.47.5, Dart 3.13.4, Windows 10):

- `flutter analyze`: **No issues found**
- `flutter test`: **276 tests, all passed**

(The Week 3 report says 184 tests passed on October 5. The suite grew when I added sign-in, sign-up, boundary and schema tests.)

| Test file | What it covers |
| --- | --- |
| `booking_logic_test.dart`, `overlap_boundary_test.dart` | Stay windows, overlap rule and its boundaries, pricing, guest count against capacity |
| `reservation_workflow_test.dart`, `reservation_details_actions_test.dart`, `edit_reservation_test.dart` | Status changes, Edit, Cancel, Restore, and the conflict check on edit and restore |
| `calendar_logic_test.dart`, `reservation_stats_test.dart` | Which bookings appear on which day, dashboard numbers, sorting and paging |
| `configurable_stays_test.dart`, `stay_duration_test.dart`, `config_rules_test.dart`, `manage_units_test.dart`, `manage_delete_test.dart` | Manage Resort rules: stay-type durations, validation, safe delete |
| `reservation_screens_test.dart`, `widget_test.dart`, `admin_table_test.dart` | Dashboard, Reservation List and Calendar screens at phone and desktop widths, including "no overflow" checks at 1024, 1280 and 1440 px |
| `auth_test.dart`, `account_rules_test.dart` | Sign in, sign up, validation, sign out, session restore |
| `schema_models_test.dart` | Field names used by the code exist in `pocketbase/pb_schema.json` with a compatible type |

What these tests **do not** cover:

- They use a fake data source, so **no test talks to a real PocketBase**. Server behaviour (API rules, the overlap check on the server) is not covered by `flutter test`.
- No test checks the Windows desktop build, Android or iOS.
- The tests do not check how the app looks. For that, use the checks below.
- On the day I wrote the Week 3 report, one test printed a PocketBase connection error and still passed. That message comes from a screen reaching the real client in the test environment, and it is not a failing test.

## Backend integration test (PocketBase)

The Flutter tests above use a fake data source, so they cannot prove anything about the server. The double-booking check on the server has its own test, `pocketbase/tests/run-overlap-tests.ps1`. It runs a throwaway PocketBase with the real schema and hooks, and sends real API requests, including simultaneous ones.

On 2026-10-09 it gave **22 of 22 passed** (run twice) with the hook. **Without** the hook, it gave 12 passed and 10 failed, which shows the test really detects double bookings. The same file is deployed on the online PocketBase. On 2026-10-10, live checks against it passed 16 of 16, including simultaneous requests. Details are in [09-reservations-and-data-integrity.md](09-reservations-and-data-integrity.md#5-server-side-double-booking-check).

## What you should see

Each row says how to look at it yourself and what is expected. The last column says how I know. **Live** means I ran the web version of the current code in Chrome on 2026-10-06 or 2026-10-09 against PocketBase 0.40.4 (web, not the Windows desktop build). The screenshots are in `docs/assets/App Screenshots/`.

| Feature | Steps | What you should see | Status |
| --- | --- | --- | --- |
| Sign in and sign up | Open the app signed out | Navy sign-in page with email, password, **Sign In** and "Create one". Wrong password shows "Incorrect email or password." Creating an account returns you to Sign In with a green success message. | Live, and tests |
| Session restore | Sign in, reload the page | You stay signed in. After **Sign out** and a reload, you see Sign In. | Live |
| Theme | Look at any screen | Inter font, navy `#1E3A8A` header and buttons, off-white background, white cards | Live (screenshots) |
| Spacing | Compare screens | Consistent 8 px based spacing (`lib/theme/app_spacing.dart`: 4, 8, 16, 24 px) | Seen live; not measured pixel by pixel |
| Responsive layouts | Resize the browser: under 600 px, 600 to 1023 px, 1024 px and above | Phone: single column, dashboard hub, back arrows. Tablet: same screens centred. Desktop: top bar, sidebar, wide tables. | Phone and desktop: live at 375 px and 1366 px; the no-overflow tests also cover 1024, 1280 and 1440 px. **Tablet (600–1023 px): not verified**, live or by test. |
| Dashboard | Open the Dashboard | Desktop: four stat cards, upcoming reservations, recently added, quick actions. Phone: list of upcoming reservations and four buttons (Add Reservation, View Reservations, View Calendar, Manage Resort). | Live |
| Reservation List | Open Reservations | Phone: searchable list with status badges. Desktop: table with status filters. | Live |
| Calendar | Open Calendar | Month view with dots (phone) or bars (desktop) and a panel for the selected day | Live |
| Add Reservation | Fill the form with two guests, Overnight, a unit and dates | Stay window and total price appear. Saving a booking that overlaps shows **Date Conflict Detected** and saves nothing. Saving a free slot shows "Reservation saved" and the total. | Conflict message live (desktop and phone). Successful save live on 2026-10-09 (desktop, against a copy of the database with the server hook). |
| Manage Resort | Open Manage Resort, Unit Types, Units, Stay Types, Rates | Cards or tables for each, with counts and a setup checklist | Live |
| Reservation Details, Edit, Check In, Complete, Cancel, Restore | Open a reservation | Details with action buttons that depend on its status | **Tests only. Not run live in these sessions. Please run them yourself (checklist below).** |
| Windows desktop app | `flutter run -d windows` | Same as the desktop layout, inside a DevicePreview frame in debug | **Not verified by me.** I used it earlier for the screenshot export (Week 2), but did not rerun it for these docs. |
| Online demo | Open the GitHub Pages link and sign in | Sign-in page, then the app with data from the hosted PocketBase | Live on 2026-10-09: signed in with a test account, the app loaded its data from the PocketBase Cloud database. The demo records were added through the API in that signed-in session, so saving through the app's forms online is **not verified**. |

## Screenshots: what is what

**Screenshots of the running app** (`docs/assets/App Screenshots/`). They are used in the README.

- Taken on 2026-10-06 and 2026-10-09 from the current code, at 1366 px (desktop) and 375 px (phone) width, using a copy of my database with made-up guests.
- `desktop-add-reservation-conflict.png` and `mobile-add-reservation-conflict.jpg` show a **real conflict**: Cottage A, Overnight, Nov 11 to Nov 12, blocked because Maria Santos already has Cottage A from Nov 10 to Nov 12.

**Design mockups (not the running app).** The images in `docs/assets/Wireframe screenshots/` and `docs/assets/Design System/` are Figma exports. They show the intended design, and `02-mockup.md` and `03-design-system.md` label them that way.

**Old screenshots from the first version** (`docs/assets/Documentation Screenshots/`). These four files come from the first version of the app (the Week 2 build, when it only had rooms), made with my screenshot export code. They show an **empty** "New Reservation" form with "Assign Room", not a conflict, and they no longer match the app. I kept them because [AI-USAGE.md](../AI-USAGE.md) refers to them as evidence of my screenshot code. Do not use them as evidence of the current app or of the overlap check. Use the two conflict screenshots above instead.

## Still to do by hand

**Run these once and record the results (I did not run them):**

1. Run the checklist in [09-reservations-and-data-integrity.md](09-reservations-and-data-integrity.md#7-manual-test-checklist), at least T2, T3, T6, T7 and T10.
2. Save a valid reservation and note the confirmation message; open it in Reservation Details; use Check In (only possible from the check-in date), Mark Completed, Cancel and Restore.
3. Run `flutter run -d windows` once and confirm the desktop layout and sign-in work.
4. Resize a browser window to about 800 px wide and check the tablet layout.

**Screenshots I could not take, which you may want for the report:**

- A successful save (the "Reservation saved" message).
- Reservation Details on phone and desktop, in Reserved, Cancelled and Completed states.
- A refused Restore (T7 in the checklist).
- The PocketBase admin page showing the six collections.
- A terminal showing `flutter test` passing.

**Known mismatch between the design documents and the code (not changed):** `docs/03-design-system.md` specifies a 48 px button height, but the code uses 56 px (`AppSpacing.buttonHeight` in `lib/theme/app_spacing.dart`). Neither the UI nor the design document was changed.

**Not verified at all:** the tablet layout (600–1023 px), the Android emulator, iOS, macOS and Linux, and whether the hosting service you choose accepts `pb_hooks`.
