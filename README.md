# Followkind

Volunteer hours and follow-ups, kept together.

## Run locally

```sh
cd app
npm ci
npm run dev
```

The app uses Supabase's publishable client connection. No privileged key or OpenAI key is bundled.

## Current behavior

- Staff email-link sign-in and approved-account enrollment.
- Coordinator creates expiring personal volunteer links.
- Volunteer submits an explicit date, hours, family reference and update.
- Retries use a submission ID to avoid duplicate writes.
- Coordinator confirms records and manually creates supply requests.
- Assigned staff acknowledge a request before confirming resolution.
- Reports calculate confirmed hours and distinct visits from saved records; staff CSV export is available.
- A clearly labeled fictional demo lets you test submission, shared-visit review, needs and reporting without changing Supabase data. Demo state resets when the page reloads.

## Supabase setup

The foundation migration has already been applied in your project. Do not rerun it.
Run `supabase/next-setup.local.sql` once in Supabase SQL Editor. It combines the rerunnable app-access migration and your private coordinator allowlist entry. The `.local.sql` files are ignored by Git to avoid publishing the account email.

In Supabase Authentication URL Configuration, allow your deployed app origin and local preview URL as redirect destinations. Sign in with the coordinator email you supplied. The app verifies team membership before exposing records. Sign-in emails are sent only when you press the sign-in button.

To configure another staff account, an administrator must add its verified email, role and workspace ID to `followkind_private.allowed_staff` in SQL Editor. This first version has no public staff-enrollment UI.

## Limits of this build

AI extraction, live photo upload, live duplicate linking/undo, correction links, outgoing email/SMS needs notifications and team invitation UI are not implemented. Shared-visit linking and photo preview currently work only in the fictional demo. Live submission is marked for coordinator review and does not claim that a need was automatically extracted or delivered. Staff see assigned needs in the app, refreshed every 15 seconds.

The database functions were exercised in a local PostgreSQL-compatible test instance with mocked Supabase auth. Your live migrations, real sign-in and cross-device submissions still require setup and verification. The frontend build, TypeScript checks, domain tests and browser demo flows have passed.

## Source and design

[GitHub](https://github.com/nellnellg/Followkind)

[Figma](https://www.figma.com/design/UtGNXPeN6W0hLrK2isu3Hq/Untitled)

## Deploy on your own Cloudflare account

Connect this GitHub repository to a Cloudflare Worker with these settings:

| Setting | Value |
| --- | --- |
| Worker name | `followkind` |
| Production branch | `main` |
| Root directory | `app` |
| Build command | `npm run build` |
| Deploy command | `npm run deploy` |
| Node version | `22` or newer |

The build generates the Worker and asset configuration in `dist/server/wrangler.json`.
The deploy command uses that generated configuration. No ChatGPT account is
required to access a standalone Cloudflare deployment. Staff records still
require Supabase sign-in and approved membership.

After deployment, add the exact `https://...workers.dev` URL to Supabase
Authentication > URL Configuration > Redirect URLs, and update Site URL to
that origin if it is now your primary app. Personal volunteer links are built
from the origin where the coordinator creates them.

Keep the worker name `followkind`, matching the generated configuration. This
version needs no new Cloudflare secrets because the client uses a publishable key.
