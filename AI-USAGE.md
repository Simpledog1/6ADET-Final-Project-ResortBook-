# AI Usage — ResortBook

## Overview

ResortBook was developed with substantial AI assistance, but I remained responsible for the project requirements, product decisions, design direction, database setup, testing, debugging, and deciding what AI-generated work was kept or changed.

I used three AI tools during development:

* **Gemini Pro** — early Flutter development and initial implementation.
* **Claude** — later redesign, implementation, testing support, and major feature development.
* **ChatGPT** — troubleshooting, planning, and helping me formulate prompts and implementation decisions.

I did not commit after every individual local change. I normally tested and revised the project locally, then committed after completing a feature or stage.

---

# 1. How I Used AI

## 1.1 September 23 — Initial Flutter project and design

**Tool:** Gemini Pro

**What I asked:**
I provided my ResortBook requirements and used my Figma/design-system direction to ask Gemini to help build the initial Flutter application and Dart structure.

**What AI gave me:**
Gemini generated the initial Flutter project structure, screens, theme implementation, spacing implementation, and early Dart code.

**What I kept/changed:**
I kept the initial structure as a starting point, but changed and refined the UI because the generated result did not match my Figma design closely enough. I adjusted the visual direction, colors, spacing, typography, and layout to follow my design requirements.

**Commit:**
`38bb568` — Initial design/spacing implementation

---

## 1.2 September 27 — PocketBase, dashboard, and responsive UI

**Tool:** Gemini Pro

**What I asked:**
I asked Gemini to connect ResortBook to PocketBase, build the dashboard, support both mobile and desktop layouts, and implement the reservation system according to my requirements.

**What AI gave me:**
Gemini generated the Flutter-side PocketBase integration, dashboard implementation, reservation-related code, and responsive UI.

**What I kept/changed:**
I tested the application and changed/refined UI and responsive behavior where it did not work the way I wanted. I personally configured the PocketBase database, created the collections and fields, selected the data structure, fixed the incorrect PocketBase architecture/download, and debugged the connection.

**Commits:**
`81d3c42`
`8a2c4a4`
`1cd6770`

---

## 1.3 September 27 — Screenshot tooling

**Tool:** Google/YouTube research + ChatGPT

**What I asked:**
I researched how to capture screenshots from the Flutter application using Device Preview tools. When the Windows screenshot functionality caused problems, I asked ChatGPT for troubleshooting help.

**What AI gave me:**
ChatGPT identified the Windows/Visual Studio dependencies needed for the functionality to work.

**What I kept/changed:**
I personally implemented the screenshot functionality in `lib/main.dart`, including the screenshot callback and saving the generated PNG files. I also wrote the related comments and adjusted the implementation through several small commits.

**Commits:**
`8a2c4a4`
`1cd6770`
`b6b4d3b`
`dfd39bc`

---

## 1.4 October 3 — Reservation list, details, and calendar

**Tool:** Gemini Pro

**What I asked:**
I asked Gemini to complete the Reservation List, Reservation Details, and Calendar functionality according to the project requirements.

**What AI gave me:**
Gemini generated the initial implementations for these screens and connected them to the existing project structure.

**What I kept/changed:**
I tested the generated implementation and continued following the requirements. The screens still did not fully meet my desired Figma design or the real-world functionality I wanted, which was one reason I later moved to Claude for a larger redesign.

**Commit:**
`56a5a4b`

---

## 1.5 October 3 — Figma redesign and booking architecture

**Tool:** Claude

**What I asked:**
I asked Claude to redesign ResortBook to better match my Figma design and improve the application's real-world usefulness.

I specifically required:

* better Figma alignment
* improved UI/UX
* customizable resort units
* support for different unit types
* preservation of existing functionality and data
* both mobile and desktop support

**What AI gave me:**
Claude redesigned significant parts of the Flutter application and implemented the booking architecture and related functionality.

**What I kept/changed:**
I reviewed the proposed changes, tested them, and decided which parts fit the project requirements. I retained the parts that matched my requirements and corrected/rejected changes that did not.

**Commit:**
`7bf00b7`

---

## 1.6 October 3 — PocketBase migration

**Tool:** Claude

**What I asked:**
I asked Claude to extend the existing PocketBase structure for the new configurable resort functionality without destroying the existing data or breaking the previous application.

**What AI gave me:**
Claude created the migration work for moving the project from the original room-oriented structure toward configurable units and unit types.

**What I kept/changed:**
Before the migration, I backed up the original PocketBase data. I reviewed the migration plan and explicitly required existing files and data to be preserved. I then checked the resulting database and application behavior.

**Commit:**
`9100fee`

---

## 1.7 October 3 — Manage Resort and desktop layout

**Tool:** Claude

**What I asked:**
I asked Claude to add management functionality so resort staff could configure their own unit types and units instead of being forced to use hardcoded room names.

I also explicitly required the application to support **both mobile and desktop** and not ignore the desktop Figma frames.

**What AI gave me:**
Claude implemented the Manage Resort screens, configurable unit/unit-type management, and desktop-oriented layouts.

**What I kept/changed:**
The requirement for customizable units came from my own product decision: different real resorts have different layouts and inventory. I reviewed and tested the implementation and made decisions about what should remain.

**Commit:**
`c8bbf41`

---

## 1.8 October 3 — Desktop polish

**Tool:** Claude

**What I asked:**
I asked Claude to improve the desktop dashboard, reservation table, and calendar while maintaining the existing mobile experience.

**What AI gave me:**
Claude implemented the desktop presentation and responsive adjustments.

**What I kept/changed:**
I tested the application on both mobile-sized and desktop-sized layouts and rejected changes that conflicted with the requirements or design direction.

**Commit:**
`78fab82`

---

## 1.9 October 3 — Reservation workflow

**Tool:** ChatGPT + Claude

**What I asked:**
I used ChatGPT to help formulate the implementation plan and then asked Claude to implement reservation management features including editing, check-in, completion, cancellation, and restoration.

**What AI gave me:**
Claude implemented the reservation workflow and related UI/state changes.

**What I kept/changed:**
I personally decided the intended workflow rules and what actions should be allowed. I reviewed the plan before implementation and tested the resulting behavior.

**Commit:**
`9f03afa`

---

## 1.10 October 4 — QA and release cleanup

**Tool:** Claude

**What I asked:**
I asked Claude to help audit the application and improve its test coverage and release readiness.

**What AI gave me:**
Claude added/fixed widget tests and made release cleanup changes.

**What I kept/changed:**
I personally ran the application and tests after changes, identified problems, and decided which fixes were needed before accepting the release.

**Commit:**
`6ed818e`
`0c07f30`

---

## 1.11 October 4 — Configurable units and stay durations

**Tool:** Claude

**What I asked:**
I identified that ResortBook needed configurable stay types and durations because different resorts can have different booking patterns, such as morning stays, day tours, night tours, overnight stays, and multiple-day stays.

I asked Claude to implement this while preserving existing reservations and configurable resort units.

**What AI gave me:**
Claude implemented configurable unit types, units, stay durations, dynamic reservation windows, and safe deletion behavior.

**What I kept/changed:**
I reviewed the design and tested the resulting functionality. I also required existing data and reservations to remain safe when configuration changed.

**Commit:**
`0bb7a48`

---

## 1.12 October 5 — Web viewport fix, documentation and screenshots

**Tool:** Claude

**What I asked:**
I asked Claude to make the web build fill the whole browser window instead of showing a phone frame, fix broken image links in the documentation, help me document my AI use and code contribution, and replace the Figma images in the README with screenshots of the running app.

**What AI gave me:**
Claude turned DevicePreview off for web and release builds, fixed the documentation links and web app name, drafted the "Who Wrote What" material, and prepared the README screenshot section.

**What I kept/changed:**
I checked the web build and the screenshots, and I decided what to say about my own contribution. The screenshot export code it refers to is my own work (section 3.1).

**Commits:**
`c77762c`
`689a638`
`6676888`
`f377c5a`

---

## 1.13 October 6 — Login, PocketBase configuration and database rules

**Tool:** Claude

**What I asked:**
I asked Claude to fix the web viewport, separate the development and production PocketBase addresses, prepare PocketBase for a public host, add a login, and lock the database rules so people could not change the data without signing in. I required no secrets in the code and no breaking of the existing screens.

**What AI gave me:**
Claude added the login screen, session restore and sign-out, the `POCKETBASE_URL` setting, the migration that locks the API rules, the exported `pb_schema.json`, the deployment guide (`docs/07-deployment.md`) and the authentication tests. It tested the rules on a copy of my database, not on my real data.

**What I kept/changed:**
I reviewed the change and approved the commit. I set up the online PocketBase myself (see 1.14) and created the accounts.

**Commit:**
`dd302fe`

---

## 1.14 October 6 — Choosing where to host PocketBase

**Tool:** Claude

**What I asked:**
I asked Claude to compare free hosting options for PocketBase (Google Cloud, Oracle Cloud, PocketBase Cloud, Render, Fly.io and others) using current official pricing pages.

**What AI gave me:**
A comparison and a recommendation (PocketBase Cloud's free plan, with Oracle Cloud as the fallback) and a deployment plan.

**What I kept/changed:**
I chose PocketBase Cloud, created the instance and connected the GitHub Pages build to it.

**Commit:**
None (research only).

---

## 1.15 October 6 — Create Account (sign-up)

**Tool:** Claude

**What I asked:**
I asked for a Create Account page (name, email, password, confirm password) that matches the design, plus the database rule change needed for self sign-up, without opening the resort data to people who are not signed in.

**What AI gave me:**
The sign-up screen, the validation rules, the `users` rule migration, an updated `pb_schema.json` and tests. It also pointed out that with open sign-up any new account can change the resort data.

**What I kept/changed:**
I accepted open sign-up for the class demo with made-up data, knowing the risk, which is documented in `docs/09-reservations-and-data-integrity.md`.

**Commit:**
`cfbf65f` (originally `b192d5a`, see 1.19)

---

## 1.16 October 6 — New README screenshots and a deployment check

**Tool:** Claude

**What I asked:**
I asked Claude to replace the README screenshots with the current app, for both desktop and phone, using made-up data only. I also asked it to find out why the live site still showed the old login page.

**What AI gave me:**
Claude captured the screenshots from a web build running against a copy of my database, with the guests renamed to made-up names. It also found that the published files were already correct, so the old page was most likely caching.

**What I kept/changed:**
I reviewed the screenshots before they were committed.

**Commit:**
`92259fe` (originally `66a5acd`, see 1.19)

---

## 1.17 October 9 — Professor feedback m8a1–m8a6

**Tool:** Claude

**What I asked:**
I asked Claude to go through the feedback for m8a1 to m8a6 and fix the documentation:

* setup and versions
* honest verification status
* the reservation workflow
* overlap edge cases
* client-side versus server-side validation
* conflict screenshots
* reflections in the weekly reports

I then asked it to audit its own changes before I committed them.

**What AI gave me:**

* new documentation pages `docs/08`, `docs/09` and `docs/10`;
* additions to the existing docs and weekly reports;
* 11 overlap boundary tests and a schema/model test;
* two conflict screenshots captured from the running app;
* a server-side overlap hook, tried only on a copy of the database and **not enabled**. Later that day it was replaced by the transaction-based version described in 1.20.

It also showed on a copy of the database that a direct API request can create a double booking.

**What I kept/changed:**
The audit found claims that went further than the evidence, listed in 2.4. I had them corrected before committing.

**Commit:**
`e8836e4`

---

## 1.18 October 9 — Demo preparation

**Tool:** Claude

**What I asked:**
I asked for a 5-minute demo script and flow, a simple intro, and example data in the online database so I did not have to set everything up by hand.

**What AI gave me:**

* The script and intro.
* The demo data: after I signed in to the online version with my test account, Claude added unit types, units, stay types, rates and three made-up reservations through the PocketBase API using that session. It did not type my password.

**What I kept/changed:**
I recorded the demo video myself. An extra demo-guide page that I did not ask for was committed and then reverted (see 2.5).

**Commits:**
`0e77f4e` (added), `5581800` (reverted). The database changes are not in Git.

---

## 1.19 October 9 — Commit attribution

Commits made with Claude Code on October 6 originally ended with a line crediting Claude as a co-author:

* `b192d5a`
* `66a5acd`

On October 9 I removed only those lines. The file changes, authors and dates stayed the same, and the commits became `cfbf65f` and `92259fe`. Claude's help with those commits is still disclosed in 1.15 and 1.16 of this document. Removing the line did not change who did the work.

## 1.20 October 9 — Video compression and server-side double-booking fix

**Tool:** Claude

**What I asked:**
I asked Claude to compress my demo video below GitHub's 100 MB limit without touching the original. I also asked it to audit whether ResortBook could accept overlapping reservations through the UI, a direct API request, simultaneous requests, editing, restoring and status changes, and to fix the backend if needed.

**What AI gave me:**

* **FFmpeg:** installed with my permission; the video compressed from 538 MB to 9.7 MB (720p) and checked for readable frames and audio.
* **The audit:** it found that a direct API request and simultaneous requests could create double bookings.
* **The fix:** a PocketBase hook in `pocketbase/pb_hooks/` that runs the overlap check and the save in one database transaction.
* **The tests:** a backend integration test (`pocketbase/tests/run-overlap-tests.ps1`) and two extra unit tests.
* **Installing it:** it installed the hook on my local PocketBase after backing up `pb_data`.

**What I kept/changed:**
I approved installing FFmpeg and putting the hook on my local PocketBase. I still have to upload the video. The online deployment is in 1.21.

**Commit:**
None yet. The changes are in the working tree for my review.

## 1.21 October 10 — Online deployment and data transfer

**Tool:** Claude

**What I asked:**
I asked Claude to:

* lock my local PocketBase;
* deploy the double-booking hook to the online PocketBase;
* move my local reservations online without losing or duplicating data;
* then finish the documentation and push everything.

**What AI gave me:**

* **Local PocketBase:** applied the two missing rule migrations, after a backup and a dry run on a copy, and confirmed the data was unchanged.
* **Online PocketBase:** I signed in myself to the PocketBase admin and the PocketBase Cloud portal in the browser; Claude never typed my passwords. Using those sessions, Claude:
  * made a full online backup;
  * confirmed the online rules already matched the repository;
  * pasted the hook into the portal's Hooks editor and deployed it;
  * ran live tests and deleted the test bookings afterwards;
  * imported 6 local reservations with their original IDs and checked the relationships and overlaps.
* **Hook file:** merged into one file so the portal could load it.

**What I kept/changed:**
I decided to leave out one local reservation that contains a guest's phone and email, because online sign-up is open. I reviewed the changes before they were committed.

**Commit:**
The commit that adds this entry.

---

# 2. Where AI Got It Wrong

AI was useful throughout the project, but it was not always correct. I tested the generated code rather than assuming it worked.

## 2.1 PocketBase requests inside widget tests

**What AI gave me:**
An early widget-test implementation attempted to use the real PocketBase HTTP/data layer while running Flutter widget tests.

**What was wrong:**
The widget-test environment did not behave like the running application and produced a PocketBase 400 error. The test was therefore testing against an inappropriate external data dependency.

**What I did instead:**
The data access was separated so the widgets could receive a fake/test data source. This made the widget tests deterministic instead of depending on a running PocketBase server.

**Related commits:**
Initial implementation: `7bf00b7`
Final test/release correction: `0c07f30`

---

## 2.2 Quick-add Unit form lost the Capacity field input

**What AI gave me:**
The Quick-add Unit form conditionally displayed additional fields depending on the selected unit type/rate configuration.

**What was wrong:**
The conditional rebuild caused the Capacity field to lose its state/focus. During testing, entering `50` could result in the value being entered into the wrong field.

**What I did instead:**
I tested the form, identified the focus/state problem, and the implementation was corrected using a stable key for the Capacity field.

**Commit containing the fix:**
`0bb7a48`

---

## 2.3 Pagination widget test tapped an off-screen control

**What AI gave me:**
An early pagination widget test attempted to tap a pagination button without ensuring the widget was visible on screen.

**What was wrong:**
The test failed because the button was outside the visible/hit-testable area.

**What I did instead:**
The test was corrected to scroll until the control was visible and then interact with the hit-testable widget.

**Final QA commit:**
`6ed818e`

---

## 2.4 Documentation claimed more than had been checked

**What AI gave me:**
The first version of the m8a documentation said:

* the tablet layout had been checked;
* the schema test checked every field the code reads or writes;
* importing the current `pb_schema.json` had been tested.

**What was wrong:**
When I asked Claude to audit its own changes, it found that none of these were fully supported:

* nobody had looked at the tablet width;
* the test covers only the model reads and `createReservation`;
* the import was tested before the sign-up rule changed.

**What I did instead:**
I had the documentation corrected to say what was and was not verified before committing it.

**Commit:**
`e8836e4`

---

## 2.5 Demo data put in the wrong place

**What AI gave me:**
When I asked for example data in my online database, Claude wrote a demo-setup page and pushed it to GitHub instead.

**What was wrong:**
I wanted the data in the database, not another document.

**What I did instead:**
I had the commit reverted, then Claude added the data to the online database while I was signed in.

**Commits:**
`0e77f4e`, reverted by `5581800`

## 2.6 The first server-side hook was not safe against simultaneous requests

**What AI gave me:**
The first server-side hook (1.17) checked for an overlap before the save, and a small test of simultaneous requests passed.

**What was wrong:**
When the check was slowed down on purpose in a later test, two simultaneous requests both passed the check and both bookings were saved. The earlier test only passed because of timing.

**What I did instead:**
The hook was rewritten so the check and the save happen in one database transaction. The same slowed-down test then gave 0 double bookings (1.20).

---

## 2.7 A test request created a record in my local database

**What AI gave me:**
While checking that my local PocketBase started with the new hook, Claude sent a request that was not signed in, to see whether it would be refused.

**What was wrong:**
My local database still had the original open rules, so the request was accepted and created one empty reservation.

**What I did instead:**
That single empty record was deleted straight away. The reservation list was then compared with the backup taken just before, and both had the same 7 reservations. On October 10 the rule-locking migrations were applied to my local PocketBase, after a backup and a dry run on a copy. After that, signed-out requests could no longer read or change data (`docs/09`, section 4).

---

# 3. Who Wrote What

## 3.1 Work I personally contributed

My strongest personal contributions were not limited to typing Dart code. I was responsible for major project decisions and several implementation areas.

### Product requirements and design

I personally designed most of the ResortBook Figma mockups and created the design-system specifications.

This included decisions about:

* color palette
* typography
* spacing
* component appearance
* screen layouts
* mobile/desktop behavior
* reservation workflow

The resulting Flutter theme and spacing files were AI-assisted implementations of design decisions that I had already specified.

### PocketBase architecture and setup

I personally:

* installed/configured PocketBase
* created the collections
* created the fields
* decided how reservations and units should be represented
* fixed the incorrect `arm64`/`amd64` PocketBase setup
* debugged the connection
* backed up the existing data before migrations
* tested the data flow
* checked that existing data remained preserved

The Dart PocketBase service implementation was mostly generated by Gemini, so I do not claim that service code as entirely my own.

### AI direction and project decisions

I personally provided the requirements and constraints to Gemini and Claude, reviewed their proposed implementations, tested the application, and decided which changes should be accepted.

Examples include:

* requiring both mobile and desktop support
* requiring Figma alignment
* requiring customizable resort units
* requiring configurable stay durations
* deciding reservation workflow rules
* preserving existing PocketBase data
* deciding which AI-generated changes needed correction

### Week 4 work I did myself (October 6–9)

* chose the hosting option and set up the online PocketBase on PocketBase Cloud
* created the user accounts, including the test account used for the demo
* decided to accept open sign-up for the class demo and to keep the server-side overlap hook disabled for now
* reviewed the professor's feedback and asked for the audit before committing the documentation
* recorded the demo video
* approved installing FFmpeg and adding the double-booking hook to my local PocketBase

### Personally authored Dart implementation

The clearest Git-supported example of personally authored Dart code is the screenshot export functionality in:

`lib/main.dart`

Commits:

* `8a2c4a4`
* `1cd6770`
* `b6b4d3b`
* `dfd39bc`

This implementation saves screenshots generated from Device Preview and was developed through several small iterations after I researched the process and used ChatGPT to troubleshoot the Windows dependency issue.

#### Written by me

**Screenshot export in `lib/main.dart`** (about 20 lines)

* **Commits** (all on 2026-09-27, in this order):
  * [`8a2c4a4`](https://github.com/Simpledog1/6ADET-Final-Project-ResortBook-/commit/8a2c4a4): added the `device_preview_screenshot` package and a screenshot button in the Device Preview toolbar.
  * [`1cd6770`](https://github.com/Simpledog1/6ADET-Final-Project-ResortBook-/commit/1cd6770): added the `onScreenshot` callback, which saves each screenshot as a timestamped PNG with `dart:io` `File`.
  * [`b6b4d3b`](https://github.com/Simpledog1/6ADET-Final-Project-ResortBook-/commit/b6b4d3b): changed it to save to the absolute `G:/.../Documentation Screenshots/` path and to use `debugPrint`.
  * [`dfd39bc`](https://github.com/Simpledog1/6ADET-Final-Project-ResortBook-/commit/dfd39bc): added error handling with `try/catch`. This commit also contains the 4 PNG screenshots in `docs/assets/Documentation Screenshots/` that the feature saved, which shows it worked.
* **What it does:** in a Windows debug build, the camera button in the Device Preview toolbar saves the current screen as a PNG named with the time in milliseconds, so files never overwrite each other. It creates the folder if needed and prints whether the save worked.
* **How I built it:** I learned how to do it from Google and YouTube. When it didn't work, ChatGPT helped me find that I needed the Visual Studio dependencies for the Windows build, because saving files with `dart:io` doesn't work in the browser.
* **Honest limits:**
  * Git shows these commits under my name, but it can't prove who physically typed the code or that it was written without any AI help.
  * This is my documented code contribution, but it's only about 20 lines. By itself it does **not** meet a 20% code-authorship requirement.

I also personally contributed to the theme/spacing implementation and parts of the reservation screens, but the Git history does not provide enough evidence for me to claim those sections as entirely personally written.

---

## 3.2 One AI-written piece I understand best

### `lib/logic/booking_logic.dart`

**AI tool:** Claude

**Commit:** `7bf00b7`, later updated during the configurable-stays work.

This code determines the reservation time window and applies booking rules.

The important idea is that a reservation has a start time and an end time. The configured stay type determines the duration, and the booking logic uses the resulting time window to determine whether another reservation overlaps the same unit.

The overlap rule is essentially:

* a new reservation starts before an existing reservation ends, and
* the new reservation ends after the existing reservation starts.

This prevents overlapping reservations on the same unit while allowing reservations that only touch at the boundary.

I kept this implementation because it represents the booking behavior I wanted ResortBook to provide, while allowing the actual implementation to be handled by Claude.

---

## 3.3 Code I am not claiming as entirely mine

I am not claiming the following AI-generated areas as personally authored code:

* most of the original Dashboard implementation
* most of the original Reservation Form implementation
* original Reservation List/Details/Calendar implementations
* most of the PocketBase service Dart code
* the original reservation/room model mapping code
* the later Claude-generated redesign and management features
* the later Claude-generated configurable unit/stay functionality
* the Claude-generated login, sign-up, configuration and database-rule work from October 6
* the Claude-generated tests and documentation from October 6 and October 9

The reason is that the Git history does not provide sufficient evidence that I personally wrote those sections.

---

# 4. Human vs. AI Contribution

The repository history shows that ResortBook contains substantial AI-generated code.

The strict Git-supported estimate of personally authored surviving Dart code is approximately **20 lines**, or about **0.16% of the current `lib/` code**.

*Update, 9 October 2026:* `lib/` has grown to 15,689 lines of Dart (counted with `wc -l`, which includes blank lines and comments), so the same 20 lines are now about **0.13%**. All of the code added in Week 4 (login, sign-up, configuration and tests) was generated with Claude, so it does not add to my authored share.

A more generous interpretation that includes mixed theme/spacing work is still well below 20%.

Therefore, **I cannot honestly substantiate that 20% of the final Dart code was personally written.**

I am documenting this limitation rather than presenting AI-generated code as my own.

However, I personally contributed substantial work outside of raw line count, including:

* product requirements
* Figma design
* design-system specifications
* PocketBase database architecture and setup
* data preservation/migration decisions
* AI prompting and direction
* testing
* debugging
* reviewing AI output
* deciding which features and workflows to keep
* identifying incorrect AI behavior
* personally implementing the screenshot export feature
* defining the customizable resort/unit concept
* defining reservation workflow requirements
* requiring mobile and desktop support

---

# 5. Summary

AI significantly accelerated the implementation of ResortBook, especially during the later Claude stages.

My role was not simply to accept generated code. I defined the product requirements and design, configured the database, tested the application, identified problems, directed the AI implementation, and made the final decisions about the application's behavior.

At the same time, the Git history shows that a substantial amount of the final Dart implementation was generated with AI assistance. I therefore do not claim that I personally wrote 20% of the final code when the available evidence does not support that claim.

This document is intended to accurately describe how AI was used and what work I personally contributed.
