# Weekly reports

## Week 1

**Done this week**

* Finalized the ResortBook screen flow and main application screens.
* Completed and reviewed the mobile and desktop mockups in Figma.
* Exported the mockup screens as PNG files and organized them in `docs/assets/`.
* Updated the project documentation for the mockups, wireframes, and screen flow.
* Finalized PocketBase as the application's backend for storing room and reservation data.
* Tested a basic Flutter connection to a locally running PocketBase instance and successfully fetched a record.
* Updated the project proposal to reflect the reduced MVP scope and the selected backend.
* Updated the design system documentation with the color palette, typography, spacing rules, reusable components, and responsive layout rules.

**In progress**

* Implementing the ResortBook screens in Flutter.
* Connecting the Flutter screens to PocketBase.
* Preparing the final visual design-system asset for the documentation.
* Implementing reservation validation and room availability logic.

**Blocked or stuck on**

* Some Flutter screens and backend functionality still need to be connected and tested together.
* Date-range overlap validation still needs to be implemented and tested with existing reservations.

**Decisions made, and why**

* PocketBase was selected instead of Firebase or a purely local database because it provides a lightweight backend with SQLite and real-time capabilities while being easier to set up for the project.
* Real-time multi-device synchronization was moved to a stretch goal so the core reservation system remains achievable within the term.
* Live chat and automated notifications were removed from the MVP because they are not essential to the main reservation-management workflow.
* PDF booking receipt export was kept as a stretch goal because the core application can function without it.

**Hours spent, roughly:**

* 12 hours

**Next week I will:**

* Implement the basic PocketBase CRUD operations.
* Connect the room and reservation screens to the backend.
* Continue testing the main navigation and responsive layouts.
* Start implementing date-range overlap validation.
* Fix any Flutter errors encountered during integration.
