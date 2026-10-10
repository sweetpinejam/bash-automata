#!/usr/bin/env bash
set -euo pipefail

# Remove any pre-existing .env in workspace
rm -f .env
chmod +x env_injector.sh
