#!/usr/bin/env bash
# Restores a backup made by backup.sh into a marlix database with no user data (S7-5).
#
#   RESTORE_DATABASE_URL  target database, already created with docs/schema.sql
#   RESTORE_AGE_IDENTITY  path to the age private key file
#   $1                    the .sql.age file
#
# The target must be a Supabase database (or the supabase/postgres image) where
# only docs/schema.sql has run.
set -euo pipefail

: "${RESTORE_DATABASE_URL:?Set RESTORE_DATABASE_URL}"
: "${RESTORE_AGE_IDENTITY:?Set RESTORE_AGE_IDENTITY}"
backup="${1:?Usage: restore.sh <file.sql.age>}"

# One transaction: it either restores everything or nothing.
# - The truncate clears the plan and the avatar that schema.sql seeds, which
#   the backup carries too, so they are not loaded twice.
# - session_replication_role = replica loads the tables in any order despite
#   the foreign keys, and does not fire the sign-up trigger on auth.users
#   (it would create the public.users rows the backup already has).
{
  echo "truncate public.plan_limits, public.avatars cascade;"
  echo "set session_replication_role = replica;"
  age --decrypt --identity "$RESTORE_AGE_IDENTITY" "$backup"
} | psql "$RESTORE_DATABASE_URL" --single-transaction -v ON_ERROR_STOP=1 --quiet --output=/dev/null
