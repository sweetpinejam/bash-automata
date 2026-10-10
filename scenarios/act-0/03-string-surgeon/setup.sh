#!/usr/bin/env bash
set -euo pipefail

# Provision test artifacts
rm -rf incoming categorized
mkdir -p incoming

touch incoming/backend-api.prod.tar.gz
touch incoming/frontend-app.min.js
touch incoming/database-schema.backup.sql

chmod +x sorter.sh
