# Security and privacy

**Last checked:** 2026-10-06

ResortBook is a university project. It runs against a local PocketBase for development and can be pointed at a separately hosted PocketBase for a public demo (see [07-deployment.md](07-deployment.md)). It is **not** a commercial booking system and does not claim production-level security.

## What this app stores

| Data | Where it lives | Who can see it |
| --- | --- | --- |
| Guest name, phone number, email, number of guests and notes for each reservation | The PocketBase database (`pb_data/` on the PocketBase host, not in this repository) | Signed-in ResortBook users only |
| Resort configuration: unit types, units, stay types, rates | The same local PocketBase database | Same as above |
| Booking prices (rate and total in ₱) | Saved with each reservation | Same as above |

- **No payment information** (card or bank details) is collected or stored.
- No data is sent to any other service. The app only talks to the PocketBase server.

## Access control

- **Authentication:** the app opens on a Sign In page and uses PocketBase's built-in `users` collection (email + password). The session token is kept in the browser's local storage so a reload keeps you signed in; **Sign out** clears it. There is no sign-up, password reset, social login or MFA.
- **Accounts are created only by the PocketBase superuser** (admin UI > `users`). The `users` create rule is closed (`null`), so the public API cannot register accounts.
- **API rules protect the data, not the UI.** For `unit_types`, `units`, `stay_types`, `rates` and `reservations`, list/view/create/update require `@request.auth.id != ""` (any signed-in user). Without a login the API returns no records and rejects every write. Reservations cannot be deleted through the API by users (delete rule `null`, superuser only); the app never deletes reservations (it cancels them). Unit types, units, stay types and rates may be deleted by signed-in users (the app's guarded Delete).
- `users` records can only be listed/viewed by their owner, and cannot be edited or deleted through the API.
- All signed-in users have the same access (no roles); give accounts only to people you trust.
- The rules live in `pocketbase/pb_schema.json` (fresh install) and `pocketbase/migrations/1791014406_lock_api_rules.js` (existing database).
- The PocketBase superuser (admin) credentials are created by whoever hosts the server and are **never** in this repository or the app.

## Secrets

- The only run-time setting is the PocketBase address (`POCKETBASE_URL`, default `http://127.0.0.1:8090`). It is public by nature and is not a secret.
- No API keys, tokens, admin passwords or hosting credentials are compiled into the app or committed. `.env` files are git-ignored.
- Never commit: the superuser password, `pb_data/` and its backups, `.env` files, hosting credentials, the demo user's password.

## Checklist

- [x] `.env` is in `.gitignore`, and `.env.example` is committed
- [x] No API keys, service account files, keystores or passwords in the repository
- [x] `pb_data/` (the database with guest details) is not committed
- [x] API rules locked to signed-in users (tested against a copy of the database: unauthenticated reads return nothing, writes are rejected, public sign-up is refused)
- [x] Sample/TEST data uses made-up guests, not real people
- [x] No course or university credentials anywhere

Re-run `git log -p | grep -i "api_key\|secret\|password\|token"` before submitting to confirm nothing real was committed.
