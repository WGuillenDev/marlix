# Database backups

The free Supabase plan has no backups, and it pauses a project after a week without activity. marlix keeps its own: a GitHub Actions job ([`db-backup.yml`](../.github/workflows/db-backup.yml)) dumps the data every day, encrypts it and keeps it for 90 days. The reasoning is in [decisions.md](decisions.md#2026-11-03--database-backups-are-an-encrypted-daily-dump-in-github-artifacts-s7-5).

## What is saved

- Every row of the `public` tables: profiles, conversations, messages, memories, daily usage, plans and avatars.
- `auth.users` and `auth.identities`, because every `public` table points to `auth.users`. Passwords are in `auth.users` (hashed): this is why the file is never stored unencrypted.
- Not the structure. [`schema.sql`](schema.sql) is the reviewed source of the structure, so a restore starts from it.

## One-time setup

Done by the project owner; nothing here is ever pasted in a chat or committed.

1. **Make the key pair.** Install [age](https://github.com/FiloSottile/age) (`winget install FiloSottile.age` on Windows) and run:
   ~~~bash
   age-keygen -o marlix-backup-key.txt
   ~~~
   It prints the **public key** (`age1...`). The file holds the **private key**: copy it to your password manager or an encrypted drive, **outside this repository**, and delete it from the working folder. Without it no backup can be opened, and anyone who has it can read them all.
2. **Save the public key** in the repository settings, **Settings → Secrets and variables → Actions → Variables**: name `BACKUP_AGE_RECIPIENT`. It is public by design.
3. **Save the connection string** as a secret, name `BACKUP_DATABASE_URL`. In the Supabase dashboard, **Connect → Session pooler**, copy the URI and put your database password in it. GitHub's runners have no IPv6, and the direct connection is IPv6 only, so use the session pooler (port 5432, not the transaction pooler on 6543). From a terminal, so the value does not go through a chat:
   ~~~bash
   gh secret set BACKUP_DATABASE_URL
   ~~~
4. **Run it once by hand**: **Actions → Database backup → Run workflow**. A green run with an artifact named `db-backup-<run id>` means it works. After that it runs every day at 03:17 in Costa Rica.

If a run fails, GitHub emails the person who last edited the workflow. A scheduled workflow is switched off after 60 days without any activity in the repository; the uptime monitor of S7-6 should also watch that the newest artifact is recent.

## Download a backup

~~~bash
gh run list --workflow "Database backup" --limit 5
gh run download <run id> --dir backups
~~~

The file is `backups/db-backup-<run id>/marlix-<date>.sql.age`. Artifacts expire after 90 days; keep a copy of the one you want longer, also encrypted.

## Restore

Restore into a database where only [`schema.sql`](schema.sql) has run, so the tables exist and are empty. The script loads everything in one transaction: it restores all or nothing.

To restore into a new Supabase project, run `schema.sql` in its SQL Editor, then use that project's session pooler URI:

~~~bash
RESTORE_DATABASE_URL="postgresql://postgres.<ref>:<password>@<pooler host>:5432/postgres" \
RESTORE_AGE_IDENTITY=marlix-backup-key.txt \
bash infra/backup/restore.sh backups/db-backup-<run id>/marlix-<date>.sql.age
~~~

It needs `bash`, `age` and the PostgreSQL 17 client (`psql`). Without them installed, run it from a container (this is how it was tested, on Windows with Docker):

~~~bash
docker run --rm -v "$PWD:/work" -w /work alpine:3.22 sh -c '
  apk add --no-cache bash age postgresql17-client &&
  RESTORE_DATABASE_URL="postgresql://postgres:<password>@<host>:5432/postgres" \
  RESTORE_AGE_IDENTITY=marlix-backup-key.txt \
  bash infra/backup/restore.sh backups/db-backup-<run id>/marlix-<date>.sql.age'
~~~

After restoring a production database, point the backend's `SUPABASE_URL` and keys (in Render) at the new project, and the app's `config/production.json` at it too. People must sign in again.

## How it was tested (3 November 2026)

On two throwaway `supabase/postgres` containers (the image of `docker-compose.yml`) created from `schema.sql`:

1. The first one got 2 users, a conversation with 2 messages, a memory and a day of usage.
2. `backup.sh` produced an encrypted file. The text of the messages and the emails do not appear in it, and a different key cannot open it (`no identity matched any of the recipients`).
3. `restore.sh` loaded it into the second, empty one. The row counts and an `md5` of every table (`users`, `conversations`, `messages`, `memories`, `daily_usage`, `avatars`, `plan_limits`, `auth.users`) were identical in both.

The first real run in GitHub against the production project is the check that the connection string and the session pooler work; the owner confirms it when doing step 4 of the setup.
