/// <reference path="../pb_data/types.d.ts" />
// ResortBook Stage 1 — creates the configurable `unit_types` collection
// (Room, Cottage, Villa, Cabin, Pavilion, Function Hall, ...).
migrate((app) => {
  const collection = new Collection({
    id: "pbc_unit_types",
    type: "base",
    name: "unit_types",
    // Same open rules as the existing collections (local testing).
    listRule: "",
    viewRule: "",
    createRule: "",
    updateRule: "",
    deleteRule: "",
    fields: [
      { id: "text_ut_name", name: "name", type: "text", required: true, max: 100, presentable: true },
      { id: "text_ut_description", name: "description", type: "text", max: 1000 },
      { id: "number_ut_capacity", name: "defaultCapacity", type: "number", onlyInt: true, min: 0 },
      { id: "bool_ut_active", name: "isActive", type: "bool" },
      { id: "number_ut_sort", name: "sortOrder", type: "number", onlyInt: true },
      { id: "autodate_ut_created", name: "created", type: "autodate", onCreate: true, onUpdate: false },
      { id: "autodate_ut_updated", name: "updated", type: "autodate", onCreate: true, onUpdate: true },
    ],
    indexes: [
      "CREATE UNIQUE INDEX `idx_unit_types_name` ON `unit_types` (`name`)",
    ],
  });

  return app.save(collection);
}, (app) => {
  const collection = app.findCollectionByNameOrId("pbc_unit_types");
  return app.delete(collection);
});
