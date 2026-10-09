/// <reference path="../pb_data/types.d.ts" />
// ResortBook: server-side double-booking guard for the `reservations` collection.
//
// Same rule as the app (lib/logic/booking_logic.dart): two reservations of the
// same unit clash when newStart < existingEnd && newEnd > existingStart.
// Cancelled reservations never block, and touching ends (back-to-back) are fine.
//
// The check and the save run inside ONE database transaction. PocketBase writes
// through a single connection, so while one booking is being checked and saved
// a second request waits, and when its turn comes it sees the first booking.
// (A check outside the transaction is not enough: in testing, two simultaneous
// requests both passed it and both were saved.)
//
// This file is self-contained so it can be pasted into a host's hook editor.
// PocketBase runs each handler in its own scope, so the check is defined
// inside each handler.

onRecordCreateRequest((e) => {
  function assertNoOverlap(app, rec, original) {
    const isCancelled = (r) => String(r.get("status") || "").toLowerCase().indexOf("cancel") !== -1;
    const key = (r, f) => r.getDateTime(f).string();
    if (isCancelled(rec)) return;
    if (original &&
        String(original.get("unit")) === String(rec.get("unit")) &&
        key(original, "startAt") === key(rec, "startAt") &&
        key(original, "endAt") === key(rec, "endAt") &&
        !isCancelled(original)) return; // nothing that affects availability changed
    const unit = rec.get("unit");
    if (!unit) return;
    const conflicts = app.findRecordsByFilter(
      "reservations",
      "unit = {:unit} && id != {:id} && startAt < {:end} && endAt > {:start} && status !~ 'cancel'",
      "", 1, 0,
      { unit: unit, id: rec.id, start: key(rec, "startAt"), end: key(rec, "endAt") },
    );
    if (conflicts.length > 0) {
      throw new BadRequestError("This unit is already booked for part of that time.");
    }
  }

  e.app.runInTransaction((txApp) => {
    assertNoOverlap(txApp, e.record, null);
    e.app = txApp; // save in the same transaction as the check
    e.next();
  });
}, "reservations");

onRecordUpdateRequest((e) => {
  // Same check as above. Only edits that can change availability are checked:
  // a different unit, different start/end, or restoring a cancelled booking.
  // Guest details, notes, Check In and Mark Completed are never blocked.
  function assertNoOverlap(app, rec, original) {
    const isCancelled = (r) => String(r.get("status") || "").toLowerCase().indexOf("cancel") !== -1;
    const key = (r, f) => r.getDateTime(f).string();
    if (isCancelled(rec)) return;
    if (original &&
        String(original.get("unit")) === String(rec.get("unit")) &&
        key(original, "startAt") === key(rec, "startAt") &&
        key(original, "endAt") === key(rec, "endAt") &&
        !isCancelled(original)) return;
    const unit = rec.get("unit");
    if (!unit) return;
    const conflicts = app.findRecordsByFilter(
      "reservations",
      "unit = {:unit} && id != {:id} && startAt < {:end} && endAt > {:start} && status !~ 'cancel'",
      "", 1, 0,
      { unit: unit, id: rec.id, start: key(rec, "startAt"), end: key(rec, "endAt") },
    );
    if (conflicts.length > 0) {
      throw new BadRequestError("This unit is already booked for part of that time.");
    }
  }

  e.app.runInTransaction((txApp) => {
    assertNoOverlap(txApp, e.record, e.record.original());
    e.app = txApp;
    e.next();
  });
}, "reservations");
