# Week 4: Finals, October 9, 2026

**Login, online database and public demo:** Adding sign-in so the online version is not open to everyone, making the PocketBase address configurable, locking the database rules, and preparing the web version to use a hosted PocketBase instead of my PC.

**Documentation feedback and demo:** Fixing the professor's documentation feedback (m8a1 to m8a6), refreshing the screenshots, and preparing the live demo and the demo video.

**My goal this week:** Make the GitHub Pages version of ResortBook usable by other people (with a login and a database that does not depend on my computer), answer the documentation feedback honestly, and get ready to present.

**What I did:**

* **October 6:**
  * Added **sign-in** (email and password through PocketBase's `users` collection), **sign-out** and **session restore** after a page reload (`dd302fe`).
  * Put the PocketBase address in one setting, `POCKETBASE_URL`. It defaults to `http://127.0.0.1:8090` for development, and the GitHub Pages build takes it from a repository variable.
  * **Locked the database rules** so only signed-in users can read or change resort data (migration `1791014406_lock_api_rules.js`), and exported the full schema to `pocketbase/pb_schema.json` so a new PocketBase can import it.
  * Wrote `docs/07-deployment.md` (how to host PocketBase and publish the web build) and updated the security document.
  * Compared free hosting options for PocketBase and chose **PocketBase Cloud** for the online database.
  * Added a **Create Account** page with name, email, password and confirmation, and opened the `users` create rule so people can sign up themselves (`cfbf65f`, migration `1791014407_allow_self_signup.js`).
  * Took new README screenshots of the current app at 1366 px and 375 px, with made-up guests only (`92259fe`).
  * After the sign-up release, the live site at first still showed the old login page. The deployment itself was correct: the published files already contained the new screens. The most likely cause was browser and GitHub Pages caching, since GitHub Pages lets files be cached for 10 minutes.
* **October 9:**
  * Worked through the m8a1 to m8a6 feedback (`e8836e4`).
    * New setup and troubleshooting guide with the verified Flutter, Dart and PocketBase versions and the exact collection fields (`docs/08`).
    * The reservation workflow, overlap rule and edge cases, written up (`docs/09`).
    * A testing and verification page that separates what I ran live from what is only tested (`docs/10`).
    * Two real screenshots of the "Date Conflict Detected" message.
    * 11 boundary tests for the overlap rule, and a test that checks the model field names against `pb_schema.json`.
    * Reflections added to the weekly reports.
  * Tested on a copy of the database whether PocketBase itself stops double bookings. It does not, so an overlapping booking sent straight to the API is accepted. I first wrote a server-side hook that checked before saving. Later the same day, testing showed that two simultaneous requests could both pass that check. I replaced it with a version that runs the check and the save in one database transaction (`pocketbase/pb_hooks/`), added a backend integration test, and installed it on my local PocketBase after backing up `pb_data`. On October 10 I deployed it to the online PocketBase through the PocketBase Cloud portal, after a full backup, and live tests passed: overlap, conflicting edits, restores and simultaneous requests were all rejected correctly.
  * Added demo data to the online PocketBase: unit types, units, stay types, rates and three made-up reservations. I signed in with my test account in the browser, and Claude added the records through the PocketBase API using that session.
  * Locked the rules on my local PocketBase. The two rule migrations had never been copied there, so it was still open to anyone. I made a backup and a dry run on a copy first, and checked the data was unchanged afterwards.
  * Transferred 6 of my 7 local reservations to the online database after an online backup, keeping their original IDs, dates, statuses and prices. None were duplicates or overlapped online bookings. One booking with a guest's phone and email was left local on purpose, because online sign-up is open.
  * Prepared the 5-minute demo script and recorded the demo video (5 min 51 s, 1080p), then compressed it with FFmpeg from 538 MB to 9.7 MB (720p) so it is ready to upload.

**Technical implementation:**

* **Login flow:** an `AuthGate` widget shows the Sign In page when there is no valid session and the normal app when there is. The login token is saved with `shared_preferences`, so a reload keeps you signed in, and Sign out clears it.
* **Database rules:** resort collections require `@request.auth.id != ""`. Reservations cannot be deleted through the API, and users can only see their own account record.
* **Configuration:** the address is read only in `lib/config/app_config.dart`, through `--dart-define=POCKETBASE_URL=...`. No passwords or admin credentials are in the app or the repository.

**How I tested it:**

* `flutter analyze` reported no issues after each change.
* **Test counts:** `flutter test` passed **244** tests after the login work, **257** after sign-up, **276** after the documentation feedback and **278** after the final security work (October 9).
* **Backend test:** the new PocketBase integration test (`pocketbase/tests/run-overlap-tests.ps1`) passed 22 of 22 checks twice with the hook, including simultaneous requests. Without the hook, 10 of its checks fail.
* **Live checks:** the web build was checked in a browser against a copy of the database:
  * wrong password, sign-in, reload, sign-out;
  * sign-up with a mismatched password;
  * the dashboard and lists at phone and desktop widths;
  * the overlap message.
* **Online version:** on October 9, signed in as my test account, the GitHub Pages version loaded its data from the PocketBase Cloud database. The demo records were saved there through the same signed-in session, and the dashboard showed them after a reload.

**What blocked me:**

* The live site kept showing the old login page after a deploy. The published files were correct, so it was most likely caching, not a broken deployment.
* Self sign-up means anyone who finds the link can create an account and change the demo data. For a class demo with made-up data I accepted this, but it is written down as a risk with recommendations (close sign-up, or approve accounts) in `docs/09`.
* Until the end of the week, the double-booking check only ran in the app, so a direct API request or two people saving at the same moment could double-book. A check placed before the save did not fix the simultaneous case; only doing the check and the save in one transaction did.
* The demo video is 538 MB, which is too large to put in the GitHub repository (the limit is 100 MB per file). The compressed version is 9.7 MB, but it shows my webcam, so I plan to host it as an unlisted video rather than commit it.

**What I learned:** I learned that a database's API rules, not the app's screens, are what actually protect the data, and that an app-only check does not stop a second client. I also learned how a build-time setting (`--dart-define`) lets one codebase talk to a local database during development and a hosted one for the public demo, and that "it works" should be written down as "verified live", "verified by tests" or "not verified".

**Results:**

* The web version on GitHub Pages has a login and works with the hosted PocketBase (checked on October 9).
* 276 tests pass.
* The documentation answers the feedback and says honestly what is not done.

**What is left:**

* Upload the demo video and add its link to the README.
* Run the manual test checklist in `docs/09`, the Windows desktop build and the tablet width, and record the results.
* Close sign-up (or add admin approval) before any real guest data is used.
