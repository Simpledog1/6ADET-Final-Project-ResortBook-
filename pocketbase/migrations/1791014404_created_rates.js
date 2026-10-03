/// <reference path="../pb_data/types.d.ts" />
// ResortBook Stage 1 — creates the `rates` collection:
// one price (₱) per unit type + stay type combination.
migrate((app) => {
  const collection = new Collection({
    id: "pbc_rates",
    type: "base",
    name: "rates",
    listRule: "",
    viewRule: "",
    createRule: "",
    updateRule: "",
    deleteRule: "",
    fields: [
      {
        id: "relation_rate_unit_type",
        name: "unitType",
        type: "relation",
        collectionId: "pbc_unit_types",
        maxSelect: 1,
        required: true,
        cascadeDelete: true, // a rate is meaningless without its unit type
      },
      {
        id: "relation_rate_stay_type",
        name: "stayType",
        type: "relation",
        collectionId: "pbc_stay_types",
        maxSelect: 1,
        required: true,
        cascadeDelete: true,
      },
      // Price in Philippine pesos. Not "required" because PocketBase treats
      // 0 as empty for required number fields.
      { id: "number_rate_price", name: "price", type: "number", min: 0 },
      { id: "autodate_rate_created", name: "created", type: "autodate", onCreate: true, onUpdate: false },
      { id: "autodate_rate_updated", name: "updated", type: "autodate", onCreate: true, onUpdate: true },
    ],
    indexes: [
      "CREATE UNIQUE INDEX `idx_rates_unit_type_stay_type` ON `rates` (`unitType`, `stayType`)",
    ],
  });

  return app.save(collection);
}, (app) => {
  const collection = app.findCollectionByNameOrId("pbc_rates");
  return app.delete(collection);
});
