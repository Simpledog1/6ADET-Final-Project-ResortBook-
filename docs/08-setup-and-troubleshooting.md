# Setup and troubleshooting

How to get ResortBook running from a fresh computer, and what to do when the setup fails. The troubleshooting section includes problems I actually ran into (see [the weekly reports](04-weekly-reports.md)).

## Versions

| Tool | Version | Source |
| --- | --- | --- |
| Flutter | 3.47.5 (stable channel) | `flutter --version` on 2026-10-09 |
| Dart | 3.13.4 (comes with Flutter) | same command |
| Dart constraint in the project | `sdk: ^3.8.0` | `pubspec.yaml` |
| PocketBase | 0.40.4 | the version the schema and migrations were built and tested with |
| Operating system used for the checks in these docs | Windows 10 Pro (build 19045), 64-bit Intel/AMD (`AMD64`) | checked on 2026-10-09 |

I have **not** tested other Flutter versions, other PocketBase versions, macOS, Linux or an Android emulator. The Week 1 report mentions a Linux laptop I could not set up because of the network, so Linux is untested. The Week 2 report mentions Windows 11. The checks in these docs ran on the Windows 10 machine above.

Repository: <https://github.com/Simpledog1/6ADET-Final-Project-ResortBook-.git>

## What to install

| Tool | Needed for | Notes |
| --- | --- | --- |
| Git | cloning the repository | |
| Flutter SDK | everything | Run `flutter doctor -v` after installing and fix what it reports |
| Google Chrome | running or testing the web version | |
| Visual Studio 2022 with the **Desktop development with C++** workload | running the **Windows desktop** app only | About 5 GB or more. Not needed for the web version. In Windows settings, **Developer Mode** must also be on (Flutter needs it for plugin symlinks). |
| PocketBase 0.40.4 | the database/API | One executable file, see below |

## Steps

```bash
git clone https://github.com/Simpledog1/6ADET-Final-Project-ResortBook-.git
cd 6ADET-Final-Project-ResortBook-
flutter pub get
```

### 1. Download the right PocketBase build

PocketBase publishes one file per operating system **and processor type**. Downloading the wrong one fails: in Week 2 I downloaded the `arm64` build and Windows would not run it on my AMD (x64) laptop.

1. Find your processor type:

   | System | Command | Result | File to download |
   | --- | --- | --- | --- |
   | Windows (PowerShell) | `$env:PROCESSOR_ARCHITECTURE` | `AMD64` | `pocketbase_0.40.4_windows_amd64.zip` |
   | Windows (PowerShell) | `$env:PROCESSOR_ARCHITECTURE` | `ARM64` | `pocketbase_0.40.4_windows_arm64.zip` |
   | Linux or macOS | `uname -m` | `x86_64` | `..._linux_amd64.zip` or `..._darwin_amd64.zip` |
   | Linux or macOS | `uname -m` | `aarch64` (Linux) or `arm64` (macOS) | `..._linux_arm64.zip` or `..._darwin_arm64.zip` |

   The file names above follow PocketBase's usual pattern. Check them against the release page, which I did not open while writing this.

   `amd64` means 64-bit Intel or AMD, which is most Windows and Linux PCs. `arm64` is for ARM chips (Apple Silicon Macs, some Windows laptops and Raspberry Pi).
2. Download it from the [PocketBase releases](https://github.com/pocketbase/pocketbase/releases/tag/v0.40.4) page and unzip it. Check that the zip is the size shown on the release page, because an interrupted download gives a broken zip.
3. Do not put it inside the Flutter project. Keep it in its own folder.

### 2. Create the collections

Start it from its folder:

```bash
./pocketbase serve        # Windows: .\pocketbase.exe serve
```

Open <http://127.0.0.1:8090/_/> and create the superuser (the admin) when asked. Then use **one** of these:

- **A new, empty PocketBase (recommended):** admin UI > **Settings > Import collections > Load from JSON file** > choose `pocketbase/pb_schema.json` > confirm. This creates `users` (login accounts), `unit_types`, `units`, `stay_types`, `rates` and `reservations` with all fields and the API rules. On 2026-10-06 I tested importing an **earlier version** of this file into an empty PocketBase 0.40.4 and it worked. The file was changed afterwards (the `users` create rule now allows sign-up), and I have **not** re-tested importing the current file.
- **My existing database only:** copy the files in `pocketbase/migrations/` into a `pb_migrations/` folder next to the executable and restart. These migrations upgrade the original `rooms` collection by its internal id, so on a fresh install they do not work.

Then copy the `pocketbase/pb_hooks/` folder next to the PocketBase executable (so there is a `pb_hooks` folder beside `pocketbase.exe`) and restart PocketBase. This turns on the server-side double-booking check (see [09](09-reservations-and-data-integrity.md#5-server-side-double-booking-check)).

Then create a login (admin UI > Collections > `users` > New record, or use **Create one** on the app's sign-in page), and add your resort setup in the app under **Manage Resort**: unit types, stay types, units, then a rate for every unit type and stay type pair. Without a rate the app refuses to save a reservation.

### 3. Run the app

```bash
flutter run -d chrome                # web
flutter run -d windows               # Windows desktop (needs Visual Studio C++)
```

The app expects PocketBase at `http://127.0.0.1:8090`. For another address, pass it when you run or build, for example `flutter run -d chrome --dart-define=POCKETBASE_URL=https://example.com`. The address is read in one place, `lib/config/app_config.dart`.

In a debug run on Windows desktop, the app is shown inside a DevicePreview phone frame with a screenshot tool. Release builds and the web version show the app directly.

### Required collections and fields

These match `pocketbase/pb_schema.json`. "Required" is PocketBase's own required setting. The app also enforces its own rules in the forms.

**`unit_types`**: unique index on `name`.

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `name` | text | yes | |
| `description` | text | no | |
| `defaultCapacity` | number (whole) | no | min 0 |
| `isActive` | bool | no | |
| `sortOrder` | number (whole) | no | |

**`stay_types`**: unique index on `name`. The duration is stored as the check-in time, the check-out time, and whether check-out is the next day. There is no separate duration field.

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `name` | text | yes | |
| `description` | text | no | |
| `checkInTime` | text | yes | for example `14:00` |
| `checkOutTime` | text | yes | for example `12:00` |
| `endsNextDay` | bool | no | |
| `allowMultipleNights` | bool | no | |
| `pricingBasis` | select | yes | `per_night` or `per_stay` |
| `isActive` | bool | no | |
| `sortOrder` | number (whole) | no | |

**`units`**: rooms, cottages, villas and so on.

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `name` | text | no | |
| `unitType` | relation to `unit_types` | no | single |
| `capacity` | number | no | |
| `isActive` | bool | no | |
| `sortOrder` | number (whole) | no | |
| `cleaningStatus` | text | no | kept from the original `rooms` collection |
| `type` | text | no | old text field from `rooms`, only read for old records |
| `pricePerNight` | number | no | old field from `rooms`, not used by the current code |

**`rates`**: unique index on the pair (`unitType`, `stayType`).

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `unitType` | relation to `unit_types` | yes | single, cascade delete |
| `stayType` | relation to `stay_types` | yes | single, cascade delete |
| `price` | number | no | min 0 |

**`reservations`**: index on (`unit`, `startAt`, `endAt`) for the overlap query. This index does **not** prevent overlaps, see [09](09-reservations-and-data-integrity.md#4-client-side-versus-server-side-validation).

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `guestName` | text | no | the app requires it |
| `phone` | text | no | |
| `email` | email | no | |
| `guestCount` | number (whole) | no | min 0 |
| `unit` | relation to `units` | no | |
| `stayType` | relation to `stay_types` | no | single |
| `startAt`, `endAt` | date | no | stored in UTC |
| `status` | text | no | `Reserved`, `Checked In`, `Completed`, `Cancelled` |
| `notes` | text | no | |
| `unitName`, `unitTypeName`, `stayTypeName` | text | no | copies saved at booking time |
| `rate` | number | no | copy of the rate used |
| `rateBasis` | select | no | `per_night` or `per_stay` |
| `quantity` | number (whole) | no | nights charged |
| `totalAmount` | number | no | |

Every collection also has the automatic `id`, `created` and `updated` fields. The `users` collection is PocketBase's built-in one.

The test `test/schema_models_test.dart` checks two things against this schema file: that every field the model classes read (`getStringValue('...')` and similar calls in `lib/models/`) exists with a compatible type, and that every field `createReservation` writes exists. It does **not** check the other save and update code (for example in `ConfigService` or `reservation_workflow.dart`), and it compares with the file, not with a running server.

## Troubleshooting

| Problem | Likely cause | What to do |
| --- | --- | --- |
| `curl: (56)` or `early EOF` / `RPC failed` while cloning Flutter or the project | The connection dropped during a large download (this happened to me at about 85 kbps) | Retry on a different network (a phone hotspot or another place). Try `git clone --depth 1 <url>` (downloads only the latest version, much smaller). If `git` still fails, download the Flutter SDK zip from <https://docs.flutter.dev/install> in a browser, which can resume, and unzip it. |
| A downloaded `.zip` will not open, or the executable crashes right away | Incomplete download | Compare the file size with the one on the release page and download it again. |
| PocketBase "is not compatible with this version of Windows" or will not start | Wrong processor build (`arm64` on an `amd64` PC, or the reverse) | Delete the folder, check your processor type (table above) and download the right build. |
| `flutter` says "Waiting for another flutter command to release the startup lock" | Another Flutter command, or a crashed one, still holds the lock | Close other terminals and editors that run Flutter. If it stays, delete `bin/cache/lockfile` inside the Flutter folder. |
| `flutter doctor` shows "Visual Studio not installed" | The C++ workload is missing | Install Visual Studio 2022 and tick **Desktop development with C++**. |
| "Building with plugins requires symlink support" | Windows Developer Mode is off | Turn on Developer Mode in Windows settings. |
| Error about `Platform._operatingSystem` when exporting screenshots | `dart:io` file saving does not work in the browser | Run the Windows desktop target for the screenshot tool (that is why Week 2 moved to Windows). |
| Git `Permission denied` on commit, mentioning `.vs/` | Visual Studio keeps cache files in `.vs/` locked while it is open | `.vs/` is in `.gitignore` already. If a file was committed before, run `git rm -r --cached .vs` and commit. |
| `flutter pub get` fails with a network error | Packages could not be downloaded | Retry on a better network. Once it has succeeded one time, `flutter pub get --offline` works from the local cache. |
| App shows "Cannot reach PocketBase" | PocketBase is not running, or the app points at another address | Start `pocketbase serve`, and check <http://127.0.0.1:8090/api/health> in a browser. |
| Sign-in works but screens are empty, or saving fails with 400/403 | The collections or API rules are missing or different | Import `pocketbase/pb_schema.json` again on a fresh instance, and check you are signed in. |
| Saving shows "This unit is already booked for part of that time." | The server-side check found an overlapping booking, for example one saved by someone else a moment earlier | Reload the list or calendar, then pick another unit or time. |
| `flutter test` prints a PocketBase connection error | A widget test reached the real client instead of the fake one | The tests should still pass. Report the test name if one fails. The server is not needed for `flutter test`. |

## When the internet is unreliable

- **Do the big downloads somewhere else.** Download the Flutter SDK, the PocketBase zip and Visual Studio on another network (a phone hotspot, a school or library connection, another computer) and copy them over with a USB drive. Check the file sizes afterwards.
- **Keep the caches.** After one successful `flutter pub get`, the packages are in the pub cache and later runs work offline. `flutter precache` downloads the platform files in advance.
- **Keep working without a server.** Almost everything except live data can be done offline:
  - write and run the Dart business rules and their tests (`flutter test` needs no PocketBase, because the screen tests use a fake data source);
  - build and adjust UI against the fake data source, and check layouts at phone and desktop widths;
  - review the data models against the schema file (`test/schema_models_test.dart`);
  - update documentation and the mockups.
- **Cloud development environment.** An online editor such as GitHub Codespaces could run `flutter test` and the web build without installing anything locally. **I have not tried this**, and the Windows desktop target is not possible there.

## What to commit and what not to

Keep these out of Git (they are in `.gitignore` or must stay local): `build/`, `.dart_tool/`, `.vs/`, `.env` files, the PocketBase `pb_data/` folder and its backups (keep PocketBase in its own folder outside the repository), and any passwords. Checking `git status` before every commit catches generated files early.
