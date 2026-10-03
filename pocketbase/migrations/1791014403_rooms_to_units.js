/// <reference path="../pb_data/types.d.ts" />
// ResortBook Stage 1 — generalizes `rooms` into `units`.
//
// * The collection keeps its id (pbc_3085411453), so every existing
//   reservation relation keeps pointing at the same records.
// * Field renames keep their data (PocketBase renames the column by field id):
//     roomNumber  -> name
//     maxCapacity -> capacity
// * New fields: unitType (relation), isActive, sortOrder.
// * Kept as-is: cleaningStatus, pricePerNight (legacy price fallback),
//   type (legacy free text — copied into unitType below).
// * No records are deleted.
migrate((app) => {
  const collection = app.findCollectionByNameOrId("pbc_3085411453");

  unmarshal({ name: "units" }, collection);
  collection.fields.getByName("roomNumber").setName("name");
  collection.fields.getByName("maxCapacity").setName("capacity");

  collection.fields.add(new RelationField({
    id: "relation_unit_type",
    name: "unitType",
    collectionId: "pbc_unit_types",
    maxSelect: 1,
    cascadeDelete: false,
    required: false,
  }));
  collection.fields.add(new BoolField({ id: "bool_unit_active", name: "isActive" }));
  collection.fields.add(new NumberField({ id: "number_unit_sort", name: "sortOrder", onlyInt: true }));

  app.save(collection);

  // Backfill existing units (none at the time of writing, but safe either way):
  //  - mark every existing unit as active
  //  - create a unit type for each distinct legacy `type` text and link it
  const unitTypes = app.findCollectionByNameOrId("pbc_unit_types");
  const typeIdsByName = {};

  for (const unit of app.findAllRecords("units")) {
    const legacyType = (unit.getString("type") || "").trim();

    if (legacyType) {
      const key = legacyType.toLowerCase();
      if (!typeIdsByName[key]) {
        let typeRecord = null;
        try {
          typeRecord = app.findFirstRecordByData("unit_types", "name", legacyType);
        } catch (_) {
          typeRecord = null;
        }
        if (!typeRecord) {
          typeRecord = new Record(unitTypes, {
            name: legacyType,
            defaultCapacity: unit.getInt("capacity"),
            isActive: true,
            sortOrder: Object.keys(typeIdsByName).length + 1,
          });
          app.save(typeRecord);
        }
        typeIdsByName[key] = typeRecord.id;
      }
      unit.set("unitType", typeIdsByName[key]);
    }

    unit.set("isActive", true);
    app.save(unit);
  }
}, (app) => {
  const collection = app.findCollectionByNameOrId("pbc_3085411453");

  collection.fields.removeByName("unitType");
  collection.fields.removeByName("isActive");
  collection.fields.removeByName("sortOrder");
  collection.fields.getByName("name").setName("roomNumber");
  collection.fields.getByName("capacity").setName("maxCapacity");
  unmarshal({ name: "rooms" }, collection);

  return app.save(collection);
});
