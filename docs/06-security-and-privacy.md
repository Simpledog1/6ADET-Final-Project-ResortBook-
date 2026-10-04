# Security and privacy

**Last checked:** 2026-10-04

ResortBook is a university project meant to run on a local computer with a local PocketBase server. It is **not** a production or public booking system, and it does not claim production-level security.

## What this app stores

| Data | Where it lives | Who can see it |
| --- | --- | --- |
| Guest name, phone number, email, number of guests and notes for each reservation | The local PocketBase database (`pb_data/` next to the PocketBase executable, not in this repository) | Anyone who can reach that PocketBase server (by default only the same computer, `127.0.0.1:8090`) |
| Resort configuration: unit types, units, stay types, rates | The same local PocketBase database | Same as above |
| Booking prices (rate and total in ₱) | Saved with each reservation | Same as above |

- **No payment information** (card or bank details) is collected or stored.
- No data is sent to any other service. The app only talks to the PocketBase server.

## Access control

- **Authentication is not implemented.** There are no user accounts or logins in the app.
- The PocketBase collection API rules are **open** so the app can read and write without logging in. This is only acceptable because the server runs locally for development and grading. Before any real deployment, staff logins and locked-down API rules would be required.
- The PocketBase superuser (admin) account is created locally by whoever runs the server; its credentials are not in this repository.

## Secrets

- Values the app needs at run time: none. The PocketBase address (`http://127.0.0.1:8090`) is not a secret.
- No API keys, tokens or passwords are compiled into the app or committed to the repository. `.env` files are git-ignored if ever added.
- The published web build carries nothing sensitive; it also can't reach a local PocketBase (see the README's web build section).

## Checklist

- [x] `.env` is in `.gitignore`, and `.env.example` is committed
- [x] No API keys, service account files, keystores or passwords in the repository
- [x] `pb_data/` (the database with guest details) is not committed
- [ ] Security rules locked down — **not done**: API rules are open for local use (no authentication)
- [x] Sample/TEST data uses made-up guests, not real people
- [x] No course or university credentials anywhere

Re-run `git log -p | grep -i "api_key\|secret\|password\|token"` before submitting to confirm nothing real was committed.
