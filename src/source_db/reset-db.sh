#!/bin/bash
# Reset the `provider` database to its initial state: drop, recreate, load db/[0-9]*.sql in order.
set -euo pipefail
cd "$(dirname "$0")"

docker compose up -d --wait postgres

docker compose exec -T postgres psql -v ON_ERROR_STOP=1 -U postgres -d postgres \
  -c "DROP DATABASE IF EXISTS provider WITH (FORCE)" \
  -c "CREATE DATABASE provider"

for f in db/[0-9]*.sql; do
  echo "loading $f"
  docker compose exec -T postgres psql -q -v ON_ERROR_STOP=1 -U postgres -d provider -f "/$f"
done

echo "provider db reset. Connect: psql postgresql://postgres:postgres@localhost:5440/provider"
