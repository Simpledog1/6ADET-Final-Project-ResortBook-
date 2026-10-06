/// <reference path="../pb_data/types.d.ts" />
// ResortBook — lets people create their own account from the app.
//
// `users` rules after this migration:
//   * create: anyone (the Sign Up screen), but a new account can never mark
//     itself as verified.
//   * list / view: a user can only see their own record.
//   * update / delete: superusers only (null), so nobody can change or
//     remove other users through the API.
// Signing up only creates a login. Resort data is still protected by the
// "signed-in users only" rules from 1791014406_lock_api_rules.js.
migrate((app) => {
  const users = app.findCollectionByNameOrId("users");
  users.listRule = "id = @request.auth.id";
  users.viewRule = "id = @request.auth.id";
  users.createRule = "@request.body.verified:isset = false";
  users.updateRule = null;
  users.deleteRule = null;
  app.save(users);
}, (app) => {
  // Down: close registration again (accounts by the superuser only).
  const users = app.findCollectionByNameOrId("users");
  users.createRule = null;
  app.save(users);
});
