#!/usr/bin/env bash
set -euo pipefail

pids=()
for w in worker_A worker_B worker_C worker_D; do
  bash cron_writer.sh "$w" &
  pids+=("$!")
done

wait "${pids[@]}"
echo "ALL_WORKERS_COMPLETED"
