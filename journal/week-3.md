# Week 3: Finals, October 5, 2026

**Phases 5 to 8 — Reservation List, Reservation Details, Calendar and testing:** Building the remaining core screens, connecting them to PocketBase, and testing the whole reservation flow end to end.

**Redesign and configurable resort (added during the week):** Matching the Figma design more closely and replacing the fixed "rooms" model with resort inventory that the owner can configure: unit types, units, stay types and rates.

**My goal this week:** Finish the five core screens from the proposal, make the app usable on both desktop and phone, make ResortBook work for different kinds of resorts instead of one room-based setup, and get the project ready for submission.

**What I did:**

* **October 3:**
  * Completed Phases 5 to 8 (Reservation List, Reservation Details and Calendar) with Gemini (`56a5a4b`).
  * Moved to Claude for a redesign that follows my Figma frames more closely (`7bf00b7`).
  * Added PocketBase migrations that turn the original `rooms` collection into `units` and add `unit_types`, `stay_types` and `rates` while keeping the existing bookings (`9100fee`). I backed up `pb_data` before running them.
  * Updated the reservation screens to use units and stay types (`6968915`).
  * Added the **Manage Resort** screens and the desktop layout with a navy top bar and a sidebar (`c8bbf41`).
  * Polished the desktop dashboard, reservation table and calendar (`78fab82`).
  * Added the reservation workflow: Edit, Check In, Mark Completed, Cancel and Restore (`9f03afa`).
* **October 4:**
  * Did a QA pass with friendlier error messages, cleanup of old code and more tests (`6ed818e`, `0c07f30`).
  * Made stay durations configurable by the owner, for example Overnight from 2:00 PM for 22 hours, Day Tour and Night Tour across midnight, and added safe-delete rules for units and unit types (`0bb7a48`).
  * Updated `AI-USAGE.md` and the licence.
* **October 5:**
  * Wrote the Week 3 entry in `docs/04-weekly-reports.md`.
  * Fixed the web build so it fills the whole browser window: DevicePreview is now only on for Windows debug runs, and the app starts at the responsive shell again (`c77762c`).
  * Fixed the image links in the mockup and design-system docs and named the web app ResortBook (`689a638`).
  * Documented my code contribution in `AI-USAGE.md` (`6676888`).
  * Replaced the Figma images in the README with real screenshots of the running app (`f377c5a`).

**Technical implementation:**

* **Booking rule:** the stay window is the check-in time plus the stay type's duration. Two bookings on the same unit overlap when `newStart < existingEnd && newEnd > existingStart`, so back-to-back bookings are allowed and cancelled bookings never block. This rule lives in plain Dart (`lib/logic/booking_logic.dart`) so it can be unit tested without a server.
* **Pricing:** a rate is set per unit type and stay type, either per night or per stay. Each reservation saves its own copy of the unit name, stay type, rate and total, so later price changes do not change old bookings.
* **Status workflow:** Reserved, then Checked In (from the check-in date), then Completed. Reserved can be Cancelled, and Restore only works if the unit is still free. There is no permanent delete.
* **Responsive layout:** below 600 px the phone layout (dashboard hub and back arrows), from 600 to 1023 px the same screens centred, and from 1024 px the desktop shell.
* **Testing without a server:** the screens get their data through a small gateway class, so widget tests can use a fake data source instead of a running PocketBase.

**How I tested it:**

* I ran the app and the tests after each stage.
* I re-ran the test suites on October 9 from the commits in Git: **184 tests passed** at the October 4 QA commit (`6ed818e`) and **235 tests passed** at the end of the week (`0bb7a48` and `f377c5a`). The 184 figure in the October 5 report is the one from the QA commit; the suite grew to 235 with the configurable-stays work the same evening.

**What blocked me:**

* Connecting the redesigned screens to the new PocketBase structure caused several integration and layout problems.
* Storing times correctly was harder than expected for stays that cross midnight or last several nights. I fixed it by saving start and end times in UTC.
* One dashboard widget test tried to call the real PocketBase and got a 400 error. The fix was the fake data source mentioned above.
* On the Quick-add Unit form, the Capacity field lost its input when the form rebuilt. Typing `50` sometimes ended up in the wrong field. I found it while testing, and it was fixed with a stable key on that field.
* A pagination widget test tapped a button that was off screen. The test was changed to scroll to the button first, and the app itself was not changed.

**What I learned:** I learned that keeping business rules in plain Dart, separate from the screens, makes them much easier to test and to change. I also learned that changing a database structure that already has data needs a backup and migrations that keep the old records, and that a responsive layout is easier when every screen shares the same data and rules and only the layout changes.

**Results:** All five core screens are working, plus Manage Resort, the reservation workflow and the desktop and phone layouts. By the end of the week there were 235 passing tests, and real screenshots were in the README.

**What is left:**

* Record the demo video.
* Make the online web version reach a database. On October 5 the published site could not reach my local PocketBase.
* Do a final check of the README and the repository before submission.
