#!/usr/bin/env bash
set -euo pipefail

rm -f pipeline.pid grandchildren.pids
chmod +x orchestrator.sh pipeline.sh
