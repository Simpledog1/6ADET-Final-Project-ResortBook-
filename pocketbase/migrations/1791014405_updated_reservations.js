/// <reference path="../pb_data/types.d.ts" />
// ResortBook Stage 1 — reservation field migration.
//
// Renames (data is kept — PocketBase renames the column by field id):
//   assignedRoomId -> unit      (still a relation to pbc_3085411453 = units)
//   checkInDate    -> startAt   (date/time, stored in UTC)
//   checkOutDate   -> endAt
//
// New fields: guestCount, stayType (relation), notes, and snapshot fields
// (unitName, unitTypeName, stayTypeName, rate, rateBasis, quantity,
// totalAmount) so history doesn't change when configuration is edited.
//
// `status` stays a text field (PocketBase can't change a field's type
// in place). Reservations without a stayType are treated as "Overnight"
// by the app. No records are deleted.
migrate((app) => {
  const collection = app.findCollectionByNameOrId("pbc_1473635903");

  collection.fields.getByName("assignedRoomId").setName("unit");
  collection.fields.getByName("checkInDate").setName("startAt");
  collection.fields.getByName("checkOutDate").setName("endAt");

  collection.fields.add(new NumberField({ id: "number_res_guests", name: "guestCount", onlyInt: true, min: 0 }));
  collection.fields.add(new RelationField({
    id: "relation_res_stay_type",
    name: "stayType",
    collectionId: "pbc_stay_types",
    maxSelect: 1,
    cascadeDelete: false,
    required: false,
  }));
  collection.fields.add(new TextField({ id: "text_res_notes", name: "notes", max: 2000 }));

  // Snapshots
  collection.fields.add(new TextField({ id: "text_res_unit_name", name: "unitName", max: 200 }));
  collection.fields.add(new TextField({ id: "text_res_unit_type_name", name: "unitTypeName", max: 200 }));
  collection.fields.add(new TextField({ id: "text_res_stay_type_name", name: "stayTypeName", max: 200 }));
  collection.fields.add(new NumberField({ id: "number_res_rate", name: "rate", min: 0 }));
  collection.fields.add(new SelectField({
    id: "select_res_rate_basis",
    name: "rateBasis",
    maxSelect: 1,
    values: ["per_night", "per_stay"],
  }));
  collection.fields.add(new NumberField({ id: "number_res_quantity", name: "quantity", onlyInt: true, min: 0 }));
  collection.fields.add(new NumberField({ id: "number_res_total", name: "totalAmount", min: 0 }));

  app.save(collection);

  // Index used by the per-unit overlap query (added after the renames).
  const updated = app.findCollectionByNameOrId("pbc_1473635903");
  unmarshal({
    indexes: [
      "CREATE INDEX `idx_reservations_unit_time` ON `reservations` (`unit`, `startAt`, `endAt`)",
    ],
  }, updated);
  return app.save(updated);
}, (app) => {
  const collection = app.findCollectionByNameOrId("pbc_1473635903");

  unmarshal({ indexes: [] }, collection);
  for (const name of [
    "guestCount", "stayType", "notes", "unitName", "unitTypeName",
    "stayTypeName", "rate", "rateBasis", "quantity", "totalAmount",
  ]) {
    collection.fields.removeByName(name);
  }
  collection.fields.getByName("unit").setName("assignedRoomId");
  collection.fields.getByName("startAt").setName("checkInDate");
  collection.fields.getByName("endAt").setName("checkOutDate");

  return app.save(collection);
});
