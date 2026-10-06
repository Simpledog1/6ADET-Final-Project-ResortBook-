# ResortBook

[![Made with AI](https://img.shields.io/badge/Made_with-AI_assistance-blue)](AI-USAGE.md)

> A front-desk reservation manager for small independent resorts — units, stay types, rates and bookings in one Flutter app backed by PocketBase.

**Course:** Applications Development and Emerging Technologies (6ADET), Holy Angel University
**Author:** [Simpledog1](https://github.com/Simpledog1)
**Web build:** https://simpledog1.github.io/6ADET-Final-Project-ResortBook-/ — see [Web build and deployment](#web-build-and-deployment) (it needs a publicly hosted PocketBase and a login)
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
| Backend / storage | [PocketBase](https://pocketbase.io) v0.40.4 (local for development, separately hosted for the public demo) |
| Packages | `pocketbase` (API client), `shared_preferences` (keeps the login across reloads), `device_preview` + `device_preview_screenshot` (debug-only phone frames and screenshots) |

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
   The migrations run automatically on start and create/update the `unit_types`, `units`, `stay_types`, `rates` and `reservations` collections and **lock the API rules to signed-in users**. Create a superuser when prompted (admin UI: http://127.0.0.1:8090/_/).
4. Create a login: either use **Create one** on the app's Sign In page, or add a user in the admin UI (Collections > `users` > New record).
5. By default the app uses `http://127.0.0.1:8090`. The address is read in one place, `lib/config/app_config.dart`; override it at run/build time with `--dart-define=POCKETBASE_URL=...` (see below).

> **Fresh PocketBase install:** import `pocketbase/pb_schema.json` instead (admin UI > Settings > Import collections). It contains every collection with the production API rules. The migrations below only apply to this project's existing database.
>
> The migrations upgrade this project's original `rooms` and `reservations` collections (they look them up by their collection IDs, rename `rooms` to `units` and keep existing bookings). They are meant for this project's existing database; on a completely fresh PocketBase install they won't apply as-is, and the collections would need to be created to match the fields shown in the migration files.

### 2. Flutter app

```bash
flutter pub get
flutter run -d windows    # or: flutter run -d chrome / an emulator
```

Sign in with the user you created in PocketBase. To use a different server (for example the public one): `flutter run -d chrome --dart-define=POCKETBASE_URL=https://your-pocketbase.example.com`.

Then open **Manage Resort** to add unit types, units, stay types and rates before adding reservations.

### Tests

```bash
flutter analyze
flutter test
```

The tests cover the booking, calendar, statistics, configuration and workflow rules, plus widget tests for the main screens (they use a fake data source, so no server is needed).

## Screenshots

Screenshots of the current app (signed in as a demo user) with made-up demo data, captured at 1366 px (desktop) and 375 px (phone) widths. The original Figma wireframes are in [docs/02-mockup.md](docs/02-mockup.md).

### Desktop (1024 px and wider)

| Dashboard | Reservations |
| --- | --- |
| ![Desktop dashboard](docs/assets/App%20Screenshots/desktop-dashboard.png) | ![Desktop reservation list](docs/assets/App%20Screenshots/desktop-reservations.png) |
| **Calendar** | **Add Reservation** |
| ![Desktop calendar](docs/assets/App%20Screenshots/desktop-calendar.png) | ![Desktop add reservation](docs/assets/App%20Screenshots/desktop-add-reservation.png) |
| **Manage Resort** | **Unit Types** |
| ![Desktop Manage Resort](docs/assets/App%20Screenshots/desktop-manage-resort.png) | ![Desktop unit types](docs/assets/App%20Screenshots/desktop-unit-types.png) |
| **Units** | **Stay Types** |
| ![Desktop units](docs/assets/App%20Screenshots/desktop-units.png) | ![Desktop stay types](docs/assets/App%20Screenshots/desktop-stay-types.png) |
| **Rates** | |
| ![Desktop rates](docs/assets/App%20Screenshots/desktop-rates.png) | |
| **Sign In** | **Create Account** |
| ![Desktop sign in](docs/assets/App%20Screenshots/desktop-login.png) | ![Desktop create account](docs/assets/App%20Screenshots/desktop-sign-up.png) |

### Phone

| Dashboard | Reservation List | Calendar | Add Reservation | Add Reservation (cont.) |
| --- | --- | --- | --- | --- |
| ![Phone dashboard](docs/assets/App%20Screenshots/mobile-dashboard.jpg) | ![Phone reservation list](docs/assets/App%20Screenshots/mobile-reservation-list.jpg) | ![Phone calendar](docs/assets/App%20Screenshots/mobile-calendar.jpg) | ![Phone add reservation](docs/assets/App%20Screenshots/mobile-add-reservation-1.jpg) | ![Phone add reservation, lower half](docs/assets/App%20Screenshots/mobile-add-reservation-2.jpg) |
| **Manage Resort** | **Unit Types** | **Units** | **Stay Types** | **Rates** |
| ![Phone Manage Resort](docs/assets/App%20Screenshots/mobile-manage-resort.jpg) | ![Phone unit types](docs/assets/App%20Screenshots/mobile-unit-types.jpg) | ![Phone units](docs/assets/App%20Screenshots/mobile-units.jpg) | ![Phone stay types](docs/assets/App%20Screenshots/mobile-stay-types.jpg) | ![Phone rates](docs/assets/App%20Screenshots/mobile-rates.jpg) |
| **Sign In** | **Create Account** | | | |
| ![Phone sign in](docs/assets/App%20Screenshots/mobile-login.jpg) | ![Phone create account](docs/assets/App%20Screenshots/mobile-sign-up.jpg) | | | |

## Web build and deployment

```
DEVELOPMENT                                     PRODUCTION
Flutter app (Windows / Chrome)                  Browser
        |                                               |
Local PocketBase  http://127.0.0.1:8090         GitHub Pages (Flutter web)
                                                        |
                                                Public PocketBase (HTTPS)
                                                        |
                                                Signed-in ResortBook users only
```

- **Web viewport:** the release web build shows ResortBook directly in the whole browser window (DevicePreview is debug-only and never enabled on web). Below 600 px you get the phone layout, 600-1023 px the tablet layout, from 1024 px the desktop sidebar layout.
- **Login and sign-up:** the app opens on a Sign In page with a **Create one** link to a Create Account page (name, email, password, confirm password). After creating an account you return to Sign In and log in. The session is saved in the browser, so a reload keeps you signed in until you use **Sign out**.
- **API rules:** the data is protected by PocketBase itself, not just the UI: without a login the API returns no data and rejects writes (see [Security and privacy](docs/06-security-and-privacy.md)).
- **Configuration:** the PocketBase address is `POCKETBASE_URL` (a build-time `--dart-define`, default `http://127.0.0.1:8090`; the GitHub workflow takes it from the repository variable `POCKETBASE_URL`). It is not a secret. Never commit the PocketBase admin password, `pb_data/`, or `.env` files.
- **Hosting PocketBase publicly** is a manual step that needs your own hosting account: see [docs/07-deployment.md](docs/07-deployment.md). Until a public PocketBase URL is configured, the hosted web build cannot reach any server.

## Known limitations

- Simple authentication only: one shared kind of account (no roles or password reset); accounts are managed in the PocketBase admin UI. Every signed-in user can change all data.
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
| [Deployment guide](docs/07-deployment.md) | hosting PocketBase publicly and publishing the web build |
| [Security and privacy](docs/06-security-and-privacy.md) | what is stored and how it is protected |
| [Code overview](lib/README.md) | how the `lib/` folder is organised |

## AI use

AI assistance (Gemini for the first version, then Claude) was used for planning, code generation, tests and documentation during development. All changes were reviewed, run and tested by the author. What the AI did, where it got things wrong and which parts I wrote myself are in [AI-USAGE.md](AI-USAGE.md).

## Licence

MIT, see [LICENSE](LICENSE).
