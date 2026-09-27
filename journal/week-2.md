Week 2: Finals, September 27, 2026

Phase 3 — Dashboard: Constructing the responsive main screen utilizing `LayoutBuilder` to seamlessly switch between a mobile bottom navigation bar and a desktop side navigation rail, featuring a dynamic grid of summary cards that reflow based on the active viewport.

Phase 4 — Add Reservation: Building the core input forms for capturing guest details and schedules, and implementing the crucial client-side date-overlap validation logic to actively block conflicting room bookings before executing database writes.

My goal this week: Overcome last week's network blockers to successfully set up the PocketBase backend, restore the project's cross-platform (desktop and mobile) scope, and build out the functional Dashboard and Add Reservation screens.

What I did: Restored the desktop requirements and integrated the `device_preview` package to test Windows and mobile layouts simultaneously. I successfully launched the local PocketBase server on my G: drive and configured the `rooms` and `reservations` collections with relational mapping. I developed the responsive `DashboardScreen` and built the `AddReservationScreen`, incorporating form controllers, date pickers, and a custom validation algorithm that queries existing database records to prevent date overlaps. 

What blocked me: I ran into a system architecture mismatch when setting up the database. Windows 11 completely blocked the PocketBase executable because I initially downloaded the `arm64` version, which is incompatible with my machine's AMD Ryzen 5 (x64) processor. I resolved this by deleting the directory and running the correct `amd64` executable from the command prompt. I also briefly encountered a Dart compilation error when a newly created `DashboardContent` widget was accidentally nested inside a state class, but fixing it was as simple as moving the class to the root file level.

What I learned: I learned how to utilize Flutter's `LayoutBuilder` to create truly responsive cross-platform designs that adapt their core navigation (BottomNavigationBar vs NavigationRail) based on screen width constraints. I also learned how PocketBase handles relational data under the hood using its native Relation field, bypassing the need to write and troubleshoot manual SQL foreign key constraints. Finally, I learned how to translate a business rule into client-side code by implementing the `(New Check-In < Existing Check-Out) AND (New Check-Out > Existing Check-In)` logic to prevent double bookings.
