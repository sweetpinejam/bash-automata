#!/usr/bin/env bash
# Produces 10 alert events spaced 20ms apart
set -euo pipefail

for i in {1..10}; do
  echo "ALERT event_id=$i time=$(date +%s%N)"
  sleep 0.02
done
