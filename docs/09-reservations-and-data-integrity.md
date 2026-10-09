# Reservations and data integrity

This page explains how a reservation is made, how double bookings are prevented, and, just as important, where they are **not** prevented. Each statement says how I know it. "Verified" means I ran it or a test covers it; "not verified" means I did not run it.

Terms used below:

- **Verified (live):** run against the real app and a PocketBase 0.40.4 server on 2026-10-09 (a scratch copy of my database, not the production data).
- **Verified (test):** covered by an automated test in `test/`. See [10-testing-and-verification.md](10-testing-and-verification.md).
- **Not verified:** read from the code only.
- **Recommended, not implemented:** a suggestion. It is not in the app.

## 1. How staff create a reservation

Screen: **Add Reservation** (sidebar on desktop, dashboard button on phone). The steps below match `lib/screens/add_reservation_screen.dart`.

1. **Guest name** (required). **Contact number** and **email** are optional. The app does **not** check the email format before saving. The `email` field in PocketBase has the type `email`, so the server may reject a badly formed address. I have **not** tested what happens, or which message the app shows, when an invalid email is entered.
2. **Number of guests.** Must be at least 1 and no more than the chosen unit's capacity (for example "Cottage A fits up to 4 guests.").
3. **Stay type.** Pick one of the active stay types (for example Overnight, Day Tour, Night Tour). The stay type sets the default check-in time and how long the stay lasts. These are set by the owner in Manage Resort, so another resort will see different ones.
4. **Unit.** Pick an active unit. The list shows each unit's type and capacity. "Add new unit..." lets staff create one without leaving the form.
5. **Dates.** Choose the check-in date. The check-in time starts at the stay type's default and can be changed. A check-out date is only asked for when the stay type allows several nights. The form then shows the stay window (check-in and check-out date and time) and the total price.
6. **Notes** (optional).
7. **Save Reservation.** The app then:
   1. checks the form (name, guest count, a stay type, a unit and dates chosen, and a rate configured for that unit type and stay type; if there is no rate it refuses to save);
   2. asks PocketBase for non-cancelled reservations of that unit that overlap the new time window;
   3. compares them again in Dart using the rule in section 2;
   4. if one overlaps, it shows **Date Conflict Detected** with the unit and the existing booking's dates and guest name, and nothing is saved;
   5. otherwise it saves the reservation with status `Reserved`, the UTC start and end times, and a copy of the unit name, stay type name, rate and total (so later price changes do not alter it), then shows "Reservation saved" with the total and clears the form.

What I could confirm:

- Steps 1 to 6 and the conflict banner in step 7.4: **verified (live)** on desktop and phone width. See `desktop-add-reservation-conflict.png` and `mobile-add-reservation-conflict.jpg` in `docs/assets/App Screenshots/`. The form was filled with Cottage A, Overnight, Nov 11 to Nov 12, 2026, which overlaps an existing booking for Cottage A (Nov 10 to Nov 12).
- The successful save in step 7.5: **verified (test)** with a fake data source, and I did not repeat it live in this session.

Other reservation actions (**Edit**, **Check In**, **Mark Completed**, **Cancel**, **Restore**) are described in the [README](../README.md#key-features). Edit and Restore run the same overlap check.

## 2. The overlap rule

In plain English: two bookings **for the same unit** clash when one starts **before** the other ends **and** ends **after** the other starts. Cancelled bookings are ignored. A booking that starts at the exact minute another one ends does not clash.

```
newStart < existingEnd  &&  newEnd > existingStart
```

The code is `BookingLogic.overlaps` in `lib/logic/booking_logic.dart`. The comparison uses the full date **and time**, not just the day. Reservations store UTC start and end times (`startAt`, `endAt`).

## 3. Edge cases: current behaviour

| # | Situation | What the app does now | How I know |
| --- | --- | --- | --- |
| 1 | Two reservations overlap on the same unit | The new one is blocked and the **Date Conflict Detected** banner is shown. The same check runs on Edit (when unit, stay type or dates change) and on Restore. | Live (screenshots above); tests `findConflicts`, `edit_reservation_test`, `reservation_details_actions_test` |
| 2 | One reservation ends on the same day another begins | Depends on the **times**, not the date. If the earlier one ends at or before the later one starts, both are allowed (for example a Day Tour 8:00 AM to 5:00 PM followed by a Night Tour from 7:00 PM). If they share any time, it is blocked (for example an Overnight that checks out at 12:00 PM and a Day Tour from 8:00 AM the same day). The app adds **no cleaning or turnover gap** between bookings. | Tests "Day Tour then Night Tour on the same day does not overlap" and "Overnight check-out then Day Tour the same day overlaps" |
| 3 | A reservation is cancelled | A cancelled reservation never blocks anything and stays in the list and calendar history. There is no permanent delete. **Restore** brings it back to Reserved only if the unit is still free, otherwise it is refused. | Tests "cancelled reservations never block availability", "restore is refused when another booking now uses the slot" |
| 4 | A reservation starts or ends exactly at another's boundary | Touching ends are allowed. Overlapping by even one minute is blocked. A booking inside another, or around another, is blocked. | New unit tests in `test/overlap_boundary_test.dart` (11 tests) |
| 5 | Several requests reserve the same unit at about the same time | **Protected when the server hook is installed** (section 5): the check and the save happen in one database transaction, so only one of the simultaneous requests can be saved. **Without the hook** it is not protected, because each save does "check, then write", so both requests can pass the check and both are saved. | Backend integration test on 2026-10-09: 20 pairs of simultaneous requests and one burst of 8 gave 0 double bookings with the hook. Without the hook, all 20 pairs and all 8 burst requests were saved. |

Business rules I have not confirmed with a real resort, so the behaviour above is a choice I made, not a requirement:

- No gap between a check-out and the next check-in (cleaning time).
- Same-day check-out and check-in allowed whenever the times do not overlap.
- `Checked In` and `Completed` bookings keep blocking the unit until their booked end time. Marking a stay Completed early does not free the time (listed in the README's known limitations).

## 4. Client-side versus server-side validation

**Client-side validation** is the check inside the Flutter app. It is helpful (clear message, no wasted request) but it is only a convenience, because it protects nothing against:

- another app version or another client (a script, Postman, the PocketBase admin UI);
- two users saving at the same moment, because each client checked an older picture of the data;
- a bug or an old copy of the app that skips the check.

**What I checked on the server (live, 2026-10-09, scratch copy of PocketBase 0.40.4 with this project's schema):**

- The app saves with `pb.collection('reservations').create(...)`, a direct write to the collection. The only server-side protection in this project is the API rule "a signed-in user is required" (`pocketbase/pb_schema.json`, `1791014406_lock_api_rules.js`).
- `pocketbase/` has no `pb_hooks` and no other server code. The only index on `reservations` is `idx_reservations_unit_time`, which only speeds up the overlap query. It is **not** a unique constraint (a range of time cannot be made unique with a normal index).
- **Test:** as a signed-in user I sent a `POST /api/collections/reservations/records` request for Villa 1 with a time range inside an existing Villa 1 booking, without going through the Flutter app. PocketBase **accepted it**, and a query then returned two overlapping non-cancelled bookings for the same unit.

So **without a server-side check**, conflicting reservations can be created through another client or a direct API call, and the Flutter check only prevents them in normal use. That was the situation until 2026-10-09, when the hook in section 5 was added. It protects a PocketBase only once its files are installed on that server.

**Open sign-up makes this worse.** Public sign-up is currently enabled: the `users` create rule (`@request.body.verified:isset = false`, from `1791014407_allow_self_signup.js` and `pb_schema.json`) lets anyone who can reach the server create an account. Every signed-in user has full access to the resort collections. So on a publicly reachable PocketBase, anyone could:

- create an account without the owner knowing;
- read guest names and contact details;
- create, edit or cancel reservations and change units, stay types and rates;
- create overlapping reservations by sending requests directly to the API, unless the overlap hook (section 5) is installed on that server. It has been installed on the online PocketBase since 2026-10-10.

On 2026-10-09 my **local** PocketBase also still had the original open rules (every rule empty, so even signed-out deletes were allowed), because the rule-locking migrations had never been copied into its `pb_migrations` folder. On 2026-10-10 I applied `1791014406` and `1791014407` to it.

* **Backup first:** `pb_data` was backed up to `pb_data_backup_2026-10-09_before_rule_migrations`.
* **Dry run:** a copy showed the migrations change only the rules. All six collections kept the same records, IDs, content and fields.
* **After applying:** signed-out reads return nothing, and signed-out creates and edits are refused.
* **Data unchanged:** the real data was compared with the backup afterwards and is identical.
* **Signed-in checks on a copy:** sign-up, sign-in, loading the 7 existing reservations in the app, create, edit, Check In, Complete, Cancel, Restore, and the hook's overlap rejections all worked. These ran on a copy of the migrated database, so no test bookings were added to the real one.
* **No accounts yet:** the local database has no user accounts, so an account must be created (for example with **Create one**) before the local app can be used. The **online** PocketBase does have locked rules. A request that was not signed in got 0 reservations back, even though reservations exist. The direct-API double booking above was tested only on a scratch copy with my own test account. The other points follow from the configured rules and were not tried one by one.

Recommendations (1, 2 and 4 are **not implemented**; 3 is implemented in the repository, on the online PocketBase and on my local PocketBase):

1. For anything beyond a classroom demo with made-up data, **close sign-up** (set the `users` create rule back to superuser-only in the admin UI) and create staff accounts by hand.
2. If sign-up stays open, give new accounts no access until an admin approves them, for example with an `approved` field on `users` and rules such as `@request.auth.approved = true`. This needs a schema change I have not made.
3. Install the **server-side overlap check** (section 5) on every PocketBase that holds bookings, so the API itself refuses double bookings.
4. Never put real guest data on a server with open sign-up.

## 5. Server-side double-booking check

**What it is.** One self-contained PocketBase JavaScript file, `pocketbase/pb_hooks/reservation_overlap.pb.js`, with a hook for creating and a hook for updating reservations. It is one file so that it can be pasted into a host's hook editor. An earlier version split the check into a second file, which a host's editor cannot load.

For every create and update of a reservation, the hook runs the same rule as the app: same unit, `newStart < existingEnd && newEnd > existingStart`, and cancelled bookings are ignored. If another booking clashes, it rejects the request with 400 "This unit is already booked for part of that time." It uses only APIs documented for PocketBase 0.40.4 (`onRecordCreateRequest`, `onRecordUpdateRequest`, `runInTransaction`, `findRecordsByFilter`, `record.original()`).

**Why a transaction.** A check that only looks before saving is not enough. In testing on 2026-10-09, I put a deliberate 0.4-second pause between the check and the save and sent pairs of simultaneous requests for 10 free slots:

| Version | Slots double-booked |
| --- | --- |
| No hook | 10 of 10 |
| Check in the request hook, then save | 10 of 10 |
| Check in the model "execute" hook, right before the INSERT | 10 of 10 |
| **Check and save inside one `runInTransaction`** (the version in the repo) | **0 of 10** |

PocketBase writes through a single database connection, so a transaction makes the second request wait until the first is saved. When the second request runs its check, it sees the first booking. The earlier version of this hook (the "16 simultaneous creates" result in older notes) only checked before saving and was replaced, because this test shows it can let a double booking through.

**What it protects:**

- **Creating a booking**, from the app or by a direct API request.
- **Edits that can change availability:** a different unit, a different start or end time, or **Restore** of a cancelled booking. The booking being edited is excluded from its own check.
- **Other edits are not re-checked,** so guest details, notes, Check In and Mark Completed are never blocked by it.
- **Cancelling is always allowed,** and a cancelled booking never blocks anything.

**Backend integration test.** `pocketbase/tests/run-overlap-tests.ps1` starts a throwaway PocketBase (its own data folder; it never touches real data), imports `pb_schema.json`, loads the hooks and sends real HTTP requests:

```powershell
powershell -ExecutionPolicy Bypass -File pocketbase\tests\run-overlap-tests.ps1 -PocketBaseExe "C:\path\to\pocketbase.exe"
```

The test checks:

- overlap rejected;
- back-to-back bookings allowed both ways;
- a one-minute overlap rejected;
- multi-night overlap rejected;
- cross-midnight overlap rejected, and the next day allowed;
- the same time on a different unit allowed;
- Cancelled bookings saved, and not blocking;
- restoring a booking whose slot is taken rejected, and restoring one whose slot is free allowed;
- edits: guest details allowed, an edit that overlaps only itself allowed, moving into another booking or to another unit with a clash rejected;
- Check In and Mark Completed allowed;
- 20 pairs of simultaneous requests;
- a burst of 8 simultaneous requests for one slot;
- a final scan of the database for overlapping bookings.

Results on 2026-10-09 with PocketBase 0.40.4:

| Run | Result |
| --- | --- |
| With the hook (run twice) | **22 of 22 passed** both times: 20 accepted for 20 slots, exactly 1 of 8 in the burst, 0 overlapping pairs |
| Without the hook (`-NoHooks`) | 12 passed, 10 failed: every overlap, restore and edit conflict was accepted, all 40 simultaneous requests and all 8 burst requests were saved, and 54 overlapping pairs were left in the database |

I also saved a normal booking through the app's Add Reservation form against a PocketBase with the hook. It saved as usual ("Reservation saved · ₱10,000"). If the server rejects a booking, the app's existing error message shows the server's text ("Could not save the reservation. This unit is already booked for part of that time."). I have not seen that message live, because the app's own check normally catches a conflict first.

**Where it is installed:**

| PocketBase | Installed? |
| --- | --- |
| This repository (`pocketbase/pb_hooks/`) | Yes |
| My local PocketBase | Yes, copied on 2026-10-09 after backing up `pb_data` to `pb_data_backup_2026-10-09_before_overlap_hook`. The rule-locking migrations were applied on 2026-10-10 (see section 4). Booking tests with the hook were run on a copy of the migrated local database, not on the real one. |
| The online PocketBase (PocketBase Cloud) | **Yes**, deployed on 2026-10-10 through the PocketBase Cloud portal (instance **Hooks** tab: New Hook → paste the file → Save → Deploy, "Deployed 1 file successfully"). Before deploying, a full backup was made with PocketBase's built-in backups, and the online rules and fields were confirmed to match `pb_schema.json` (no migrations needed). **Verified live**, 16 of 16 checks, see the line under this table. |

Live checks on the online PocketBase (2026-10-10), signed in with a normal account:

* the overlap was rejected by the server with the hook's message;
* a back-to-back booking was allowed;
* moving a booking into another was rejected, and so was restoring into an occupied slot;
* notes, Check In, Mark Completed, Cancel and Restore into a free slot all worked;
* 4 pairs of simultaneous requests gave 0 double bookings, and a burst of 5 for one slot gave exactly 1 booking;
* signed-out reads returned nothing and signed-out creates were refused;
* the reservation list loaded with unit and stay-type details.

The test bookings (in 2035) were deleted afterwards by the admin account, leaving the original online bookings untouched. Because of the free plan's limit of 500 API requests per hour, the online concurrency test is smaller than the local one.

**Limits:**

- It only protects a PocketBase that has the files. A copy of the app pointed at a server without them is not protected.
- It does not remove double bookings that already exist. It only blocks new ones.
- The concurrency result comes from tests (40 paired and 8 burst requests with the hook, and the slowed-down comparison above). It shows the transaction serialises the check and the save in PocketBase 0.40.4. It is test evidence, not a formal proof, and it relies on PocketBase keeping a single write connection.
- PocketBase's batch API also passes through the same request hooks, but it is turned off by default and I did not test it.

## 6. Checking the models against PocketBase

The models read fields with calls such as `record.getStringValue('guestName')`. If a name were wrong, the call would **not** fail. It would return an empty value, and the screen would just look blank. So it is worth checking.

What exists in the repository:

- `test/schema_models_test.dart` reads each model file and `createReservation`, and checks that the fields the models read exist in `pocketbase/pb_schema.json` with a compatible type (text/select/relation/date for strings, number for numbers, bool for flags), and that the fields `createReservation` writes exist. It does not cover the other save and update code. It passed on 2026-10-09. This proves the code agrees with the **schema file**. It does not prove that the schema file matches your running server.

To check the real server (**manual, not done for the online server**):

1. Start PocketBase and open the admin UI (`/_/`) > **Collections**. For each collection, compare the field names and types with the tables in [08-setup-and-troubleshooting.md](08-setup-and-troubleshooting.md#required-collections-and-fields).
2. Or export from the admin UI (**Settings > Export collections**) and compare it with `pocketbase/pb_schema.json` (for example with `git diff --no-index`). Differences in `created`/`updated` timestamps and `id`s can be ignored.
3. Run the app with a few records and check that no field that has data shows blank.

## 7. Manual test checklist

Use the demo data (units Cottage A, Cottage B and Villa 1; stay types Overnight 2:00 PM for 22 hours, Day Tour 8:00 AM to 5:00 PM, Night Tour 7:00 PM to 6:00 AM). Set up one existing booking: **Cottage A, Overnight, Nov 10, 2026 2:00 PM to Nov 12, 2026 12:00 PM** (Maria Santos in the demo data). Then try each row on the **Add Reservation** screen.

| # | Input | Expected result | Basis |
| --- | --- | --- | --- |
| T1 | Cottage A, Overnight, check-in Nov 11 (1 night) | Blocked: "Cottage A is already booked from Nov 10, 2026 2:00 PM to Nov 12, 2026 12:00 PM (Maria Santos)." Nothing saved. | Seen live on 2026-10-09 |
| T2 | Cottage A, Overnight, check-in Nov 12 (2:00 PM) | Saved (starts after the 12:00 PM check-out) | Unit tests; not run live |
| T3 | Cottage A, Day Tour, Nov 12 (8:00 AM to 5:00 PM) | Blocked (overlaps until 12:00 PM) | Unit test "Overnight check-out then Day Tour the same day overlaps"; not run live |
| T4 | Cottage A, Night Tour, Nov 12 (7:00 PM) | Saved | Follows the rule; not run live |
| T5 | Cottage B, Overnight, check-in Nov 11 | Saved (different unit) | Unit test; not run live |
| T6 | Cancel Maria's booking, then Cottage A, Overnight, Nov 11 | Saved (cancelled does not block) | Unit test; not run live |
| T7 | After T6, Restore Maria's booking | Refused: the unit is no longer free | Unit test; not run live |
| T8 | Cottage A with 5 guests | Error "Cottage A fits up to 4 guests." | Unit test; not run live |
| T9 | Cottage A, Overnight, check-in Nov 8, check-out Nov 11 | Blocked (3 nights overlap the start of Maria's stay) | Follows the rule; not run live |
| T10 | Open Add Reservation in two browser windows, fill the same unit and times, save both within a second | **With the hook:** only the first is saved; the second shows "Could not save the reservation. This unit is already booked…". **Without the hook:** both may be saved. | The same situation was tested at the API level (backend integration test, 0 double bookings with the hook). The two-window UI version was not run. |
| T11 | Send an overlapping reservation directly to the API (see section 4) | **Without the hook:** accepted. **With the hook:** rejected with 400. | Both verified on 2026-10-09 (scratch copy and backend integration test) |

Expected outcomes for T2 to T4 and T6 also depend on the business rules listed at the end of section 3 (no turnover gap and so on).
