# Proposal

> **Status note (October 2026):** this is the original plan from September, kept as written so the decisions can be traced. The app grew beyond it. The section "Where the project stands now" at the end says what changed, and the README describes the current app. Where the two disagree, the README is right.

## The problem, in one sentence

Small-to-medium independent resorts struggle to manage room inventory, guest records, and reservations accurately, often relying on error-prone paper logbooks or disjointed spreadsheets that can lead to double-bookings and operational friction.

## Who it is for

ResortBook is designed for internal front-desk managers and staff at small independent resorts.

Today, these staff members may manually track room availability using paper desk calendars, record guest contact details in physical logbooks, and use scattered Excel spreadsheets to check historical or upcoming reservations. ResortBook provides a single system for managing rooms, guest information, and reservations.

## Core features

1. **Dashboard Screen**

   * Displays high-level information such as available rooms, active check-ins, and reservation statistics.
   * Uses Flutter widgets such as `Card`, `GridView.builder`, `ListView.builder`, and `FutureBuilder`.

2. **Add Reservation Screen**

   * Allows staff to enter guest information, select a room, and specify check-in and check-out dates.
   * Includes form validation to prevent invalid or conflicting bookings.
   * Uses `Form`, `TextFormField`, `DropdownButtonFormField`, and navigation.

3. **Reservation List Screen**

   * Provides a searchable list of active and historical reservations.
   * Allows staff to quickly find guest and booking information.
   * Uses `ListView.builder`, search filtering, and `Card`.

4. **Reservation Details Screen**

   * Displays detailed information about a selected reservation.
   * Shows guest information, booking dates, assigned room, and reservation status.
   * Uses `Card`, `Text`, `FutureBuilder`, and `Navigator.pop`.

5. **Calendar Screen**

   * Provides a visual overview of reservations across dates.
   * Reservations can be displayed according to their booking status.
   * Uses `TableCalendar` or a custom calendar layout, along with `Card` and `GestureDetector`.

The core version of the application focuses on these five screens so that they can be completed, tested, and demonstrated reliably within the remaining term.

The current screen flow is:

**Dashboard → Add Reservation → Reservation List → Reservation Details → Calendar**

There is no separate Room Management screen in the current application.

## Out of scope, and why

The following features are outside the core scope of the project:

* **Real-time multi-device synchronization:** Although PocketBase provides real-time capabilities, implementing full multi-device synchronization and conflict-resolution logic is outside the core MVP because of the additional backend complexity and development time. It remains a stretch goal.
* **Live chat:** This was included in the preliminary proposal but was removed because it does not directly support the core reservation-management workflow and would require additional development time.
* **Automated notifications:** Automated guest or staff notifications were removed from the MVP to keep the project focused on the essential reservation-management workflow.
* **Guest accounts and online payments:** ResortBook is an internal front-desk management application rather than a guest-facing booking platform.
* **PDF booking receipt export:** PDF confirmation/receipt generation using the `pdf` and `printing` packages is a stretch goal. The core reservation system does not depend on it.
* **Separate Room Management screen:** Room management is not included as a dedicated screen in the current MVP. Room information is still stored in the database because it is needed for room assignment, availability information, and reservations.

## Data the app remembers, and where it is saved

ResortBook uses **PocketBase** as its backend. PocketBase provides a lightweight, self-hosted backend with a built-in SQLite database and real-time capabilities. It can be run locally during development without the heavier configuration required by a full Firebase setup.

The application stores approximately 20–40 room records and around 50–80 reservation records during a typical week of use.

### Room collection

* `id` — String
* `roomNumber` — String
* `type` — String
* `maxCapacity` — int
* `pricePerNight` — double
* `cleaningStatus` — String

These records are stored in the PocketBase **rooms** collection. Although there is no dedicated Room Management screen, this information is still required by the reservation and dashboard features.

### Reservation collection

* `id` — String
* `guestName` — String
* `phone` — String
* `email` — String
* `checkInDate` — DateTime
* `checkOutDate` — DateTime
* `assignedRoomId` — String

These records are stored in the PocketBase **reservations** collection.

### Temporary local state

Temporary form information, such as text input values and selected date-range filters, is kept in the relevant Flutter widget state and does not need to be permanently stored.

A one-hour technical spike was completed using PocketBase. The backend was run locally, connected to a Flutter test application, and successfully used to fetch a basic record.

## Risks

### 1. Backend integration and state management

**Risk:** Connecting the Flutter screens to PocketBase and keeping the displayed room and reservation information synchronized with the backend could introduce implementation issues.

**Mitigation:** Implement basic CRUD operations against PocketBase first and build the screens around those operations.

**First step and target date:** Implement basic CRUD operations against PocketBase by **October 1, 2026**.

### 2. Date-range overlap validation

**Risk:** A new reservation could overlap with an existing reservation for the same room if the date-range validation is implemented incorrectly.

**Mitigation:** Create a helper validation function that compares the proposed check-in/check-out dates against existing reservations before allowing the booking to be submitted.

**First step and target date:** Implement and test the date-range overlap validation helper by **October 5, 2026**.

## Changes since the last version

**September 20, 2026 — Core scope reduced:** The proposal was changed from six major features to five current screens. Real-time multi-device synchronization was moved to a stretch goal, while live chat and automated notifications were removed from the core scope. This was based on the development time required for the main screens and the need to keep the project achievable within the remaining term.

**September 20, 2026 — Room Management screen removed:** The separate Room Management screen was removed from the proposal because it is not part of the current Figma designs or application flow. Room data remains in the database because the reservation and dashboard features still depend on room information.

**September 20, 2026 — Persistence decision made:** The project previously had an undecided choice between local SQLite and Firebase. PocketBase was selected after a one-hour technical spike successfully connected a Flutter test application to a locally running PocketBase backend and fetched a record. This provides a lightweight backend while allowing room and reservation data to be shared between devices when the backend is available.

**September 20, 2026 — Risks narrowed:** The previous concern about general state management and concurrent booking was narrowed into two concrete implementation risks: PocketBase/backend integration and date-range overlap validation. This change reflects the experience gained from building the earlier Flutter modules and makes the remaining risks easier to test and address.

**September 20, 2026 — PDF export added as a stretch goal:** A PDF booking receipt/confirmation feature using the `pdf` and `printing` packages was identified as an additional feature to attempt if time allows. It is not required for the core reservation workflow.

## Where the project stands now (added October 9, 2026)

| Proposal said | Current app |
| --- | --- |
| Five screens: Dashboard, Add Reservation, Reservation List, Reservation Details, Calendar | **All five are built.** Added later: **Manage Resort** (unit types, units, stay types, rates) and a **sign-in / create-account** page. |
| "No separate Room Management screen" | Changed in Week 3. Because stays and prices had to be owner-configurable, the app now has Manage Resort. Rooms became **units** with **unit types**, and stay types and rates were added. |
| `rooms` collection with `roomNumber`, `type`, `maxCapacity`, `pricePerNight`, `cleaningStatus`, and `reservations` with `checkInDate`, `checkOutDate`, `assignedRoomId` | Now `unit_types`, `units`, `stay_types`, `rates` and `reservations` (with `startAt`, `endAt`, `unit`, `stayType`, `status` and saved price fields), plus PocketBase's `users`. Exact fields: [08-setup-and-troubleshooting.md](08-setup-and-troubleshooting.md#required-collections-and-fields). The old `rooms` fields `type`, `pricePerNight` and `cleaningStatus` still exist on `units` but the app mostly no longer uses them. |
| Calendar with `TableCalendar` or a custom layout | A **custom** calendar. No calendar package is used. |
| Overlap validation helper, target October 5 | Done (Week 2, date and time based, covered by unit tests). It runs **only in the app**; PocketBase does not enforce it ([09-reservations-and-data-integrity.md](09-reservations-and-data-integrity.md)). |
| Backend integration risk, target October 1 | Done. PocketBase runs locally for development. The online demo uses a PocketBase Cloud instance (setup in [07-deployment.md](07-deployment.md)). On 2026-10-09 the GitHub Pages app loaded its data from it after signing in. |
| Out of scope: real-time sync, live chat, notifications, guest accounts and payments, PDF receipts | Still out of scope. Real-time sync and PDF receipts remain stretch goals and are **not built**. (Staff accounts for signing in were added; guest accounts were not.) |
| Mobile and desktop | Both are supported (phone, tablet and desktop layouts). The Week 1 report says "mobile-only" for a few days, but that was reversed in Week 2. |
