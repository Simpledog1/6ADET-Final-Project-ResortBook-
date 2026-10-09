module.exports = {
  assertNoOverlap: function (rec) {
    const status = String(rec.get("status") || "");
    // A cancelled booking can't conflict with anything.
    if (status.toLowerCase().indexOf("cancel") !== -1) return;

    const unit = rec.get("unit");
    if (!unit) return;

    const conflicts = $app.findRecordsByFilter(
      "reservations",
      "unit = {:unit} && id != {:id} && startAt < {:end} && endAt > {:start} && status !~ 'cancel'",
      "",
      1,
      0,
      {
        unit: unit,
        id: rec.id,
        start: rec.getDateTime("startAt").string(),
        end: rec.getDateTime("endAt").string(),
      },
    );

    if (conflicts.length > 0) {
      throw new BadRequestError(
        "This unit is already booked for part of that time.",
      );
    }
  },
};
