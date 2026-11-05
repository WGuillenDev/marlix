#!/usr/bin/env bash
# Encrypted logical backup of the marlix database (S7-5).
#
#   BACKUP_DATABASE_URL  Postgres connection string (secret, never printed)
#   BACKUP_AGE_RECIPIENT age public key (age1...) that can decrypt the backup
#   BACKUP_DIR           output folder (default: ./backups)
#
# The dump is encrypted before it touches the disk: pg_dump writes to a pipe.
set -euo pipefail

: "${BACKUP_DATABASE_URL:?Set BACKUP_DATABASE_URL}"
: "${BACKUP_AGE_RECIPIENT:?Set BACKUP_AGE_RECIPIENT}"
dir="${BACKUP_DIR:-backups}"
mkdir -p "$dir"
file="$dir/marlix-$(date -u +%Y%m%dT%H%M%SZ).sql.age"

# Data only: docs/schema.sql is the reviewed source of the structure.
# `public` holds the app's data. The two auth tables are needed because every
# `public` table points to auth.users, and the sign-in methods live in
# auth.identities. Passwords are in auth.users, so the file is always encrypted.
# Two dumps, one stream: pg_dump ignores --schema when --table is given.
{
  pg_dump "$BACKUP_DATABASE_URL" --data-only --no-owner --schema=public
  pg_dump "$BACKUP_DATABASE_URL" --data-only --no-owner \
    --table=auth.users --table=auth.identities
} | age --recipient "$BACKUP_AGE_RECIPIENT" --output "$file"

# A failed dump still leaves a valid, tiny file; refuse an obviously empty one.
[ "$(wc -c < "$file")" -gt 1024 ] || { echo "Backup is too small: $file" >&2; rm -f "$file"; exit 1; }
echo "$file"
