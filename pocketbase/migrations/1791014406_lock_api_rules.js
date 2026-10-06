/// <reference path="../pb_data/types.d.ts" />
// ResortBook — production API rules.
//
// Replaces the open development rules with "signed-in users only":
//   * unit_types, units, stay_types, rates, reservations: any authenticated
//     user can list / view / create / update; reservations are never
//     deleted by the app, so delete is superuser-only (rule = null).
//   * users: public registration is switched off (createRule = null), so
//     accounts can only be made by a PocketBase superuser in the admin UI.
//     Users can read their own record and nothing else.
// A null rule means "superusers only"; "" would mean "everyone".
migrate((app) => {
  const authed = "@request.auth.id != \"\"";

  const open = ["unit_types", "units", "stay_types", "rates"];
  for (const name of open) {
    const c = app.findCollectionByNameOrId(name);
    c.listRule = authed;
    c.viewRule = authed;
    c.createRule = authed;
    c.updateRule = authed;
    c.deleteRule = authed;
    app.save(c);
  }

  const reservations = app.findCollectionByNameOrId("reservations");
  reservations.listRule = authed;
  reservations.viewRule = authed;
  reservations.createRule = authed;
  reservations.updateRule = authed;
  reservations.deleteRule = null;
  app.save(reservations);

  const users = app.findCollectionByNameOrId("users");
  users.listRule = "id = @request.auth.id";
  users.viewRule = "id = @request.auth.id";
  users.createRule = null;
  users.updateRule = null;
  users.deleteRule = null;
  app.save(users);
}, (app) => {
  // Down: restore the open development rules (local testing only).
  for (const name of ["unit_types", "units", "stay_types", "rates", "reservations"]) {
    const c = app.findCollectionByNameOrId(name);
    c.listRule = "";
    c.viewRule = "";
    c.createRule = "";
    c.updateRule = "";
    c.deleteRule = "";
    app.save(c);
  }
  const users = app.findCollectionByNameOrId("users");
  users.listRule = "id = @request.auth.id";
  users.viewRule = "id = @request.auth.id";
  users.createRule = "";
  users.updateRule = "id = @request.auth.id";
  users.deleteRule = "id = @request.auth.id";
  app.save(users);
});
