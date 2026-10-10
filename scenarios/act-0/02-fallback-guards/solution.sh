#!/usr/bin/env bash
# ==============================================================================
# REFERENCE SOLUTION: Microservice Runtime Config Injector
# ==============================================================================
set -euo pipefail

# Parameter expansion with fallbacks and mandatory guards
PORT="${PORT:-8080}"
DB_HOST="${DB_HOST:-localhost}"
API_SECRET="${API_SECRET:?API_SECRET is required}"

echo "PORT=$PORT" > .env
echo "DB_HOST=$DB_HOST" >> .env
echo "API_SECRET=$API_SECRET" >> .env

echo "CONFIG_INJECTED"
