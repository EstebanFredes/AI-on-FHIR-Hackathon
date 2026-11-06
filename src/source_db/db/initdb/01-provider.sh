#!/bin/bash
# First-boot hook (docker-entrypoint-initdb.d): create the `provider` database and load db/*.sql in order.
set -euo pipefail
psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d postgres -c "CREATE DATABASE provider"
for f in /db/[0-9]*.sql; do
  echo "loading $f"
  psql -q -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d provider -f "$f"
done
