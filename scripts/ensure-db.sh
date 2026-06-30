#!/bin/bash
# Idempotently create a database on the shared dev Postgres server.
# Usage: bash scripts/ensure-db.sh <db-name>   (or `make ensure-db DB=<db-name>`)
set -e
DB="$1"
CONTAINER="postgres-dev-shared"
[ -n "$DB" ] || { echo "❌ usage: ensure-db.sh <db-name>"; exit 1; }

if ! docker exec "$CONTAINER" psql -U postgres -tAc \
    "SELECT 1 FROM pg_database WHERE datname='${DB}'" | grep -q 1; then
    echo "🐘 Creating database ${DB}"
    docker exec "$CONTAINER" psql -U postgres -c "CREATE DATABASE \"${DB}\""
else
    echo "✓ database ${DB} already exists"
fi
