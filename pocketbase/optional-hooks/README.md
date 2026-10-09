# Optional server-side overlap check (not active)

`pb_hooks/` holds a PocketBase JavaScript hook that rejects a reservation that overlaps an existing non-cancelled booking for the same unit. It is the server-side version of the rule in `lib/logic/booking_logic.dart`.

- **It is not installed anywhere.** It only works if you copy the `pb_hooks` folder next to the PocketBase executable and restart PocketBase.
- I tried it on a scratch copy of PocketBase 0.40.4 with this project's schema. The results are in [docs/09-reservations-and-data-integrity.md](../../docs/09-reservations-and-data-integrity.md#5-recommended-server-side-validation-not-enabled-in-my-project).
- I have not checked whether the hosting service for the online demo accepts uploaded `pb_hooks`.
- It does not change the schema, the collection rules or any data.