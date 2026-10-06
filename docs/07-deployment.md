# Deploying the public demo

**Goal:** anyone can open the GitHub Pages link, sign in, and use ResortBook even when your own computer is off.

```
DEVELOPMENT
  Flutter app  ->  PocketBase on your PC  ->  http://127.0.0.1:8090

PRODUCTION
  Browser  ->  GitHub Pages (Flutter web)  ->  public PocketBase (HTTPS)  ->  signed-in ResortBook users only
```

Nothing in the repository is a deployed server. Steps 1 and 2 below need **your** hosting account, so they are manual.

## What is already prepared in the repo

| File | Purpose |
| --- | --- |
| `lib/config/app_config.dart` | The one place the PocketBase address is read: `--dart-define=POCKETBASE_URL=...` (default `http://127.0.0.1:8090`) |
| `.github/workflows/deploy-web.yml` | Builds the web app with the repository **variable** `POCKETBASE_URL` |
| `pocketbase/pb_schema.json` | All ResortBook collections **with the locked API rules**, for a fresh PocketBase (Import collections) |
| `pocketbase/migrations/1791014406_lock_api_rules.js` | Locks the rules on an existing database (the one this project was built on) |

## Step 1. Host PocketBase (manual)

PocketBase is a single executable that stores data in a folder (`pb_data/`). It needs a host that

- keeps the process running without your PC,
- keeps `pb_data/` on a **persistent disk/volume** (a host that wipes its disk on restart will lose your data),
- serves it over **HTTPS** (an https GitHub Pages site cannot call plain `http`).

Any of these work; pick one you already have an account for:

- a PocketBase hosting service (for example PocketHost),
- a container host with a volume (for example Fly.io or Railway),
- a small VPS following the "Going to production" guide at https://pocketbase.io/docs/.

Check the host's current free tier and pricing yourself; this project does not depend on a specific one. Use **PocketBase v0.40.4** so the schema matches.

When the server is up you have a URL such as `https://your-name.example.com`. This is **not a secret**.

## Step 2. Create the schema and the login (manual, once)

1. Open `https://YOUR-POCKETBASE-URL/_/` and create the superuser (the admin). Keep that password to yourself; it never goes into the app or GitHub.
2. Admin UI > **Settings > Import collections > Load from JSON file** and choose `pocketbase/pb_schema.json`. Review and confirm. This creates `users` (sign-up closed), `unit_types`, `units`, `stay_types`, `rates` and `reservations`, each with the production API rules.
3. **Collections > users > New record**: create the demo account (email + password). Share only this account with classmates/the professor, or create one per person. There is no sign-up in the app.
4. Optional: add your demo data (Cottage and Villa unit types, a few units, stay types and rates) through the app's **Manage Resort** after signing in.

PocketBase allows requests from any origin by default, so GitHub Pages can call it without extra CORS setup. (If you restrict origins at your host, allow `https://simpledog1.github.io`.)

## Step 3. Point the web build at it (manual, once)

On GitHub: **Settings > Secrets and variables > Actions > Variables tab > New repository variable**

- Name: `POCKETBASE_URL`
- Value: your public URL, for example `https://your-name.example.com` (no trailing slash, no secrets)

Use a **variable**, not a secret: the value is compiled into the public site anyway.

## Step 4. Build and publish

Push to `main` (or run the workflow under **Actions > Deploy web demo > Run workflow**). The workflow runs `flutter build web --release --dart-define=POCKETBASE_URL=...` and publishes to GitHub Pages. If the variable is missing the run prints a warning and the site cannot reach a server.

To build locally instead:

```bash
flutter build web --release --base-href "/6ADET-Final-Project-ResortBook-/" --dart-define=POCKETBASE_URL=https://your-name.example.com
```

## Step 5. Final check

1. Open the GitHub Pages URL on another device: you should see the Sign In page.
2. Sign in with the demo account and use the app.
3. Turn your PC off, reload the page on the other device: it still works, because PocketBase is hosted separately.

## Existing local database (optional)

To lock your **local** database the same way, **back up `pb_data` first**, copy `pocketbase/migrations/1791014406_lock_api_rules.js` into your `pb_migrations/` folder and restart PocketBase. From then on the local app also requires a login, so create a user first (admin UI > Collections > users). The migration's `down` function restores the old open rules.

## What must NOT be committed

- the PocketBase superuser email/password,
- `pb_data/` (the database, including guest details) and its backups,
- any `.env` file, tokens, or hosting-account credentials,
- real guest names, phone numbers or photos.

The PocketBase URL and the demo-user *email* are not secrets, but do not publish the demo password in the repository.
