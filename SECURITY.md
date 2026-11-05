# Security policy

marlix handles emotional conversations, so security and privacy issues are taken seriously.

## Reporting a vulnerability

Please **do not open a public issue** for a security problem.

Report it privately through GitHub: go to the **Security** tab of this repository and choose **Report a vulnerability**. Include what you found, how to reproduce it and its possible impact.

You will get a reply within 7 days. Once the issue is fixed, it will be disclosed in the repository with credit to the reporter, unless you prefer to stay anonymous.

## Scope

In scope:

- Exposure of conversations, memories or any user data.
- Ways to bypass the crisis filter or reach the LLM from the app.
- Authentication, authorization or Row Level Security (RLS) issues.
- Leaked keys or secrets in the repository.

Out of scope:

- Issues in third-party services (Supabase, Groq, Render); report them to their providers.
- Denial of service against the free-tier hosting.

## Supported versions

marlix is in early development. Only the latest version on `main` receives security fixes.

## Secret protection

The repository is public, so no key may ever reach it. GitHub checks every push:

| Protection | State |
|---|---|
| Secret scanning (keys from known providers, such as Groq and Supabase) | On |
| Push protection (a push that contains such a key is blocked) | On |
| Generic patterns (passwords, connection strings, private keys) | Not available |
| Validity checks (whether a detected key is still active) | Not available |

The last two belong to GitHub Secret Protection, a paid product for organizations. Enabling them on this personal public repository was tried on 2026-10-15: GitHub accepted the request but left both off. If the repository moves to an organization with that product, they should be turned on.

Keys live only in `api/.env` (local, ignored by Git) and in Render's dashboard. The app holds none; a test fails if its code or config contains something that looks like a key.

## Dependencies

Dependabot sends security alerts and, every Monday, pull requests with new versions of the backend's npm packages, the app's Flutter packages, the Docker images and the GitHub Actions ([`.github/dependabot.yml`](.github/dependabot.yml)). Minor and patch updates of npm and of Flutter packages each come in one grouped PR. Every update goes through the [CI](.github/workflows/ci.yml) and is merged by hand only when it passes.

## Not a crisis line

This channel is only for security reports. If you or someone you know is in danger, call **9-1-1**.
