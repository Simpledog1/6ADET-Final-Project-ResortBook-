# ResortBook

[![Made with AI](https://img.shields.io/badge/Made_with-AI_assistance-blue)](AI-USAGE.md)

> A front-desk reservation manager for small independent resorts — units, stay types, rates and bookings in one Flutter app backed by PocketBase.

**Course:** Applications Development and Emerging Technologies (6ADET), Holy Angel University
**Author:** [Simpledog1](https://github.com/Simpledog1)
**Web build:** https://simpledog1.github.io/6ADET-Final-Project-ResortBook-/ — see [Web build limitation](#web-build-limitation) (it needs a reachable PocketBase server)
**Demo video:** see [docs/05-demo-video.md](docs/05-demo-video.md)
**AI use:** built with heavy AI help: Gemini (Google) for the first version (Sept 23 – Oct 3), then Claude (Anthropic) for most of the current code, tests and docs. I set the requirements, ran and tested everything, and decided what to keep. Details in [AI-USAGE.md](AI-USAGE.md).

---

## The problem

Small resorts often track bookings in paper logbooks or loose spreadsheets. That makes double-bookings easy, makes it hard to see who is arriving or staying, and prices get calculated by hand.

## Who it is for

Front-desk staff and managers of small-to-medium resorts. It is an internal staff tool, not a guest-facing booking site.

## Key features

- **Configurable resort setup (Manage Resort)** — unit types (Room, Cottage, Villa…), units with capacity, stay types with a default check-in time and a duration set by the owner (e.g. Overnight from 2:00 PM for 22 hours, Day Tour 8 hours, Night Tour across midnight) and a rate for each unit type + stay type. Records still used by reservations are protected from deletion; they can be deactivated instead.
- **Add Reservation** — the check-in time starts at the stay type's default (staff can pick another) and check-out is calculated from the stay type's duration; multi-night stays for stay types that allow them. Changing a duration later only affects new bookings. A new unit can also be added straight from the Unit field: type its name, type a new or existing unit type, capacity and (optionally) the price for the chosen stay type. Blocks overlapping bookings on the same unit (back-to-back bookings are allowed), checks guest count against unit capacity, and refuses to save when no rate is configured. Prices (per night or per stay) and names are saved with the booking, so later configuration changes don't alter history.
- **Reservation List** — guest-name search; on desktop a sortable table (guest, check-in, check-out) with status filters and 20 rows per page.
- **Reservation Details** — full booking information, pricing and a timeline.
- **Booking workflow** — Edit, Check In (from the check-in date), Mark Completed, Cancel (with confirmation) and Restore (only if the unit is still free). Cancelled reservations never block availability. There is no permanent delete.
- **Calendar** — month view showing a booking on every day its time window touches (including Night Tours that cross midnight); desktop adds booking bars, "+N more" and a side panel for the selected day.
- **Dashboard** — on desktop: reservations this month, staying now, arriving in the next 7 days, units occupied now, upcoming and recently added bookings, quick actions and a setup warning when the configuration has gaps.

## Built with

| | |
| --- | --- |
| Framework | Flutter (Dart), Material 3, bundled Inter font |
| State | `setState` + `FutureBuilder` (no state-management package) |
| Backend / storage | [PocketBase](https://pocketbase.io) v0.40.4, running locally |
| Packages | `pocketbase` (API client), `device_preview` + `device_preview_screenshot` (debug-only phone frames and screenshots) |

### Screen sizes

| Width | Layout |
| --- | --- |
| Phone (< 600 px) | Mobile screens with a dashboard hub and back navigation |
| Tablet (600–1023 px) | The same screens, centred at a comfortable width |
| Desktop (≥ 1024 px) | Navy top bar, sidebar navigation and wide desktop layouts |

## Running it yourself

### 1. PocketBase

1. Download PocketBase **v0.40.4** for your OS from the [PocketBase releases](https://github.com/pocketbase/pocketbase/releases) and extract it.
2. Copy the files in this repo's `pocketbase/migrations/` folder into a `pb_migrations/` folder next to the PocketBase executable.
3. Start it:
   ```bash
   ./pocketbase serve
   ```
   The migrations run automatically on start and create/update the `unit_types`, `units`, `stay_types`, `rates` and `reservations` collections. Create a superuser when prompted (admin UI: http://127.0.0.1:8090/_/).
4. The app expects the server at `http://127.0.0.1:8090` (set in `lib/services/pocketbase_service.dart`). The collection API rules are open for local use (see [Security and privacy](docs/06-security-and-privacy.md)).

> The migrations upgrade this project's original `rooms` and `reservations` collections (they look them up by their collection IDs, rename `rooms` to `units` and keep existing bookings). They are meant for this project's existing database; on a completely fresh PocketBase install they won't apply as-is, and the collections would need to be created to match the fields shown in the migration files.

### 2. Flutter app

```bash
flutter pub get
flutter run -d windows    # or: flutter run -d chrome / an emulator
```

Then open **Manage Resort** to add unit types, units, stay types and rates before adding reservations.

### Tests

```bash
flutter analyze
flutter test
```

The tests cover the booking, calendar, statistics, configuration and workflow rules, plus widget tests for the main screens (they use a fake data source, so no server is needed).

## Screenshots

Design wireframes (Figma) are in `docs/assets/Wireframe screenshots/`:

| Dashboard | Reservation List | Calendar |
| --- | --- | --- |
| ![Desktop dashboard](docs/assets/Wireframe%20screenshots/Desktop%20-%20Dashboard.png) | ![Desktop reservation list](docs/assets/Wireframe%20screenshots/Desktop%20-%20Reservation%20List.png) | ![Desktop calendar](docs/assets/Wireframe%20screenshots/Desktop%20-%20Calendar%20View.png) |
| ![Mobile dashboard](docs/assets/Wireframe%20screenshots/Mobile%20-%20Dashboard.png) | ![Mobile reservation list](docs/assets/Wireframe%20screenshots/Mobile%20-%20Reservation%20List.png) | ![Mobile calendar](docs/assets/Wireframe%20screenshots/Mobile%20-%20Calendar%20View.png) |

Screenshots of the running app can be captured in debug mode with the DevicePreview screenshot tool.

## Web build limitation

A web build is published by the GitHub Actions workflow (`.github/workflows/deploy-web.yml`), but the app talks to PocketBase at `http://127.0.0.1:8090` — the computer it runs on. A static GitHub Pages site cannot reach your local PocketBase (and an `https` page cannot call a plain `http` local address), so **the hosted web build shows "Cannot reach PocketBase" unless a reachable PocketBase backend is set up**. No public backend is part of this project. Run the app locally with PocketBase as described above; the demo video and screenshots are the primary showcase.

## Known limitations

- No authentication or user accounts; anyone who can reach the PocketBase server can read and change data (local use only).
- If two people edit the same reservation at the same time, the last save wins. The overlap check happens just before saving, so two simultaneous bookings for the same slot are theoretically possible.
- Completing a stay early doesn't shorten the booked time window; the unit stays blocked until the booked end time.
- No payments, notifications, housekeeping or guest-facing online booking (out of scope).

## Project documentation

| Document | |
| --- | --- |
| [Proposal](docs/01-proposal.md) | the problem, the users, the scope |
| [Mockup and wireframes](docs/02-mockup.md) | what it looks like, and the screen flow |
| [Design system](docs/03-design-system.md) | colors, type, spacing, components |
| [Weekly reports](docs/04-weekly-reports.md) | what happened each week |
| [Demo video](docs/05-demo-video.md) | the recording and what it shows |
| [Security and privacy](docs/06-security-and-privacy.md) | what is stored and how it is protected |
| [Code overview](lib/README.md) | how the `lib/` folder is organised |

## AI use

AI assistance (Gemini for the first version, then Claude) was used for planning, code generation, tests and documentation during development. All changes were reviewed, run and tested by the author. What the AI did, where it got things wrong and which parts I wrote myself are in [AI-USAGE.md](AI-USAGE.md).

## Licence

MIT, see [LICENSE](LICENSE).
