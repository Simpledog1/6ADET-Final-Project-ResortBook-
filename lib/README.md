# ResortBook — code overview

Setup, features and limitations are in the [project README](../README.md). This page explains how the `lib/` folder is organised.

## Structure

| Folder | What is in it |
| --- | --- |
| `main.dart` | App entry point. Wraps the app in `DevicePreview` in debug runs only (phone frames and screenshots); release builds show the app directly. |
| `models/` | Data classes mapped from PocketBase records: `Reservation`, `Unit`, `UnitType`, `StayType`, `Rate`. |
| `services/` | `PocketBaseService` (reservations), `ConfigService` (unit types, units, stay types, rates, delete guards, friendly error messages) and `ReservationGateway`, a thin wrapper the reservation screens use so widget tests can swap in a fake. |
| `logic/` | Pure Dart rules with unit tests: `booking_logic` (stay windows, overlaps, pricing, capacity), `calendar_logic` (which bookings show on which day), `reservation_stats` (dashboard numbers, sorting, pages), `reservation_workflow` (statuses, editing, restore), `config_rules` (Manage Resort validation and setup checklist). |
| `screens/` | Dashboard, Reservation List, Reservation Details, Add/Edit Reservation, Calendar, and `manage/` for Manage Resort (unit types, units, stay types, rates). |
| `widgets/` | Shared UI: the desktop shell and page frame, cards, tables, filters, badges, dialogs and form inputs. |
| `theme/`, `utils/` | Colours, spacing and text styles; date and peso formatting. |

## Layouts

`widgets/app_shell.dart` picks the layout by width: below 1024 px the phone/tablet screens (navy header, dashboard hub, back navigation); from 1024 px the desktop shell (top bar, sidebar, nested navigator). Each screen checks `DesktopShellScope` to choose its phone or desktop layout, so the data and rules are shared.

## Booking rules in short

- A booking's start and end come from its stay type (e.g. Overnight 2:00 PM → 12:00 PM next day). Times are stored in UTC.
- Two bookings on the same unit overlap when `newStart < existingEnd && newEnd > existingStart`, so back-to-back bookings are allowed. Cancelled bookings never block.
- Prices are per night or per stay, from the rate for the unit's type and the stay type. The rate, total and names are saved with each booking.
- Statuses: `Reserved` → `Checked In` (from the check-in date) → `Completed`; `Reserved` can be cancelled; a cancelled booking can be restored if its unit is still free. Editing a checked-in booking is limited to guest details and notes; completed and cancelled bookings can't be edited.
- Changing the unit, stay type or dates of a booking re-checks availability and recalculates the price; other edits keep the saved times and price.
