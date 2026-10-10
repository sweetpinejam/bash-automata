#!/usr/bin/env bash
# ==============================================================================
# Microservice Runtime Config Injector
# Objective: Support defaults for PORT/DB_HOST, and require API_SECRET.
# ==============================================================================
set -euo pipefail

# TODO: Refactor the assignments below using parameter expansion:
# 1. PORT should default to "8080" if unset
# 2. DB_HOST should default to "localhost" if unset
# 3. API_SECRET must be mandatory (error out if missing: "API_SECRET is required")
PORT=$PORT
DB_HOST=$DB_HOST
API_SECRET=$API_SECRET

# Write generated configuration into .env
echo "PORT=$PORT" > .env
echo "DB_HOST=$DB_HOST" >> .env
echo "API_SECRET=$API_SECRET" >> .env

echo "CONFIG_INJECTED"
