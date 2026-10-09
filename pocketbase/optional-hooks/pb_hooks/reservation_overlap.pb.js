/// <reference path="../pb_data/types.d.ts" />
// Server-side double-booking guard for the `reservations` collection.
// Same rule as the Flutter app: newStart < existingEnd && newEnd > existingStart,
// same unit, cancelled bookings never block.
//
// PocketBase runs each handler in its own scope, so the shared check lives in
// a module that is loaded with require() inside the handler.

onRecordCreateRequest((e) => {
  require(`${__hooks}/reservation_overlap_check.js`).assertNoOverlap(e.record);
  e.next();
}, "reservations");

onRecordUpdateRequest((e) => {
  require(`${__hooks}/reservation_overlap_check.js`).assertNoOverlap(e.record);
  e.next();
}, "reservations");
