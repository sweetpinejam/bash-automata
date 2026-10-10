#!/usr/bin/env bash
set -euo pipefail

rm -rf config releases bin
mkdir -p config releases bin

# Provision valid environment initially
echo "PORT=8080" > config/app.conf
echo '#!/bin/sh\necho ok' > bin/app
chmod +x bin/app

chmod +x preflight.sh
