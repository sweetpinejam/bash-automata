#!/usr/bin/env bash
set -euo pipefail

rm -f /dev/shm/telemetry_bus.dat disk_telemetry.dat
chmod +x writer.sh consumer.py
