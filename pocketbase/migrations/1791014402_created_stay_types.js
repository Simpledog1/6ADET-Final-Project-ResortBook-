/// <reference path="../pb_data/types.d.ts" />
// ResortBook Stage 1 — creates the configurable `stay_types` collection
// and seeds the three default stay types.
migrate((app) => {
  const timePattern = "^([01][0-9]|2[0-3]):[0-5][0-9]$"; // 24h "HH:mm"

  const collection = new Collection({
    id: "pbc_stay_types",
    type: "base",
    name: "stay_types",
    listRule: "",
    viewRule: "",
    createRule: "",
    updateRule: "",
    deleteRule: "",
    fields: [
      { id: "text_st_name", name: "name", type: "text", required: true, max: 100, presentable: true },
      { id: "text_st_description", name: "description", type: "text", max: 1000 },
      { id: "text_st_checkin", name: "checkInTime", type: "text", required: true, pattern: timePattern },
      { id: "text_st_checkout", name: "checkOutTime", type: "text", required: true, pattern: timePattern },
      // true when the check-out time falls on the following day (crosses midnight)
      { id: "bool_st_next_day", name: "endsNextDay", type: "bool" },
      { id: "bool_st_multi", name: "allowMultipleNights", type: "bool" },
      {
        id: "select_st_basis",
        name: "pricingBasis",
        type: "select",
        required: true,
        maxSelect: 1,
        values: ["per_night", "per_stay"],
      },
      { id: "bool_st_active", name: "isActive", type: "bool" },
      { id: "number_st_sort", name: "sortOrder", type: "number", onlyInt: true },
      { id: "autodate_st_created", name: "created", type: "autodate", onCreate: true, onUpdate: false },
      { id: "autodate_st_updated", name: "updated", type: "autodate", onCreate: true, onUpdate: true },
    ],
    indexes: [
      "CREATE UNIQUE INDEX `idx_stay_types_name` ON `stay_types` (`name`)",
    ],
  });

  app.save(collection);

  // Default stay types (resorts can edit these or add their own later).
  const defaults = [
    {
      name: "Overnight",
      description: "Check in 2:00 PM, check out 12:00 PM the next day.",
      checkInTime: "14:00",
      checkOutTime: "12:00",
      endsNextDay: true,
      allowMultipleNights: true,
      pricingBasis: "per_night",
      isActive: true,
      sortOrder: 1,
    },
    {
      name: "Day Tour",
      description: "Same-day visit from 8:00 AM to 5:00 PM.",
      checkInTime: "08:00",
      checkOutTime: "17:00",
      endsNextDay: false,
      allowMultipleNights: false,
      pricingBasis: "per_stay",
      isActive: true,
      sortOrder: 2,
    },
    {
      name: "Night Tour",
      description: "From 7:00 PM to 6:00 AM the next day.",
      checkInTime: "19:00",
      checkOutTime: "06:00",
      endsNextDay: true,
      allowMultipleNights: false,
      pricingBasis: "per_stay",
      isActive: true,
      sortOrder: 3,
    },
  ];

  for (const data of defaults) {
    app.save(new Record(collection, data));
  }
}, (app) => {
  const collection = app.findCollectionByNameOrId("pbc_stay_types");
  return app.delete(collection);
});
