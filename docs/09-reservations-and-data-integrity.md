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
| 5 | Several requests reserve the same unit at about the same time | **Not protected.** Each save does "check, then write", with nothing that makes the two steps one action. Two staff members saving at nearly the same moment can both pass the check. Nothing on the server rejects the second one either (section 4). | Code reading, plus a live test that the server accepts an overlapping write (section 4). I did **not** test two real app windows saving at the same moment. |

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

So in the project as it stands, **conflicting reservations can be created through another client or a direct API call.** The Flutter check prevents them in normal use only.

**Open sign-up makes this worse.** Public sign-up is currently enabled: the `users` create rule (`@request.body.verified:isset = false`, from `1791014407_allow_self_signup.js` and `pb_schema.json`) lets anyone who can reach the server create an account. Every signed-in user has full access to the resort collections. So on a publicly reachable PocketBase, anyone could:

- create an account without the owner knowing;
- read guest names and contact details;
- create, edit or cancel reservations and change units, stay types and rates;
- create overlapping reservations by sending requests directly to the API, because no server-side overlap check is active.

The direct-API double booking above was tested only on a scratch copy with my own test account. The other points follow from the configured rules and were not tried one by one.

Recommendations (**none of these are implemented**):

1. For anything beyond a classroom demo with made-up data, **close sign-up** (set the `users` create rule back to superuser-only in the admin UI) and create staff accounts by hand.
2. If sign-up stays open, give new accounts no access until an admin approves them, for example with an `approved` field on `users` and rules such as `@request.auth.approved = true`. This needs a schema change I have not made.
3. Enable the **server-side overlap check** (section 5) so the API itself refuses double bookings.
4. Never put real guest data on a server with open sign-up.

## 5. Recommended server-side validation (not enabled in my project)

PocketBase can run JavaScript hooks from a `pb_hooks` folder next to the executable. A request hook on `reservations` can run the same overlap query before a record is created or updated, and reject it with a 400 error.

I wrote this, in `pocketbase/optional-hooks/pb_hooks/`, and tried it on a **scratch copy** of PocketBase 0.40.4 with the project's schema:

| Request (existing booking: Villa 1, 00:00 to 22:00 UTC) | Result |
| --- | --- |
| Create overlapping (06:00 to 20:00) | Rejected, 400 "This unit is already booked for part of that time." |
| Create starting exactly when it ends (22:00 to 23:00) | Accepted |
| Create ending exactly when it starts | Accepted |
| Create overlapping by one minute | Rejected |
| Create a Cancelled booking inside it | Accepted |
| Update (restore) that cancelled booking to Reserved | Rejected |
| Harmless edit (notes) of a non-conflicting booking | Accepted |
| Move a booking into the existing one | Rejected |
| 16 simultaneous creates (2 per time slot, 8 slots) | 8 accepted; 0 slots double-booked |

Notes and limits:

- It is **not installed** in my local PocketBase or in the online one. To use it, copy the `pb_hooks` folder next to the PocketBase executable and restart PocketBase. Whether a hosting service lets you upload `pb_hooks` has not been checked. Ask the host first.
- The simultaneous test (last row) is small. It does not prove that the check and the save can never interleave. For a stronger guarantee the check and the write should happen in one database transaction, which I have not tried.
- The Flutter app currently shows a generic "Could not save the reservation" message for a server rejection. I did not change the app to show the hook's message as the conflict banner, and that would be a sensible follow-up.
- An existing double booking in the data is not removed by the hook. It only blocks new conflicts.

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
| T10 | Open Add Reservation in two browser windows, fill the same unit and times, save both within a second | **Today:** both may be saved (not verified). **After adding the server hook:** the second is rejected. | Depends on the hook, which is not enabled. Business rule: unconfirmed |
| T11 | Send an overlapping reservation directly to the API (see section 4) | **Today:** accepted (verified). **With the hook:** rejected with 400. | Verified on a scratch copy |

Expected outcomes for T2 to T4 and T6 also depend on the business rules listed at the end of section 3 (no turnover gap and so on).
