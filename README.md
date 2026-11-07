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
