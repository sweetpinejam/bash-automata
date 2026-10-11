#!/usr/bin/env bash
set -euo pipefail

rm -rf releases current current.tmp*
mkdir -p releases/v1 releases/v2

echo "VERSION 1.0.0" > releases/v1/version.txt
echo "VERSION 2.0.0" > releases/v2/version.txt

ln -s releases/v1 current
chmod +x swap.sh
