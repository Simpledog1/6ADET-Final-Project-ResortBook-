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

The reason is that the Git history does not provide sufficient evidence that I personally wrote those sections.

---

# 4. Human vs. AI Contribution

The repository history shows that ResortBook contains substantial AI-generated code.

The strict Git-supported estimate of personally authored surviving Dart code is approximately **20 lines**, or about **0.16% of the current `lib/` code**.

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
